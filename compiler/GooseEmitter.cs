using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;

sealed class GooseEmitter(SemanticModel model)
{
    private static readonly string[] ReservedNames = """
        import namespace struct enum type fn thread_fn export simd recursive let var
        extern const pad reusable if else while for in loop block guard match defer
        return break continue as true false null self bool varint i8 i16 i32 i64 u8
        u16 u32 u64 f32 f64 main receiver print dotgoose
        """.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries);

    private readonly StringBuilder output = new();
    private readonly Dictionary<IMethodSymbol, List<(IMethodSymbol Callee, SyntaxNode Site)>> calls =
        new(SymbolEqualityComparer.Default);
    private IMethodSymbol currentMethod = null!;
    private int depth;
    private bool usesLibrary;

    public string Emit(CompilationUnitSyntax root)
    {
        if (root.DescendantTrivia().FirstOrDefault(trivia => trivia.IsDirective).GetStructure() is { } directive)
            throw new UnsupportedSource(directive, "preprocessor directives");
        Require(root.Externs.Count == 0 && root.AttributeLists.Count == 0, root);
        foreach (var import in root.Usings)
        {
            Require(import.Alias is null && import.StaticKeyword.RawKind == 0 &&
                import.GlobalKeyword.RawKind == 0 && model.GetSymbolInfo(import.Name!).Symbol?.ToDisplayString() == "System",
                import);
        }

        foreach (var member in root.Members)
        {
            if (member is ClassDeclarationSyntax { Identifier.ValueText: "Program" } program)
                EmitProgram(program);
            else if (member is TypeDeclarationSyntax type)
                EmitType(type);
            else
                throw new UnsupportedSource(member);
        }

        CheckCallGraph();
        return (usesLibrary ? "import .dotgoose;\n\n" : "") + output.ToString().TrimEnd() + "\n";
    }

    private void EmitProgram(ClassDeclarationSyntax program)
    {
        Require(program.Modifiers.Any(SyntaxKind.StaticKeyword), program);
        CheckType(program, SyntaxKind.StaticKeyword);
        if (program.Members is not [MethodDeclarationSyntax { Identifier.ValueText: "Main" } main])
            throw new UnsupportedSource(program, "expected a single static void Program.Main()");
        var symbol = model.GetDeclaredSymbol(main)!;
        Require(symbol.IsStatic && symbol.ReturnsVoid && symbol.Parameters.Length == 0 &&
            SymbolEqualityComparer.Default.Equals(symbol, model.Compilation.GetEntryPoint(default)), main);
        CheckMethod(main, SyntaxKind.StaticKeyword);
        EmitFunction(symbol, "fn main()", main.Body!);
    }

    private void EmitType(TypeDeclarationSyntax type)
    {
        Require(type is StructDeclarationSyntax ||
            type is ClassDeclarationSyntax && type.Modifiers.Any(SyntaxKind.SealedKeyword), type);
        CheckType(type, SyntaxKind.SealedKeyword);
        var name = Name(type.Identifier);
        Require(char.IsAsciiLetterUpper(name[0]), type, "type names must begin with an ASCII uppercase letter");
        var fields = type.Members.OfType<FieldDeclarationSyntax>().ToArray();
        Require(fields.Length > 0, type, "a data type must have at least one instance field");
        var constructors = type.Members.OfType<ConstructorDeclarationSyntax>().ToArray();
        Require(constructors.Length <= 1, type, "constructor overloads");
        var methods = type.Members.OfType<MethodDeclarationSyntax>().ToArray();
        Require(methods.Select(method => method.Identifier.ValueText).Distinct().Count() == methods.Length,
            type, "method overloads within a type");

        Open($"struct {name}");
        foreach (var field in fields)
        {
            Require(field.AttributeLists.Count == 0, field);
            CheckModifiers(field.Modifiers, field);
            foreach (var variable in field.Declaration.Variables)
            {
                Require(variable.Initializer is null, variable);
                var symbol = (IFieldSymbol)model.GetDeclaredSymbol(variable)!;
                Line($"{Name(variable.Identifier)}: {ScalarType(symbol.Type, variable)},");
            }
        }
        Close();
        Line();

        foreach (var member in type.Members)
        {
            switch (member)
            {
                case FieldDeclarationSyntax:
                    break;
                case ConstructorDeclarationSyntax constructor:
                    CheckMethod(constructor);
                    Require(constructor.Initializer is null, constructor);
                    var ctor = model.GetDeclaredSymbol(constructor)!;
                    EmitFunction(ctor, $"fn new_{name}({Parameters(constructor, ctor)}) -> {name}",
                        constructor.Body!, DefaultValue(ctor.ContainingType, constructor));
                    break;
                case MethodDeclarationSyntax method:
                    CheckMethod(method);
                    var symbol = model.GetDeclaredSymbol(method)!;
                    Require(!symbol.ReturnsByRef && !symbol.ReturnsByRefReadonly, method);
                    var methodName = Name(method.Identifier);
                    Require(char.IsAsciiLetterUpper(methodName[0]), method, "method names must begin with an ASCII uppercase letter");
                    var parameters = Parameters(method, symbol);
                    var returnType = symbol.ReturnsVoid ? "" : $" -> {ScalarType(symbol.ReturnType, method.ReturnType)}";
                    var signature = parameters.Length == 0
                        ? $"receiver: {name}&"
                        : $"receiver: {name}&, {parameters}";
                    EmitFunction(symbol, $"fn {methodName}({signature}){returnType}", method.Body!);
                    break;
                default:
                    throw new UnsupportedSource(member);
            }
        }
    }

    private static void CheckType(TypeDeclarationSyntax type, SyntaxKind extraModifier)
    {
        Require(type.BaseList is null && type.TypeParameterList is null && type.ParameterList is null &&
            type.AttributeLists.Count == 0, type);
        CheckModifiers(type.Modifiers, type, extraModifier);
    }

    private static void CheckMethod(BaseMethodDeclarationSyntax method, SyntaxKind extraModifier = SyntaxKind.None)
    {
        Require(method.Body is not null && method.AttributeLists.Count == 0 &&
            method is not MethodDeclarationSyntax { TypeParameterList: not null }, method);
        CheckModifiers(method.Modifiers, method, extraModifier);
    }

    private static void CheckModifiers(SyntaxTokenList modifiers, SyntaxNode site, SyntaxKind extra = SyntaxKind.None) =>
        Require(modifiers.All(modifier => modifier.Kind() == extra || modifier.Kind() is
            SyntaxKind.PublicKeyword or SyntaxKind.InternalKeyword or SyntaxKind.PrivateKeyword), site);

    private static string Parameters(BaseMethodDeclarationSyntax syntax, IMethodSymbol symbol) =>
        string.Join(", ", symbol.Parameters.Select((parameter, index) =>
        {
            var declaration = syntax.ParameterList.Parameters[index];
            Require(declaration.Modifiers.Count == 0 && declaration.AttributeLists.Count == 0 &&
                declaration.Default is null, declaration);
            return $"{Name(declaration.Identifier)}: {ScalarType(parameter.Type, declaration)}";
        }));

    private void EmitFunction(IMethodSymbol symbol, string signature, BlockSyntax body,
        string? constructedValue = null)
    {
        currentMethod = symbol;
        calls.Add(symbol, []);
        Open(signature);
        if (constructedValue is not null)
            Line($"var receiver = {constructedValue};");
        EmitStatements(body);
        if (constructedValue is not null)
            Line("return receiver;");
        Close();
        Line();
    }

    private void EmitStatements(BlockSyntax block)
    {
        foreach (var statement in block.Statements)
        {
            switch (statement)
            {
                case LocalDeclarationStatementSyntax local:
                    Require(local.Modifiers.Count == 0 && local.UsingKeyword.RawKind == 0 &&
                        local.Declaration.Type is not RefTypeSyntax, local);
                    foreach (var variable in local.Declaration.Variables)
                    {
                        Require(variable.Initializer is not null, variable);
                        var symbol = (ILocalSymbol)model.GetDeclaredSymbol(variable)!;
                        var initializer = variable.Initializer!.Value;
                        var type = IsSourceData(symbol.Type) ? symbol.Type.Name : ScalarType(symbol.Type, variable);
                        var value = initializer is ObjectCreationExpressionSyntax creation
                            ? EmitNew(creation, symbol.Type)
                            : Expression(initializer);
                        Line($"var {Name(variable.Identifier)}: {type} = {value};");
                    }
                    break;
                case ExpressionStatementSyntax { Expression: AssignmentExpressionSyntax assignment }
                    when assignment.IsKind(SyntaxKind.SimpleAssignmentExpression):
                    Require(model.GetSymbolInfo(assignment.Left).Symbol is ILocalSymbol or IFieldSymbol, assignment.Left);
                    Line($"{Expression(assignment.Left)} = {Expression(assignment.Right)};");
                    break;
                case ExpressionStatementSyntax { Expression: InvocationExpressionSyntax invocation }:
                    Line($"{Expression(invocation)};");
                    break;
                case ReturnStatementSyntax result:
                    Require(currentMethod.MethodKind != MethodKind.Constructor, result, "early constructor return");
                    Line(result.Expression is null ? "return;" : $"return {Expression(result.Expression)};");
                    break;
                case IfStatementSyntax { Statement: BlockSyntax then } branch:
                    Open($"if {Expression(branch.Condition)}");
                    EmitStatements(then);
                    if (branch.Else is { Statement: BlockSyntax otherwise })
                    {
                        depth--;
                        Open("} else");
                        EmitStatements(otherwise);
                    }
                    else
                        Require(branch.Else is null, branch);
                    Close();
                    break;
                case WhileStatementSyntax { Statement: BlockSyntax body } loop:
                    Open($"while {Expression(loop.Condition)}");
                    EmitStatements(body);
                    Close();
                    break;
                default:
                    throw new UnsupportedSource(statement);
            }
        }
    }

    private string Expression(ExpressionSyntax expression)
    {
        var type = model.GetTypeInfo(expression);
        Require(SymbolEqualityComparer.Default.Equals(type.Type, type.ConvertedType), expression, "implicit conversion");
        Require(type.Type?.IsReferenceType != true, expression, "reference value outside a direct receiver or supported console call");

        return expression switch
        {
            LiteralExpressionSyntax literal when literal.Token.Value is int value => value.ToString(CultureInfo.InvariantCulture),
            LiteralExpressionSyntax literal when literal.IsKind(SyntaxKind.TrueLiteralExpression) => "true",
            LiteralExpressionSyntax literal when literal.IsKind(SyntaxKind.FalseLiteralExpression) => "false",
            PrefixUnaryExpressionSyntax minus when minus.IsKind(SyntaxKind.UnaryMinusExpression) &&
                minus.Operand is LiteralExpressionSyntax && model.GetConstantValue(minus).Value is int value =>
                value.ToString(CultureInfo.InvariantCulture),
            ParenthesizedExpressionSyntax group => $"({Expression(group.Expression)})",
            IdentifierNameSyntax name when model.GetSymbolInfo(name).Symbol is ILocalSymbol or IParameterSymbol =>
                Name(name.Identifier),
            IdentifierNameSyntax name when model.GetSymbolInfo(name).Symbol is IFieldSymbol { IsStatic: false } =>
                $"receiver.{Name(name.Identifier)}",
            MemberAccessExpressionSyntax member when model.GetSymbolInfo(member).Symbol is IFieldSymbol { IsStatic: false } =>
                $"{Receiver(member.Expression)}.{Name(member.Name.Identifier)}",
            BinaryExpressionSyntax binary => EmitBinary(binary),
            InvocationExpressionSyntax invocation => EmitCall(invocation),
            _ => throw new UnsupportedSource(expression)
        };
    }

    private string EmitBinary(BinaryExpressionSyntax binary)
    {
        var leftType = model.GetTypeInfo(binary.Left).Type;
        var rightType = model.GetTypeInfo(binary.Right).Type;
        Require(SymbolEqualityComparer.Default.Equals(leftType, rightType) &&
            leftType?.SpecialType is SpecialType.System_Int32 or SpecialType.System_Boolean, binary);
        var left = Expression(binary.Left);
        var right = Expression(binary.Right);
        if (binary.IsKind(SyntaxKind.AddExpression) && leftType?.SpecialType == SpecialType.System_Int32)
        {
            usesLibrary = true;
            var receiver = binary.Left is PrefixUnaryExpressionSyntax ? $"({left})" : left;
            return $"{receiver}.add({right})";
        }
        Require(binary.Kind() is SyntaxKind.EqualsExpression or SyntaxKind.NotEqualsExpression ||
            leftType?.SpecialType == SpecialType.System_Int32 && binary.Kind() is
                SyntaxKind.LessThanExpression or SyntaxKind.LessThanOrEqualExpression or
                SyntaxKind.GreaterThanExpression or SyntaxKind.GreaterThanOrEqualExpression, binary);
        return $"({left} {binary.OperatorToken.Text} {right})";
    }

    private string EmitCall(InvocationExpressionSyntax invocation)
    {
        var method = model.GetSymbolInfo(invocation).Symbol as IMethodSymbol;
        var arguments = invocation.ArgumentList.Arguments;
        CheckArguments(arguments);
        if (method is { Name: "WriteLine", Parameters: [var parameter] } &&
            SymbolEqualityComparer.Default.Equals(method.ContainingType, model.Compilation.GetTypeByMetadataName("System.Console")))
        {
            var argument = arguments[0].Expression;
            return parameter.Type.SpecialType switch
            {
                SpecialType.System_Int32 => $"print({Expression(argument)})",
                SpecialType.System_String when argument is LiteralExpressionSyntax { Token.Value: string text } =>
                    $"print({StringLiteral(text, argument)})",
                _ => throw new UnsupportedSource(invocation, "Console.WriteLine overload or argument")
            };
        }
        if (method is null || method.IsStatic || !IsSourceData(method.ContainingType) ||
            invocation.Expression is not MemberAccessExpressionSyntax member ||
            !SymbolEqualityComparer.Default.Equals(model.GetTypeInfo(member.Expression).Type, method.ContainingType))
            throw new UnsupportedSource(invocation, "call without an exact source receiver or a supported BCL mapping");

        calls[currentMethod].Add((method, invocation));
        return $"{Receiver(member.Expression)}.{Name(member.Name.Identifier)}({JoinArguments(arguments)})";
    }

    private string EmitNew(ObjectCreationExpressionSyntax creation, ITypeSymbol target)
    {
        if (creation.Initializer is not null || creation.ArgumentList is null ||
            model.GetSymbolInfo(creation).Symbol is not IMethodSymbol constructor ||
            !IsSourceData(constructor.ContainingType) ||
            !SymbolEqualityComparer.Default.Equals(target, constructor.ContainingType))
            throw new UnsupportedSource(creation, "construction must initialize a local of the exact source type");
        var arguments = creation.ArgumentList.Arguments;
        CheckArguments(arguments);
        if (constructor.IsImplicitlyDeclared)
            return DefaultValue(constructor.ContainingType, creation);

        calls[currentMethod].Add((constructor, creation));
        return $"new_{constructor.ContainingType.Name}({JoinArguments(arguments)})";
    }

    private string JoinArguments(SeparatedSyntaxList<ArgumentSyntax> arguments) =>
        string.Join(", ", arguments.Select(argument => Expression(argument.Expression)));

    private static void CheckArguments(SeparatedSyntaxList<ArgumentSyntax> arguments)
    {
        foreach (var argument in arguments)
            Require(argument.NameColon is null && argument.RefKindKeyword.RawKind == 0, argument);
    }

    private string Receiver(ExpressionSyntax expression) => expression switch
    {
        ThisExpressionSyntax => "receiver",
        IdentifierNameSyntax name when model.GetSymbolInfo(name).Symbol is ILocalSymbol => Name(name.Identifier),
        _ => throw new UnsupportedSource(expression, "receiver must be a local or this")
    };

    private static string DefaultValue(INamedTypeSymbol type, SyntaxNode site)
    {
        var fields = type.GetMembers().OfType<IFieldSymbol>().Where(field => !field.IsStatic);
        var defaults = fields.Select(field => $"{field.Name}: {ScalarType(field.Type, site) switch
        {
            "i32" => "0",
            _ => "false"
        }}");
        return $"{type.Name} {{ {string.Join(", ", defaults)} }}";
    }

    private void CheckCallGraph()
    {
        var visiting = new HashSet<IMethodSymbol>(SymbolEqualityComparer.Default);
        var complete = new HashSet<IMethodSymbol>(SymbolEqualityComparer.Default);
        foreach (var method in calls.Keys)
            Visit(method);

        void Visit(IMethodSymbol method)
        {
            if (complete.Contains(method))
                return;
            visiting.Add(method);
            foreach (var (callee, site) in calls[method])
            {
                Require(calls.ContainsKey(callee), site, "call target has no emitted declaration");
                Require(!visiting.Contains(callee), site, "recursive calls");
                Visit(callee);
            }
            visiting.Remove(method);
            complete.Add(method);
        }
    }

    private static bool IsSourceData(ITypeSymbol? type) =>
        type is INamedTypeSymbol { TypeKind: TypeKind.Class or TypeKind.Struct } named &&
        named.DeclaringSyntaxReferences.Length != 0 && !named.IsStatic;

    private static string ScalarType(ITypeSymbol type, SyntaxNode site) => type.SpecialType switch
    {
        SpecialType.System_Int32 => "i32",
        SpecialType.System_Boolean => "bool",
        _ => throw new UnsupportedSource(site, $"type {type.ToDisplayString()}")
    };

    private static string Name(SyntaxToken token)
    {
        var name = token.ValueText;
        if (!Regex.IsMatch(name, @"\A[A-Za-z_][A-Za-z0-9_]*\z") ||
            name.StartsWith("new_", StringComparison.Ordinal) || ReservedNames.Contains(name))
            throw new UnsupportedSource(token.Parent!, $"identifier {name}");
        return name;
    }

    private static string StringLiteral(string value, SyntaxNode site)
    {
        Require(value.All(character => character is >= ' ' and <= '~' or '\t' or '\n' or '\r'),
            site, "string literal outside the starter character set");
        return "\"" + value.Replace("\\", "\\\\").Replace("\"", "\\\"")
            .Replace("\t", "\\t").Replace("\n", "\\n").Replace("\r", "\\r") + "\"";
    }

    private static void Require(bool condition, SyntaxNode site, string? detail = null)
    {
        if (!condition)
            throw new UnsupportedSource(site, detail);
    }

    private void Open(string text)
    {
        Line(text + " {");
        depth++;
    }

    private void Close()
    {
        depth--;
        Line("}");
    }

    private void Line(string text = "")
    {
        if (text.Length != 0)
            output.Append(' ', depth * 4).Append(text);
        output.Append('\n');
    }
}

sealed class UnsupportedSource(SyntaxNode site, string? detail = null)
    : Exception(Format(site, detail))
{
    private static string Format(SyntaxNode site, string? detail)
    {
        var span = site.GetLocation().GetLineSpan();
        var start = span.StartLinePosition;
        return $"{span.Path}({start.Line + 1},{start.Character + 1}): error DG0001: " +
            $"Unsupported {detail ?? site.Kind().ToString()}.";
    }
}

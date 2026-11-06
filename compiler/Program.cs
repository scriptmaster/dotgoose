using System.Text;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;

if (args.Length != 1 && (args.Length != 3 || args[1] != "--output") ||
    args[0].StartsWith('-'))
{
    Console.Error.WriteLine("Usage: dotgoose input.cs [--output output.goose]");
    return 2;
}

try
{
    if (args.Length == 3 && Path.GetFullPath(args[0]) == Path.GetFullPath(args[2]))
    {
        Console.Error.WriteLine("The output path must differ from the input path.");
        return 2;
    }

    var source = File.ReadAllText(args[0], new UTF8Encoding(false, true));
    var tree = CSharpSyntaxTree.ParseText(source, new CSharpParseOptions(LanguageVersion.CSharp14), args[0]);
    var frameworkPaths = (string)AppContext.GetData("TRUSTED_PLATFORM_ASSEMBLIES")!;
    var frameworkDirectory = Path.GetDirectoryName(typeof(object).Assembly.Location);
    var references = frameworkPaths.Split(Path.PathSeparator)
        .Where(path => Path.GetDirectoryName(path) == frameworkDirectory)
        .Select(path => MetadataReference.CreateFromFile(path));
    var compilation = CSharpCompilation.Create("DotGooseInput", [tree], references,
        new CSharpCompilationOptions(OutputKind.ConsoleApplication));
    var errors = compilation.GetDiagnostics().Where(diagnostic => diagnostic.Severity == DiagnosticSeverity.Error).ToArray();
    if (errors.Length != 0)
    {
        foreach (var error in errors)
            Console.Error.WriteLine(error);
        return 1;
    }

    var output = new GooseEmitter(compilation.GetSemanticModel(tree))
        .Emit((CompilationUnitSyntax)tree.GetRoot());
    if (args.Length == 3)
        File.WriteAllText(args[2], output);
    else
        Console.Write(output);
    return 0;
}
catch (UnsupportedSource error)
{
    Console.Error.WriteLine(error.Message);
    return 1;
}
catch (Exception error) when (error is IOException or UnauthorizedAccessException or ArgumentException)
{
    Console.Error.WriteLine(error.Message);
    return 2;
}

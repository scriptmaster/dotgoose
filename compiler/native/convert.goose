import .parser;
import .strings;

const absent = -1;
const void_type = -2;
const int_type = -3;
const bool_type = -4;
const string_type = -5;

struct Local {
    name_token: i64,
    type_id: i64,
    parameter: bool,
}

struct CallEdge { caller: i64, callee: i64, site: i64 }

fn convert(source: const u8[:], tokens: const Token[:], nodes: const SyntaxNode[:],
           output: u8[>..]&) -> i64, const u8[:], bool {
    var indent = 0;
    var uses_library = false;
    var locals: Local[>..<] = [];
    var calls: CallEdge[>..] = [];
    var methods: i64[>..] = [];
    var owner = absent;
    var current = absent;
    var result_type = void_type;
    var use_system = false;
    var entry = absent;
    let unit = nodes.len - 1;

    fn text(index: i64) -> const u8[:] {
        let token = tokens[index];
        return source[token.start..token.end];
    }

    fn head(node: i64) -> i64 { return nodes[node].first_token; }
    fn child(node: i64) -> i64 { return nodes[node].first_child; }
    fn next(node: i64) -> i64 { return nodes[node].next_sibling; }

    fn fail(node: i64, message: const u8[:]) {
        return tokens[head(node)].start, message, false from convert;
    }

    fn check(ok: bool, node: i64, message: const u8[:]) {
        if !ok { fail(node, message); }
    }

    fn prefix_expression(start: i64, prefix: const u8[:]) {
        let end = output.len;
        for i in prefix.len { output.push(0); }
        output[start + prefix.len..].move_from(output[start..end]);
        output[start..start + prefix.len].move_from(prefix);
    }

    fn declaration(node: i64) -> i64 {
        var index = head(node);
        while text(index) == "public" || text(index) == "private" || text(index) == "internal" ||
              text(index) == "sealed" || text(index) == "static" {
            index++;
        }
        return index;
    }

    fn has_modifier(node: i64, keyword: const u8[:]) -> bool {
        for index in head(node)..declaration(node) {
            if text(index) == keyword { return true; }
        }
        return false;
    }

    fn validate_modifiers(node: i64, special: const u8[:], allow_private: bool) {
        var access = false;
        var extra = false;
        for index in head(node)..declaration(node) {
            let modifier = text(index);
            if modifier == special {
                check(!extra, node, "duplicate modifier");
                extra = true;
            } else {
                check(!access && (modifier == "public" || modifier == "internal" ||
                    (allow_private && modifier == "private")), node, "invalid modifiers");
                access = true;
            }
        }
    }

    fn name_token(node: i64) -> i64 {
        return declaration(node) + (if nodes[node].kind == SyntaxKind.Constructor { 0 } else { 1 });
    }

    fn lookup_type(name: const u8[:]) -> i64 {
        var item = child(unit);
        while item != absent {
            if nodes[item].kind == SyntaxKind.Type && text(name_token(item)) == name { return item; }
            item = next(item);
        }
        return absent;
    }

    fn type_id(name: const u8[:]) -> i64 {
        if name == "int" { return int_type; }
        if name == "bool" { return bool_type; }
        if name == "string" { return string_type; }
        if name == "void" { return void_type; }
        return lookup_type(name);
    }

    fn type_text(id: i64) -> const u8[:] {
        if id == int_type { return "i32"; }
        if id == bool_type { return "bool"; }
        if id == string_type { return "u8[>..]"; }
        return text(name_token(id));
    }

    fn scalar(id: i64) -> bool { return id == int_type || id == bool_type; }

    fn is_class(id: i64) -> bool {
        return id >= 0 && text(declaration(id)) == "class";
    }

    fn safe_name(index: i64, node: i64) {
        const reserved = """
            |import|namespace|struct|enum|type|fn|thread_fn|export|simd|recursive|
            |let|var|extern|const|pad|reusable|if|else|while|for|in|loop|block|
            |guard|match|defer|return|break|continue|as|true|false|null|self|
            |bool|varint|i8|i16|i32|i64|u8|u16|u32|u64|f32|f64|
            |main|receiver|print|str|dotgoose|
            """;
        let name = text(index);
        check(!starts_with(name, "new_") && find(reserved, str("|", name, "|")) < 0,
            node, "identifier is reserved in generated Goose");
    }

    fn local_index(name: const u8[:]) -> i64 {
        var index = locals.len - 1;
        while index >= 0 {
            if text(locals[index].name_token) == name { return index; }
            index--;
        }
        return absent;
    }

    fn field_token(field: i64, name: const u8[:]) -> i64 {
        var index = name_token(field);
        while index < nodes[field].end_token - 1 {
            if text(index) == name { return index; }
            index += 2;
        }
        return absent;
    }

    fn lookup_member(data_type: i64, name: const u8[:], kind: SyntaxKind) -> i64 {
        var item = child(data_type);
        while item != absent {
            if nodes[item].kind == kind {
                if kind == SyntaxKind.Field {
                    if field_token(item, name) != absent { return item; }
                } else if text(name_token(item)) == name { return item; }
            }
            item = next(item);
        }
        return absent;
    }

    fn access(member: i64, target: i64, site: i64) {
        check(target == owner || has_modifier(member, "public") || has_modifier(member, "internal"),
            site, "member is inaccessible");
    }

    fn padding() {
        for i in indent * 4 { output.push(' '); }
    }

    fn defaults(data_type: i64) {
        format(output, type_text(data_type), " { ");
        var field = child(data_type);
        var first = true;
        while field != absent {
            if nodes[field].kind == SyntaxKind.Field {
                var index = name_token(field);
                while index < nodes[field].end_token - 1 {
                    if !first { output.append(", "); }
                    first = false;
                    let zero = if text(declaration(field)) == "int" { "0" } else { "false" };
                    format(output, text(index), ": ", zero);
                    index += 2;
                }
            }
            field = next(field);
        }
        output.append(" }");
    }

    fn receiver_type(node: i64) -> i64 {
        check(nodes[node].kind == SyntaxKind.Name, node, "receiver must be a local or this");
        let name = text(head(node));
        if name == "this" {
            check(owner != entry, node, "this is unavailable in Main");
            return owner;
        }
        let index = local_index(name);
        check(index != absent && locals[index].type_id >= 0, node, "receiver must be a data local");
        return locals[index].type_id;
    }

    fn write_receiver(node: i64) {
        let name = text(head(node));
        output.append(if name == "this" { "receiver" } else { name });
    }

    fn write_name(node: i64, writable: bool) -> i64 {
        let name = text(head(node));
        let index = local_index(name);
        if index != absent {
            let local = locals[index];
            check(local.type_id != absent, node, "local used before its initializer");
            check(!writable || !local.parameter, node, "assignment to a parameter");
            check(!is_class(local.type_id), node, "class values require a direct receiver");
            output.append(name);
            return local.type_id;
        }
        let field = lookup_member(owner, name, SyntaxKind.Field);
        check(field != absent, node, "unknown local or field");
        format(output, "receiver.", name);
        return type_id(text(declaration(field)));
    }

    fn write_member(node: i64) -> i64 {
        let receiver_node = child(node);
        let target = receiver_type(receiver_node);
        let name = text(nodes[node].end_token - 1);
        let member = lookup_member(target, name, SyntaxKind.Field);
        check(member != absent, node, "unknown field");
        access(member, target, node);
        write_receiver(receiver_node);
        format(output, ".", name);
        return type_id(text(declaration(member)));
    }

    fn write_integer(node: i64, literal: i64, negative: bool) -> i64 {
        let value, ok = parse_int(text(head(literal)));
        let max = if negative { 2147483648 } else { 2147483647 };
        check(ok && value <= max, node, "integer literal outside the Int32 range");
        format(output, if negative { -value } else { value });
        return int_type;
    }

    recursive fn integer_constant(node: i64) -> i64, bool {
        let kind = nodes[node].kind;
        if kind == SyntaxKind.Literal && tokens[head(node)].kind == TokenKind.Integer {
            return parse_int(text(head(node)));
        }
        if kind == SyntaxKind.Unary {
            let value, ok = parse_int(text(head(child(node))));
            return -value, ok;
        }
        if kind == SyntaxKind.Group { return integer_constant(child(node)); }
        if kind == SyntaxKind.Binary {
            let left = child(node);
            if text(nodes[left].end_token) == "+" {
                let lhs, lhs_known = integer_constant(left);
                let rhs, rhs_known = integer_constant(next(left));
                return lhs + rhs, lhs_known && rhs_known;
            }
        }
        return 0, false;
    }

    fn console_target(node: i64) -> bool {
        let name = text(head(node));
        if lookup_member(owner, name, SyntaxKind.Field) != absent || local_index(name) != absent ||
           lookup_type(name) != absent { return false; }
        if nodes[node].kind == SyntaxKind.Name { return use_system && name == "Console"; }
        return nodes[node].kind == SyntaxKind.Member && name == "System" &&
               text(nodes[node].end_token - 1) == "Console" && nodes[child(node)].kind == SyntaxKind.Name;
    }

    recursive fn write_arguments(first: i64, method: i64, site: i64, depth: i64) {
        var argument = first;
        var parameter = child(method);
        var initial = true;
        while argument != absent {
            check(parameter != absent && nodes[parameter].kind == SyntaxKind.Parameter,
                site, "argument count does not match");
            if !initial { output.append(", "); }
            initial = false;
            let actual = expression(argument, depth + 1);
            check(actual == type_id(text(head(parameter))), argument, "argument type does not match");
            argument = next(argument);
            parameter = next(parameter);
        }
        check(parameter != absent && nodes[parameter].kind == SyntaxKind.Block,
            site, "argument count does not match");
    }

    recursive fn write_call(node: i64, depth: i64) -> i64 {
        let callee = child(node);
        check(nodes[callee].kind == SyntaxKind.Member, node, "call requires an explicit receiver");
        let receiver_node = child(callee);
        let name = text(nodes[callee].end_token - 1);
        if name == "WriteLine" && console_target(receiver_node) {
            let argument = next(callee);
            check(argument != absent && next(argument) == absent, node, "unsupported Console.WriteLine overload");
            output.append("print(");
            let actual = expression(argument, depth + 1);
            check(actual == int_type || actual == string_type,
                argument, "unsupported Console.WriteLine argument");
            output.push(')');
            return void_type;
        }
        let target = receiver_type(receiver_node);
        let method = lookup_member(target, name, SyntaxKind.Method);
        check(method != absent && target != entry, node, "unknown instance method");
        access(method, target, node);
        calls.push(CallEdge { current, method, node });
        write_receiver(receiver_node);
        format(output, ".", name, "(");
        write_arguments(next(callee), method, node, depth + 1);
        output.push(')');
        return type_id(text(declaration(method)));
    }

    recursive fn expression(node: i64, depth: i64) -> i64 {
        check(depth < 256, node, "expression exceeds the lowering limit");
        let kind = nodes[node].kind;
        if kind == SyntaxKind.Name { return write_name(node, false); }
        if kind == SyntaxKind.Member { return write_member(node); }
        if kind == SyntaxKind.Call { return write_call(node, depth); }
        if kind == SyntaxKind.Group {
            output.push('(');
            let result = expression(child(node), depth + 1);
            output.push(')');
            return result;
        }
        if kind == SyntaxKind.Literal {
            let token = head(node);
            if tokens[token].kind == TokenKind.Integer { return write_integer(node, node, false); }
            if tokens[token].kind == TokenKind.RawString {
                var decoded: u8[>..] = [];
                let error = raw_content(text(token), decoded);
                check(error.len == 0, node, error);
                if quote_count(text(token), 0) == 3 && find(text(token), "\r") < 0 { output.append(text(token)); }
                else { write_quoted(output, decoded); }
                return string_type;
            }
            if tokens[token].kind == TokenKind.StringPart || tokens[token].kind == TokenKind.RawPart {
                write_interpolation_part(output, text(token), tokens[token].kind == TokenKind.RawPart);
                return string_type;
            }
            output.append(text(token));
            return if tokens[token].kind == TokenKind.String { string_type } else { bool_type };
        }
        if kind == SyntaxKind.Interpolated {
            output.append("str(");
            var part = child(node);
            var first = true;
            while part != absent {
                if !first { output.append(", "); }
                first = false;
                let start = output.len;
                let actual = expression(part, depth+1);
                check(actual == string_type || actual == int_type || actual == bool_type,
                      part, "interpolation requires text, Int32, or Boolean");
                if actual == bool_type {
                    uses_library = true;
                    prefix_expression(start, "dotgoose::interpolate(");
                    output.push(')');
                }
                part = next(part);
            }
            output.push(')');
            return string_type;
        }
        if kind == SyntaxKind.Unary {
            let literal = child(node);
            check(nodes[literal].kind == SyntaxKind.Literal && tokens[head(literal)].kind == TokenKind.Integer,
                node, "only integer literals support unary minus");
            return write_integer(node, literal, true);
        }
        if kind == SyntaxKind.Binary {
            let left = child(node);
            let right = next(left);
            let op = text(nodes[left].end_token);
            let unary_receiver = op == "+" && nodes[left].kind == SyntaxKind.Unary;
            if op == "+" {
                uses_library = true;
            }
            if op != "+" || unary_receiver { output.push('('); }
            let lhs = expression(left, depth + 1);
            if op == "+" {
                if unary_receiver { output.push(')'); }
                output.append(".add(");
            }
            else { format(output, " ", op, " "); }
            let rhs = expression(right, depth + 1);
            check(lhs == rhs && (lhs == int_type || (lhs == bool_type && (op == "==" || op == "!="))),
                node, "unsupported operand types");
            if op == "+" {
                let constant, known = integer_constant(node);
                check(!known || (constant >= -2147483648 && constant <= 2147483647),
                    node, "constant expression overflows Int32");
            }
            output.push(')');
            return if op == "+" { int_type } else { bool_type };
        }
        fail(node, "unsupported expression");
        return absent;
    }

    fn construct(node: i64) -> i64 {
        let name = text(head(node) + 1);
        let target = lookup_type(name);
        check(target != absent && target != entry, node, "unknown construction type");
        let method = lookup_member(target, name, SyntaxKind.Constructor);
        if method == absent || (!is_class(target) && child(node) == absent &&
                               nodes[child(method)].kind == SyntaxKind.Parameter) {
            check(child(node) == absent, node, "no matching constructor");
            defaults(target);
        } else {
            access(method, target, node);
            calls.push(CallEdge { current, method, node });
            format(output, "new_", name, "(");
            write_arguments(child(node), method, node, 0);
            output.push(')');
        }
        return target;
    }

    recursive fn write_block(node: i64) -> bool {
        let saved = locals.len;
        var returns = false;
        var statement = child(node);
        while statement != absent {
            if nodes[statement].kind == SyntaxKind.Local {
                var variable = child(statement);
                while variable != absent {
                    let name = head(variable);
                    safe_name(name, variable);
                    check(local_index(text(name)) == absent, variable, "duplicate local name");
                    locals.push(Local { name, absent, false });
                    variable = next(variable);
                }
            }
            statement = next(statement);
        }
        statement = child(node);
        indent++;
        while statement != absent {
            returns = write_statement(statement) || returns;
            statement = next(statement);
        }
        indent--;
        locals.pop_n(locals.len - saved);
        return returns;
    }

    recursive fn write_statement(node: i64) -> bool {
        let kind = nodes[node].kind;
        padding();
        if kind == SyntaxKind.Local {
            let declared_name = text(head(node));
            let inferred = declared_name == "var" && lookup_type(declared_name) == absent;
            let declared = type_id(declared_name);
            check(inferred || scalar(declared) || declared == string_type || (declared >= 0 && declared != entry),
                  node, "unsupported local type");
            var variable = child(node);
            while variable != absent {
                let name = head(variable);
                let init = child(variable);
                let start = output.len;
                let actual = if nodes[init].kind == SyntaxKind.New { construct(init) } else { expression(init, 0) };
                check(scalar(actual) || actual == string_type || (actual >= 0 && actual != entry), init, "unsupported initializer type");
                check(inferred || actual == declared, init, "initializer type does not match");
                check(!inferred || next(variable) == absent, node, "var requires a single declarator");
                let prefix = str("var ", text(name), ": ", type_text(actual), " = ",
                                 if actual == string_type { "str(" } else { "" });
                prefix_expression(start, prefix);
                if actual == string_type { output.push(')'); }
                output.append(";\n");
                locals[local_index(text(name))].type_id = actual;
                variable = next(variable);
                if variable != absent { padding(); }
            }
        } else if kind == SyntaxKind.Assignment {
            let lhs = child(node);
            let left_kind = nodes[lhs].kind;
            check(left_kind == SyntaxKind.Name || left_kind == SyntaxKind.Member, lhs, "invalid assignment target");
            let left = if left_kind == SyntaxKind.Name { write_name(lhs, true) } else { write_member(lhs) };
            output.append(" = ");
            if left == string_type { output.append("str("); }
            check(expression(next(lhs), 0) == left, node, "assignment type does not match");
            if left == string_type { output.push(')'); }
            output.append(";\n");
        } else if kind == SyntaxKind.ExpressionStatement {
            let value = child(node);
            check(nodes[value].kind == SyntaxKind.Call, node, "expected a call statement");
            expression(value, 0);
            output.append(";\n");
        } else if kind == SyntaxKind.Return {
            check(nodes[current].kind != SyntaxKind.Constructor, node, "early constructor return");
            output.append("return");
            let value = child(node);
            var actual = void_type;
            if value != absent {
                output.push(' ');
                actual = expression(value, 0);
                check(actual != void_type, value, "return expression must have a value");
            }
            check(actual == result_type, node, "return type does not match");
            output.append(";\n");
            return true;
        } else {
            output.append(if kind == SyntaxKind.If { "if " } else { "while " });
            let condition = child(node);
            check(expression(condition, 0) == bool_type, condition, "condition must be Boolean");
            output.append(" {\n");
            let body = next(condition);
            let body_returns = write_block(body);
            padding();
            let otherwise = next(body);
            if otherwise != absent {
                output.append("} else {\n");
                let otherwise_returns = write_block(otherwise);
                padding();
                output.append("}\n");
                return body_returns && otherwise_returns;
            }
            output.append("}\n");
        }
        return false;
    }

    fn validate_type(node: i64) {
        let name = text(name_token(node));
        check(lookup_type(name) == node, node, "duplicate type name");
        safe_name(name_token(node), node);
        if name == "Program" {
            validate_modifiers(node, "static", false);
            check(is_class(node) && has_modifier(node, "static"), node, "expected static class Program");
            entry = node;
            return;
        }
        check(name[0] >= 'A' && name[0] <= 'Z', node, "type names must begin with an uppercase ASCII letter");
        validate_modifiers(node, if is_class(node) { "sealed" } else { "" }, false);
        check(!is_class(node) || has_modifier(node, "sealed"), node, "expected a sealed class or struct");

        var member = child(node);
        var fields = 0;
        var constructors = 0;
        while member != absent {
            validate_modifiers(member, "", true);
            let kind = nodes[member].kind;
            if kind == SyntaxKind.Field {
                fields++;
                check(scalar(type_id(text(declaration(member)))), member, "unsupported field type");
                var index = name_token(member);
                while index < nodes[member].end_token - 1 {
                    safe_name(index, member);
                    let field_name = text(index);
                    check(field_name != name && lookup_member(node, field_name, SyntaxKind.Field) == member &&
                        field_token(member, field_name) == index &&
                        lookup_member(node, field_name, SyntaxKind.Method) == absent, member, "duplicate member name");
                    index += 2;
                }
            } else if kind == SyntaxKind.Constructor {
                constructors++;
                check(constructors == 1 && text(name_token(member)) == name, member, "invalid or overloaded constructor");
                check(is_class(node) || nodes[child(member)].kind == SyntaxKind.Parameter || has_modifier(member, "public"),
                    member, "parameterless struct constructor must be public");
            } else {
                let token = name_token(member);
                let method_name = text(token);
                let data_type = type_id(text(declaration(member)));
                safe_name(token, member);
                check(method_name[0] >= 'A' && method_name[0] <= 'Z', member, "method names must begin with an uppercase ASCII letter");
                check(method_name != name && lookup_member(node, method_name, kind) == member, member, "invalid or overloaded method");
                check(scalar(data_type) || data_type == void_type, member, "unsupported method return type");
            }
            member = next(member);
        }
        check(fields != 0, node, "a data type must have at least one field");
    }

    fn write_function(node: i64) {
        current = node;
        methods.push(node);
        let constructor = nodes[node].kind == SyntaxKind.Constructor;
        let name = text(name_token(node));
        let main = owner == entry;
        result_type = if constructor { void_type } else { type_id(text(declaration(node))) };
        if main { output.append("fn main("); }
        else if constructor { format(output, "fn new_", name, "("); }
        else { format(output, "fn ", name, "(receiver: ", type_text(owner), "&"); }

        var comma = !main && !constructor;
        var body = child(node);
        while nodes[body].kind == SyntaxKind.Parameter {
            let data_type = type_id(text(head(body)));
            let token = head(body) + 1;
            safe_name(token, body);
            check(scalar(data_type) && local_index(text(token)) == absent, body, "invalid parameter");
            if comma { output.append(", "); }
            comma = true;
            format(output, text(token), ": ", type_text(data_type));
            locals.push(Local { token, data_type, true });
            body = next(body);
        }
        output.push(')');
        if constructor || result_type != void_type {
            format(output, " -> ", type_text(if constructor { owner } else { result_type }));
        }
        output.append(" {\n");
        if constructor {
            output.append("    var receiver = ");
            defaults(owner);
            output.append(";\n");
        }
        let returns = write_block(body);
        check(returns || result_type == void_type, node, "method must return a value on every path");
        if constructor { output.append("    return receiver;\n"); }
        output.append("}\n\n");
        locals.clear();
    }

    var item = child(unit);
    while item != absent {
        if nodes[item].kind == SyntaxKind.Using {
            check(nodes[item].end_token - head(item) == 3 && text(head(item) + 1) == "System",
                item, "only using System is supported");
            use_system = true;
        } else {
            validate_type(item);
        }
        item = next(item);
    }
    check(entry != absent, unit, "missing static class Program");
    let main = child(entry);
    check(main != absent && next(main) == absent && nodes[main].kind == SyntaxKind.Method &&
          text(declaration(main)) == "void" && text(name_token(main)) == "Main" &&
          has_modifier(main, "static") && nodes[child(main)].kind == SyntaxKind.Block,
          entry, "expected one static void Main()");
    validate_modifiers(main, "static", true);

    item = child(unit);
    while item != absent {
        if nodes[item].kind == SyntaxKind.Type {
            owner = item;
            if owner != entry {
                format(output, "struct ", type_text(owner), " {\n");
                var field = child(owner);
                while field != absent {
                    if nodes[field].kind == SyntaxKind.Field {
                        var index = name_token(field);
                        while index < nodes[field].end_token - 1 {
                            format(output, "    ", text(index), ": ", type_text(type_id(text(declaration(field)))), ",\n");
                            index += 2;
                        }
                    }
                    field = next(field);
                }
                output.append("}\n\n");
            }
            var member = child(owner);
            while member != absent {
                if nodes[member].kind != SyntaxKind.Field { write_function(member); }
                member = next(member);
            }
        }
        item = next(item);
    }

    var finished: bool[>..] = [];
    for i in nodes.len { finished.push(false); }
    var remaining = methods.len;
    while remaining != 0 {
        let before = remaining;
        for method in methods {
            if finished[method] { continue; }
            var ready = true;
            for edge in calls {
                if edge.caller == method && !finished[edge.callee] { ready = false; break; }
            }
            if ready { finished[method] = true; remaining--; }
        }
        if before == remaining {
            for edge in calls {
                if !finished[edge.caller] && !finished[edge.callee] { fail(edge.site, "recursive call graph"); }
            }
        }
    }
    return 0, "", uses_library;
}

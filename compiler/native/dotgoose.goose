import .convert;
import .diagnostic;
import .razor;
import .web;

fn main() {
    let argv = args();
    if argv.len > 2 && argv[1] == "web" {
        web_compiler::run(argv[2..]);
        return;
    }
    if argv.len > 2 && argv[1] == "razor" {
        razor::run(argv[2..]);
        return;
    }
    if !(argv.len == 2 || (argv.len == 4 && argv[2] == "--output" && argv[1] != argv[3])) {
        write_stderr("Usage: dotgoose input.cs [--output output.goose]\n");
        exit(2);
    }

    let path = argv[1];
    var source: u8[>..] = [];
    if !read_file(path, source) {
        write_stderr(str("Cannot read ", path, "\n"));
        exit(2);
    }

    var tokens: Token[>..] = [];
    let lex_offset, lex_error = lex(source, tokens);
    if lex_error.len != 0 {
        report(path, source, lex_offset, "DG1001", lex_error);
        exit(1);
    }

    var nodes: SyntaxNode[>..] = [];
    let parse_offset, expected = parse(source, tokens, nodes);
    if expected.len != 0 {
        report(path, source, parse_offset, "DG1002", str("expected ", expected));
        exit(1);
    }

    var body: u8[>..] = [];
    let offset, problem, uses_library = convert(source, tokens, nodes, body);
    if problem.len != 0 {
        report(path, source, offset, "DG0001", problem);
        exit(1);
    }

    var output: u8[>..] = [];
    if uses_library { output.append("import .dotgoose;\n\n"); }
    output.append(body[..body.len - 1]);
    if argv.len == 2 {
        write_stdout(output);
    } else if !write_file_atomic(argv[3], output) {
        write_stderr(str("Cannot write ", argv[3], "\n"));
        exit(2);
    }
}

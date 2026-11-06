import os;
import .parser;

import .diagnostic;

fn main() {
    let argv = args();
    if argv.len != 2 {
        write_stderr("Usage: goose run compiler/native/check.goose -- input.cs\n");
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
    print("Parsed ", tokens.len - 1, " tokens and ", nodes.len, " syntax nodes.");
}

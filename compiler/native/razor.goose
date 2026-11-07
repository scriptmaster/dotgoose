namespace razor;

import std;
import .diagnostic;

fn name_start(c: u8) -> bool { return ascii::is_alpha(c) || c == '_'; }
fn name_continue(c: u8) -> bool { return name_start(c) || ascii::is_digit(c); }

fn identifier(s: const u8[:]) -> bool {
    if s.len == 0 || !name_start(s[0]) { return false; }
    for c in s {
        if !name_continue(c) { return false; }
    }
    return true;
}

fn model_identifier(s: const u8[:]) -> bool {
    return identifier(s) && s[0] >= 'A' && s[0] <= 'Z';
}

fn write_literal(out: u8[>..]&, literal: const u8[:]) {
    if literal.len == 0 { return; }
    out.append("    html.append(\"");
    for c in literal {
        if c == '"' { out.append("\\\""); }
        else if c == '\\' { out.append("\\\\"); }
        else if c == '\n' { out.append("\\n"); }
        else if c == '\r' { out.append("\\r"); }
        else if c == '\t' { out.append("\\t"); }
        else if c < 32 || c == 127 {
            const hex = "0123456789abcdef";
            out.append("\\x");
            out.push(hex[c >> 4]);
            out.push(hex[c & 15]);
        } else { out.push(c); }
    }
    out.append("\");\n");
}

fn compile_view(source: const u8[:], name: const u8[:], out: u8[>..]&) -> i64, const u8[:] {
    let offset = source_start(source);
    let source_text = source[offset..];
    let end = position(source_text, '\n');
    if end < 0 || !starts_with(source_text, "@model ") {
        return offset, "expected @model Type on the first line";
    }
    let model = trim(source_text[7..end]);
    if !model_identifier(model) { return offset + 7, "expected a PascalCase Goose model identifier"; }
    format(out, "fn ", name, "(model: ", model, ") -> u8[>..] {\n    var html: u8[>..] = [];\n");

    var cursor = end + 1;
    var literal_start = cursor;
    const member = "@Model.";
    while cursor < source_text.len {
        if source_text[cursor] != '@' { cursor++; continue; }
        write_literal(out, source_text[literal_start..cursor]);
        if starts_with(source_text[cursor..], "@@") {
            write_literal(out, "@");
            cursor += 2;
        } else if starts_with(source_text[cursor..], member) {
            let field_start = cursor + member.len;
            cursor = field_start;
            while cursor < source_text.len && name_continue(source_text[cursor]) { cursor++; }
            let field = source_text[field_start..cursor];
            if !model_identifier(field) { return offset + field_start, "expected a PascalCase model property"; }
            if cursor < source_text.len &&
                (source_text[cursor] == '(' || source_text[cursor] == '[' ||
                 (source_text[cursor] == '.' && cursor + 1 < source_text.len && name_start(source_text[cursor+1]))) {
                return offset + cursor, "expected a single model property";
            }
            format(out, "    web::HtmlValue(html, model.", field, ");\n");
        } else {
            return offset + cursor, "expected @Model.Property or @@";
        }
        literal_start = cursor;
    }
    write_literal(out, source_text[literal_start..]);
    out.append("    return html;\n}\n");
    return 0, "";
}

fn run(argv: u8[:][:]) {
    if !(argv.len == 2 || (argv.len == 4 && argv[2] == "--output" && argv[0] != argv[3])) {
        write_stderr("Usage: dotgoose razor TEMPLATE render_NAME [--output FILE]\n");
        exit(2);
    }
    let name = argv[1];
    if !starts_with(name, "render_") || name.len <= 7 || !identifier(name) {
        write_stderr("The view function name must begin with render_ and use ASCII identifier characters.\n");
        exit(2);
    }

    var source: u8[>..] = [];
    if !read_file(argv[0], source) {
        write_stderr(str("Cannot read ", argv[0], "\n"));
        exit(2);
    }
    var output: u8[>..] = [];
    let offset, error = compile_view(source, name, output);
    if error.len != 0 {
        report(argv[0], source, offset, "DG2001", error);
        exit(1);
    }
    if argv.len == 2 {
        write_stdout(output);
    } else if !write_file_atomic(argv[3], output) {
        write_stderr(str("Cannot write ", argv[3], "\n"));
        exit(2);
    }
}

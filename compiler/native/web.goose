namespace web_compiler;

import .diagnostic;

struct Lexeme { start: i64, end: i64 }

fn scan(source: const u8[:], tokens: Lexeme[>..]&) -> i64, const u8[:] {
    var cursor = source_start(source);
    while cursor < source.len {
        let start = cursor;
        let c = source[cursor];
        cursor++;
        if c <= ' ' { continue; }
        if c == '/' && cursor < source.len && source[cursor] == '/' {
            while cursor < source.len && source[cursor] != '\n' { cursor++; }
            continue;
        }
        if c == '/' && cursor < source.len && source[cursor] == '*' {
            cursor++;
            var nesting = 1;
            while cursor + 1 < source.len && nesting > 0 {
                if source[cursor..cursor+2] == "/*" { nesting++; cursor += 2; }
                else if source[cursor..cursor+2] == "*/" { nesting--; cursor += 2; }
                else { cursor++; }
            }
            if nesting > 0 { return start, "unterminated comment"; }
            continue;
        }
        if c == '"' || c == '\'' {
            let raw = c == '"' && start + 3 <= source.len && source[start..start+3] == "\"\"\"";
            let width = if raw { 3 } else { 1 };
            let delimiter = source[start..start+width];
            cursor = start + width;
            while cursor < source.len && !starts_with(source[cursor..], delimiter) {
                if !raw && source[cursor] == '\\' { cursor++; }
                cursor++;
            }
            if cursor + width > source.len { return start, "unterminated string or character literal"; }
            cursor += width;
        } else if word_start(c) {
            while cursor < source.len && (word_start(source[cursor]) || ascii::is_digit(source[cursor])) { cursor++; }
        }
        tokens.push(Lexeme { start: start, end: cursor });
    }
    return 0, "";
}

fn lower(source: const u8[:], output: u8[>..]&) -> i64, const u8[:] {
    var tokens: Lexeme[>..] = [];
    let scan_offset, scan_error = scan(source, tokens);
    if scan_error.len > 0 { return scan_offset, scan_error; }

    fn at(index: i64, word: const u8[:]) -> bool {
        return index < tokens.len && source[tokens[index].start..tokens[index].end] == word;
    }

    fn closing(index: i64, open: const u8[:], close: const u8[:]) -> i64 {
        var nesting = 0;
        for cursor in index..tokens.len {
            if at(cursor, open) { nesting++; }
            if at(cursor, close) {
                nesting--;
                if nesting == 0 { return cursor; }
            }
        }
        return -1;
    }

    var scoped_type = source[0..0];
    for i in 0..tokens.len {
        if at(i, ".") && at(i+1, "AddScoped") && at(i+2, "<") {
            let end = closing(i+2, "<", ">");
            if end < 0 { return tokens[i].start, "expected scoped service type"; }
            if scoped_type.len > 0 { return tokens[i].start, "one scoped service is supported"; }
            scoped_type = source[tokens[i+2].end..tokens[end].start];
        }
    }

    var handlers: u8[>..] = [];
    var dispatch: u8[>..] = [];
    var count: i32 = 0;
    var runs = 0;
    var copied = 0;
    var i = 0;
    while i + 2 < tokens.len {
        if !at(i, ".") || !at(i+2, "(") { i++; continue; }
        let get = at(i+1, "MapGet");
        let post = at(i+1, "MapPost");
        let middleware = at(i+1, "Use");
        let run = at(i+1, "Run");
        if !get && !post && !middleware && !run { i++; continue; }
        let end = closing(i+2, "(", ")");
        if end < 0 { return tokens[i].start, "expected closing parenthesis"; }
        output.append(source[copied..tokens[i+1].start]);
        if run {
            if end != i+3 { return tokens[i].start, "expected app.Run()"; }
            runs++;
            if runs > 1 { return tokens[i].start, "one application Run call is supported"; }
            if scoped_type.len > 0 { format(output, "RunScoped(default<", scoped_type, ">(), "); }
            else { output.append("Run("); }
            output.append("__dotgoose_dispatch)");
            copied = tokens[end].end;
            i = end+1;
            continue;
        }
        if count == 64 { return tokens[i].start, "at most 64 handlers are supported"; }
        if (middleware && end != i+3) || (!middleware && end == i+3) {
            return tokens[i].start, "expected a route argument for MapGet/MapPost or no arguments for Use";
        }
        if !at(end+1, "{") || end+5 >= tokens.len || !at(end+3, "=") || !at(end+4, ">") {
            return tokens[i].start, "expected a trailing handler block with one named request parameter";
        }
        let close = closing(end+1, "{", "}");
        if close < 0 { return tokens[end+1].start, "expected closing handler brace"; }
        let parameter = source[tokens[end+2].start..tokens[end+2].end];
        if !word_start(parameter[0]) { return tokens[end+2].start, "expected request parameter name"; }
        output.append(if get { "RegisterGet(" } else if post { "RegisterPost(" } else { "RegisterMiddleware(" });
        if !middleware { format(output, source[tokens[i+2].end..tokens[end].start], ", "); }
        format(output, count, ")");
        format(handlers, "\nfn __dotgoose_handler_", count, "<T>(", parameter, ": web::App<T>&) {",
               source[tokens[end+4].end..tokens[close].start], "}\n");
        format(dispatch, "    if handler == ", count, " { __dotgoose_handler_", count, "(request); return; }\n");
        count++;
        copied = tokens[close].end;
        i = close+1;
    }
    if runs != 1 { return source.len, "expected one app.Run() call"; }
    output.append(source[copied..]);
    output.append(handlers);
    output.append("\nfn __dotgoose_dispatch<T>(request: web::App<T>&, handler: i32) {\n");
    output.append(dispatch);
    output.append("    abort(\"unknown compiled web handler\");\n}\n");
    return 0, "";
}

fn run(argv: u8[:][:]) {
    if !(argv.len == 3 && argv[1] == "--output" && argv[0] != argv[2]) {
        write_stderr("Usage: dotgoose web INPUT.goose --output OUTPUT.goose\n");
        exit(2);
    }
    var source: u8[>..] = [];
    if !read_file(argv[0], source) { write_stderr(str("Cannot read ", argv[0], "\n")); exit(2); }
    var output: u8[>..] = [];
    let offset, error = lower(source, output);
    if error.len > 0 { report(argv[0], source, offset, "DG2101", error); exit(1); }
    if !write_file_atomic(argv[2], output) { write_stderr(str("Cannot write ", argv[2], "\n")); exit(2); }
}

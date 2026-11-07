import std;

fn write_quoted(output: u8[>..]&, text: const u8[:]) {
    output.push('"');
    const hex = "0123456789abcdef";
    for c in text {
        if c == '"' { output.append("\\\""); }
        else if c == '\\' { output.append("\\\\"); }
        else if c == '\n' { output.append("\\n"); }
        else if c == '\r' { output.append("\\r"); }
        else if c == '\t' { output.append("\\t"); }
        else if c < 32 || c == 127 {
            output.append("\\x");
            output.push(hex[c >> 4]);
            output.push(hex[c & 15]);
        } else { output.push(c); }
    }
    output.push('"');
}

fn raw_content(literal: const u8[:], decoded: u8[>..]&) -> const u8[:] {
    let width = quote_count(literal, 0);
    let content = literal[width..literal.len-width];
    if content.len == 0 { return "raw string requires content or a multiline delimiter"; }
    var start = 0;
    if starts_with(content, "\r\n") { start = 2; }
    else if starts_with(content, "\n") { start = 1; }
    if start == 0 {
        if find(content, "\n") >= 0 || find(content, "\r") >= 0 {
            return "multiline raw string requires the opening delimiter on its own line";
        }
        decoded.append(content);
        return "";
    }

    var last_line = content.len;
    while last_line > 0 && content[last_line-1] != '\n' { last_line--; }
    let indent = content[last_line..];
    for c in indent {
        if c != ' ' && c != '\t' { return "raw string closing delimiter must be on its own line"; }
    }
    var end = last_line-1;
    if end >= 0 && content[end] == '\n' && end > 0 && content[end-1] == '\r' { end--; }
    if end < start { return ""; }
    var cursor = start;
    while cursor <= end {
        var line_end = cursor;
        while line_end < end && content[line_end] != '\n' { line_end++; }
        let line = content[cursor..line_end];
        var spaces = 0;
        while spaces < line.len && (line[spaces] == ' ' || line[spaces] == '\t') { spaces++; }
        let blank = spaces == line.len || (spaces+1 == line.len && line[spaces] == '\r');
        let remove = if blank { min(spaces, indent.len) } else { indent.len };
        if line.len < remove || line[..remove] != indent[..remove] {
            return "raw string indentation does not match the closing delimiter";
        }
        decoded.append(line[remove..]);
        if line_end < end { decoded.push('\n'); }
        cursor = line_end+1;
    }
    return "";
}

fn write_interpolation_part(output: u8[>..]&, part: const u8[:], raw: bool) {
    if raw { write_quoted(output, part); return; }
    output.push('"');
    var cursor = 0;
    while cursor < part.len {
        let c = part[cursor];
        output.push(c);
        if (c == '{' || c == '}') && cursor+1 < part.len && part[cursor+1] == c { cursor++; }
        cursor++;
    }
    output.push('"');
}

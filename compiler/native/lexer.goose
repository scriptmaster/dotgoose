import std;

enum TokenKind { Word, Integer, String, RawString, InterpolatedStart, StringPart, RawPart,
                 InterpolationOpen, InterpolationClose, InterpolatedEnd, Punctuation, End }

struct Token {
    kind: TokenKind,
    start: i64,
    end: i64,
}

fn word_start(c: u8) -> bool {
    return ascii::is_alpha(c) || c == '_';
}

fn source_start(source: const u8[:]) -> i64 {
    if source.len >= 3 && source[0] == 0xef && source[1] == 0xbb && source[2] == 0xbf {
        return 3;
    }
    return 0;
}

fn quote_count(source: const u8[:], start: i64) -> i64 {
    var end = start;
    while end < source.len && source[end] == '"' { end++; }
    return end-start;
}

fn lex(source: const u8[:], tokens: Token[>..]&) -> i64, const u8[:] {
    return lex_strings(source, tokens, 0);
}

recursive fn lex_strings(source: const u8[:], tokens: Token[>..]&, depth: i64) -> i64, const u8[:] {
    if depth > 32 { return 0, "string nesting exceeds the limit"; }
    var pos = source_start(source);
    while pos < source.len {
        let start = pos;
        let c = source[pos];
        pos++;
        if c == ' ' || c == '\t' || c == '\x0b' || c == '\x0c' || c == '\r' || c == '\n' {
            continue;
        }
        if c == '/' && pos < source.len {
            if source[pos] == '/' {
                while pos < source.len && source[pos] != '\r' && source[pos] != '\n' { pos++; }
                continue;
            }
            if source[pos] == '*' {
                pos++;
                while pos + 1 < source.len && source[pos..pos + 2] != "*/" { pos++; }
                if pos + 1 >= source.len { return start, "unterminated block comment"; }
                pos += 2;
                continue;
            }
        }
        if word_start(c) {
            while pos < source.len && (word_start(source[pos]) || ascii::is_digit(source[pos])) { pos++; }
            tokens.push(Token { TokenKind.Word, start, pos });
        } else if ascii::is_digit(c) {
            while pos < source.len && ascii::is_digit(source[pos]) { pos++; }
            tokens.push(Token { TokenKind.Integer, start, pos });
        } else if c == '$' {
            var dollars = 1;
            while pos < source.len && source[pos] == '$' { dollars++; pos++; }
            let quote_run = quote_count(source, pos);
            if quote_run == 0 { return start, "expected interpolated string"; }
            let quotes = if quote_run >= 3 { quote_run } else { 1 };
            let raw = quotes >= 3;
            if !raw && dollars != 1 { return start, "regular interpolation requires one dollar sign"; }
            let delimiter = source[pos..pos+quotes];
            pos += quotes;
            tokens.push(Token { TokenKind.InterpolatedStart, start, pos });
            var part = pos;
            var ended = false;
            while pos < source.len {
                if starts_with(source[pos..], delimiter) {
                    tokens.push(Token { if raw { TokenKind.RawPart } else { TokenKind.StringPart }, part, pos });
                    tokens.push(Token { TokenKind.InterpolatedEnd, pos, pos+quotes });
                    pos += quotes;
                    ended = true;
                    break;
                }
                let current = source[pos];
                if current == '\n' || current == '\r' { return pos, "multiline interpolated strings are outside the starter profile"; }
                if !raw && current == '\\' {
                    if pos+1 >= source.len { return start, "unterminated interpolated string"; }
                    let escape = source[pos+1];
                    if escape != '"' && escape != '\\' && escape != 't' && escape != 'n' && escape != 'r' {
                        return pos+1, "unsupported string escape";
                    }
                    pos += 2;
                    continue;
                }
                if current == '{' || current == '}' {
                    var end = pos;
                    while end < source.len && source[end] == current { end++; }
                    let run = end-pos;
                    if !raw && run >= 2 { pos += 2; continue; }
                    if raw && run < dollars { pos = end; continue; }
                    if current == '}' { return pos, "unmatched interpolation closing brace"; }
                    if raw && run >= 2*dollars { return pos, "too many interpolation opening braces"; }
                    let open = end-dollars;
                    tokens.push(Token { if raw { TokenKind.RawPart } else { TokenKind.StringPart }, part, open });
                    tokens.push(Token { TokenKind.InterpolationOpen, open, end });
                    let expression_start = end;
                    pos = end;
                    while pos < source.len && source[pos] != '}' {
                        if source[pos] == '"' {
                            let width = quote_count(source, pos);
                            let quoted = if width >= 3 { width } else { 1 };
                            let stop = source[pos..pos+quoted];
                            pos += quoted;
                            while pos < source.len && !starts_with(source[pos..], stop) {
                                if quoted == 1 && source[pos] == '\\' { pos++; }
                                pos++;
                            }
                            if pos + quoted > source.len { return expression_start, "unterminated interpolation expression string"; }
                            pos += quoted;
                        } else { pos++; }
                    }
                    var close = pos;
                    while close < source.len && source[close] == '}' { close++; }
                    if close-pos < dollars { return expression_start, "unterminated interpolation expression"; }
                    let first_token = tokens.len;
                    let offset, error = lex_strings(source[expression_start..pos], tokens, depth+1);
                    if error.len > 0 { return expression_start+offset, error; }
                    for index in first_token..tokens.len {
                        tokens[index].start += expression_start;
                        tokens[index].end += expression_start;
                    }
                    tokens.push(Token { TokenKind.InterpolationClose, pos, pos+dollars });
                    pos += dollars;
                    part = pos;
                } else { pos++; }
            }
            if !ended { return start, "unterminated interpolated string"; }
        } else if c == '"' && quote_count(source, start) >= 3 {
            let width = quote_count(source, start);
            pos = start+width;
            while pos < source.len && quote_count(source, pos) < width { pos++; }
            if pos == source.len { return start, "unterminated raw string"; }
            pos += width;
            tokens.push(Token { TokenKind.RawString, start, pos });
        } else if c == '"' {
            while pos < source.len && source[pos] != '"' {
                let ch = source[pos];
                if ch < ' ' || ch > '~' { return pos, "character outside the starter string grammar"; }
                if ch == '\\' {
                    pos++;
                    if pos >= source.len { return start, "unterminated string"; }
                    let escape = source[pos];
                    if escape != '"' && escape != '\\' && escape != 't' && escape != 'n' && escape != 'r' {
                        return pos, "unsupported string escape";
                    }
                }
                pos++;
            }
            if pos == source.len { return start, "unterminated string"; }
            pos++;
            tokens.push(Token { TokenKind.String, start, pos });
        } else if c == '=' || c == '!' || c == '<' || c == '>' {
            if pos < source.len && source[pos] == '=' { pos++; }
            if c == '!' && pos == start + 1 { return start, "unsupported punctuation"; }
            tokens.push(Token { TokenKind.Punctuation, start, pos });
        } else if c == '{' || c == '}' || c == '(' || c == ')' || c == ';' ||
                  c == ',' || c == '.' || c == '+' || c == '-' {
            if (c == '+' || c == '-') && pos < source.len && source[pos] == c {
                return start, "increment and decrement are outside the starter syntax";
            }
            tokens.push(Token { TokenKind.Punctuation, start, pos });
        } else {
            return start, "unsupported source character";
        }
    }
    if depth == 0 { tokens.push(Token { TokenKind.End, pos, pos }); }
    return pos, "";
}

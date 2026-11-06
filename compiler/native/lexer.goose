import std;

enum TokenKind { Word, Integer, String, Punctuation, End }

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

fn lex(source: const u8[:], tokens: Token[>..]&) -> i64, const u8[:] {
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
    tokens.push(Token { TokenKind.End, pos, pos });
    return pos, "";
}

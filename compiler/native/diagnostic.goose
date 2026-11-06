import os;
import .lexer;

fn report(path: const u8[:], source: const u8[:], offset: i64, code: const u8[:], message: const u8[:]) {
    var line = 1;
    var column = 1;
    var previous_cr = false;
    for i in source_start(source)..offset {
        let c = source[i];
        if c == '\r' || c == '\n' {
            if c == '\r' || !previous_cr { line++; }
            column = 1;
        } else {
            column++;
        }
        previous_cr = c == '\r';
    }
    write_stderr(str(path, "(", line, ",", column, "): error ", code, ": ", message, "\n"));
}

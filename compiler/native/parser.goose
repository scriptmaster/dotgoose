import .lexer;

enum SyntaxKind {
    Unit, Using, Type, Field, Constructor, Method, Parameter, Block,
    Local, Variable, If, While, Return, Assignment, ExpressionStatement,
    Name, Literal, Group, New, Member, Call, Unary, Binary,
}

struct SyntaxNode {
    kind: SyntaxKind,
    first_token: i64,
    end_token: i64,
    subtree_start: i64,
}

fn is_reserved(word: const u8[:]) -> bool {
    const keywords = """
        |abstract|as|base|bool|break|byte|case|catch|char|checked|class|const|continue|
        |decimal|default|delegate|do|double|else|enum|event|explicit|extern|false|finally|
        |fixed|float|for|foreach|goto|if|implicit|in|int|interface|internal|is|lock|
        |long|namespace|new|null|object|operator|out|override|params|private|protected|
        |public|readonly|ref|return|sbyte|sealed|short|sizeof|stackalloc|static|string|
        |struct|switch|this|throw|true|try|typeof|uint|ulong|unchecked|unsafe|ushort|
        |using|virtual|void|volatile|while|
        """;
    return find(keywords, str("|", word, "|")) >= 0;
}

fn parse(source: const u8[:], tokens: const Token[:], nodes: SyntaxNode[>..]&) -> i64, const u8[:] {
    var pos = 0;

    fn spelling(index: i64) -> const u8[:] {
        let token = tokens[index];
        return source[token.start..token.end];
    }

    fn at(word: const u8[:]) -> bool { return spelling(pos) == word; }

    fn take(word: const u8[:]) -> bool {
        if !at(word) { return false; }
        pos++;
        return true;
    }

    fn expect(word: const u8[:]) {
        if !take(word) { return tokens[pos].start, word from parse; }
    }

    fn is_name(index: i64) -> bool {
        return tokens[index].kind == TokenKind.Word && !is_reserved(spelling(index));
    }

    fn name() {
        if !is_name(pos) { return tokens[pos].start, "identifier" from parse; }
        pos++;
    }

    fn type_name() {
        if !take("int") && !take("bool") { name(); }
    }

    fn modifiers() {
        while take("public") || take("private") || take("internal") || take("static") || take("sealed") {}
    }

    fn add(kind: SyntaxKind, start: i64, subtree: i64) {
        nodes.push(SyntaxNode { kind, start, pos, subtree });
    }

    fn precedence() -> i64 {
        if at("==") || at("!=") { return 1; }
        if at("<") || at(">") || at("<=") || at(">=") { return 2; }
        if at("+") { return 3; }
        return 0;
    }

    recursive fn arguments(depth: i64) {
        expect("(");
        if !at(")") {
            expression(1, depth);
            while take(",") { expression(1, depth); }
        }
        expect(")");
    }

    recursive fn primary(depth: i64) {
        if depth >= 256 { return tokens[pos].start, "expression within the nesting limit" from parse; }
        let start = pos;
        let subtree = nodes.len;
        if take("new") {
            type_name();
            arguments(depth + 1);
            add(SyntaxKind.New, start, subtree);
        } else if take("(") {
            expression(1, depth + 1);
            expect(")");
            add(SyntaxKind.Group, start, subtree);
        } else if take("-") {
            primary(depth + 1);
            add(SyntaxKind.Unary, start, subtree);
            return;
        } else if tokens[pos].kind == TokenKind.Integer || tokens[pos].kind == TokenKind.String ||
                  at("true") || at("false") {
            pos++;
            add(SyntaxKind.Literal, start, subtree);
        } else {
            if !take("this") { name(); }
            add(SyntaxKind.Name, start, subtree);
        }

        loop {
            if take(".") {
                name();
                add(SyntaxKind.Member, start, subtree);
            } else if at("(") {
                arguments(depth + 1);
                add(SyntaxKind.Call, start, subtree);
            } else {
                break;
            }
        }
    }

    recursive fn expression(min_precedence: i64, depth: i64) {
        let start = pos;
        let subtree = nodes.len;
        primary(depth);
        loop {
            let level = precedence();
            if level < min_precedence { break; }
            pos++;
            expression(level + 1, depth + 1);
            add(SyntaxKind.Binary, start, subtree);
        }
    }

    fn parameters() {
        expect("(");
        if !at(")") {
            loop {
                let start = pos;
                type_name();
                name();
                add(SyntaxKind.Parameter, start, nodes.len);
                if !take(",") { break; }
            }
        }
        expect(")");
    }

    recursive fn parse_block(depth: i64) {
        if depth >= 256 { return tokens[pos].start, "block within the nesting limit" from parse; }
        let start = pos;
        let subtree = nodes.len;
        expect("{");
        while !at("}") {
            statement(depth);
        }
        expect("}");
        add(SyntaxKind.Block, start, subtree);
    }

    recursive fn statement(depth: i64) {
        let start = pos;
        let subtree = nodes.len;
        if at("if") || at("while") {
            let branch = take("if");
            if !branch { expect("while"); }
            expect("(");
            expression(1, 0);
            expect(")");
            parse_block(depth + 1);
            if branch && take("else") { parse_block(depth + 1); }
            add(if branch { SyntaxKind.If } else { SyntaxKind.While }, start, subtree);
        } else if take("return") {
            if !at(";") { expression(1, 0); }
            expect(";");
            add(SyntaxKind.Return, start, subtree);
        } else if at("int") || at("bool") || (is_name(pos) && is_name(pos + 1)) {
            type_name();
            loop {
                let variable = pos;
                let initializer = nodes.len;
                name();
                expect("=");
                expression(1, 0);
                add(SyntaxKind.Variable, variable, initializer);
                if !take(",") { break; }
            }
            expect(";");
            add(SyntaxKind.Local, start, subtree);
        } else {
            expression(1, 0);
            let assignment = take("=");
            if assignment { expression(1, 0); }
            expect(";");
            add(if assignment { SyntaxKind.Assignment } else { SyntaxKind.ExpressionStatement }, start, subtree);
        }
    }

    fn member() {
        let start = pos;
        let subtree = nodes.len;
        modifiers();
        if is_name(pos) && spelling(pos + 1) == "(" {
            name();
            parameters();
            parse_block(0);
            add(SyntaxKind.Constructor, start, subtree);
            return;
        }
        if !take("void") { type_name(); }
        name();
        if at("(") {
            parameters();
            parse_block(0);
            add(SyntaxKind.Method, start, subtree);
        } else {
            while take(",") { name(); }
            expect(";");
            add(SyntaxKind.Field, start, subtree);
        }
    }

    let root = nodes.len;
    while at("using") {
        let start = pos;
        expect("using");
        name();
        while take(".") { name(); }
        expect(";");
        add(SyntaxKind.Using, start, nodes.len);
    }
    while tokens[pos].kind != TokenKind.End {
        let start = pos;
        let subtree = nodes.len;
        modifiers();
        if !take("class") { expect("struct"); }
        name();
        expect("{");
        while !at("}") { member(); }
        expect("}");
        add(SyntaxKind.Type, start, subtree);
    }
    add(SyntaxKind.Unit, 0, root);
    return tokens[pos].start, "";
}

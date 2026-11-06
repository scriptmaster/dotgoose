import parser from "../compiler/native";

fn main() {
    const source = "class Example { int Value() { return x == y + z + w; } }";
    var tokens: Token[>..] = [];
    let _, lex_error = lex(source, tokens);
    assert(lex_error.len == 0);
    var nodes: SyntaxNode[>..] = [];
    let _, parse_error = parse(source, tokens, nodes);
    assert(parse_error.len == 0);

    // x == ((y + z) + w), in postorder. Each parent stores the start of its subtree.
    assert(nodes[0].kind == SyntaxKind.Name);
    assert(nodes[3].kind == SyntaxKind.Binary && nodes[3].subtree_start == 1);
    assert(nodes[5].kind == SyntaxKind.Binary && nodes[5].subtree_start == 1);
    assert(nodes[6].kind == SyntaxKind.Binary && nodes[6].subtree_start == 0);
    let equality = nodes[6];
    assert(equality.first_child == 0);
    assert(nodes[0].next_sibling == 5 && nodes[5].next_sibling == -1);
    assert(nodes[5].first_child == 3 && nodes[3].next_sibling == 4);
    let start = tokens[equality.first_token].start;
    let end = tokens[equality.end_token - 1].end;
    assert(source[start..end] == "x == y + z + w");
    assert(nodes[nodes.len - 1].kind == SyntaxKind.Unit);
}

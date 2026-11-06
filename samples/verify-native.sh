#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
goose=${GOOSE:-goose}
check=("$goose" run "$root/compiler/native/check.goose" --)
"$goose" run "$root/compiler/native/test_parser.goose"

[[ $("${check[@]}" "$root/samples/basics/Program.cs") == 'Parsed 62 tokens and 38 syntax nodes.' ]]
[[ $("${check[@]}" "$root/samples/objects/Program.cs") == 'Parsed 164 tokens and 82 syntax nodes.' ]]

expect_error() {
    local source=$1 diagnostic=$2
    if "${check[@]}" "$source" > "$work/out" 2> "$work/err"; then
        printf 'Expected rejection of %s\n' "$source" >&2
        exit 1
    else
        test "$?" -eq 1
    fi
    test ! -s "$work/out"
    diff -u <(printf '%s%s\n' "$source" "$diagnostic") "$work/err"
}

printf 'static class Program {\r\nstatic void Main() {\r\nint x = ;\r\n}\r\n}\r\n' > "$work/syntax.cs"
expect_error "$work/syntax.cs" '(3,9): error DG1002: expected identifier'
printf '/* unterminated' > "$work/lex.cs"
expect_error "$work/lex.cs" '(1,1): error DG1001: unterminated block comment'
printf '\xef\xbb\xbf#' > "$work/bom.cs"
expect_error "$work/bom.cs" '(1,1): error DG1001: unsupported source character'
printf 'struct switch {}' > "$work/keyword.cs"
expect_error "$work/keyword.cs" '(1,8): error DG1002: expected identifier'
printf 'static class Program { static void Main() {' > "$work/eof.cs"
expect_error "$work/eof.cs" '(1,44): error DG1002: expected identifier'
printf 'Native parser samples and diagnostics passed.\n'

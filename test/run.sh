#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
goose=${GOOSE:-goose}
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
export DOTNET_NOLOGO=1
export GOOSE_HOME="$work/goose-home"

bash "$root/test/syntax.sh"
compiler=("$goose" run "$root/compiler/native/dotgoose.goose" --)
positive=0
for source in "$root"/samples/*/Program.cs "$root"/test/programs/*.cs; do
    label=${source#"$root/"}
    case_dir="$work/program-$positive"
    mkdir "$case_dir"
    cp "$source" "$case_dir/Program.cs"
    cp "$root/test/Sample.csproj" "$root/lib/dotgoose.goose" "$case_dir/"

    if ! dotnet build "$case_dir/Sample.csproj" --nologo -v:q > "$case_dir/build.log" 2>&1; then
        cat "$case_dir/build.log" >&2
        exit 1
    fi
    dotnet "$case_dir/bin/Debug/net10.0/Sample.dll" > "$case_dir/dotnet.stdout" 2> "$case_dir/dotnet.stderr"
    "${compiler[@]}" "$source" --output "$case_dir/program.goose"
    "${compiler[@]}" "$source" > "$case_dir/compiler.stdout"
    diff -u "$case_dir/program.goose" "$case_dir/compiler.stdout"

    fixture_dir=$(dirname "$source")
    if [[ $label == samples/* ]]; then
        diff -u "$fixture_dir/expected.goose" "$case_dir/program.goose"
        diff -u "$fixture_dir/expected.txt" "$case_dir/dotnet.stdout"
    fi

    "$goose" build "$case_dir/program.goose" -o "$case_dir/program" > "$case_dir/goose-build.log" 2>&1 || {
        cat "$case_dir/goose-build.log" >&2
        exit 1
    }
    "$case_dir/program" > "$case_dir/goose.stdout" 2> "$case_dir/goose.stderr"
    "$goose" run "$case_dir/program.goose" --debug > "$case_dir/debug.stdout" 2> "$case_dir/debug.stderr"
    for mode in goose debug; do
        diff -u "$case_dir/dotnet.stdout" "$case_dir/$mode.stdout"
        diff -u "$case_dir/dotnet.stderr" "$case_dir/$mode.stderr"
    done
    printf 'PASS %s (.NET, Goose executable, Goose debug)\n' "$label"
    positive=$((positive + 1))
done

reject() {
    local source=$1 expected=$2
    printf 'preserved\n' > "$work/rejected.goose"
    if "${compiler[@]}" "$source" --output "$work/rejected.goose" > "$work/stdout" 2> "$work/stderr"; then
        printf 'Expected the compiler to reject %s\n' "$source" >&2
        exit 1
    else
        test "$?" -eq 1
    fi
    test ! -s "$work/stdout"
    diff -u <(printf 'preserved\n') "$work/rejected.goose"
    grep -Fq "$expected" "$work/stderr" || { cat "$work/stderr" >&2; exit 1; }
    printf 'PASS %s (rejected, output preserved)\n' "${source#"$root/"}"
}

negative=0
for source in "$root"/test/rejected/*.cs; do
    reject "$source" "$(<"${source%.cs}.txt")"
    negative=$((negative + 1))
done
reject "$root/samples/rejected/class-alias.cs" 'DG0001: class values require a direct receiver'
negative=$((negative + 1))
printf 'PASS %d differential programs, %d rejected programs, and native parser checks.\n' "$positive" "$negative"

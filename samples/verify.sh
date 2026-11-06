#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
goose=${GOOSE:-goose}
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1

dotnet build "$root/compiler" --nologo -o "$work/compiler"
compiler=(dotnet "$work/compiler/DotGoose.dll")
for sample in basics objects; do
    source="$root/samples/$sample"
    target="$work/$sample"
    mkdir "$target"
    cp "$source/Program.cs" "$root/lib/dotgoose.goose" "$target/"
    cat > "$target/Sample.csproj" <<'PROJECT'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net10.0</TargetFramework>
  </PropertyGroup>
</Project>
PROJECT
    dotnet build "$target/Sample.csproj" --nologo -o "$target/app"
    dotnet "$target/app/Sample.dll" > "$target/csharp.txt"
    diff -u "$source/expected.txt" "$target/csharp.txt"

    "${compiler[@]}" "$target/Program.cs" --output "$target/program.goose"
    diff -u "$source/expected.goose" "$target/program.goose"
    "$goose" run "$target/program.goose" > "$target/goose.txt"
    diff -u "$target/csharp.txt" "$target/goose.txt"
done

printf 'preserved\n' > "$work/rejected.goose"
if "${compiler[@]}" "$root/samples/rejected/class-alias.cs" --output "$work/rejected.goose" \
    > "$work/rejected.stdout" 2> "$work/rejected.stderr"; then
    printf 'Expected the compiler to reject a class alias.\n' >&2
    exit 1
else
    test "$?" -eq 1
fi
test ! -s "$work/rejected.stdout"
diff -u <(printf 'preserved\n') "$work/rejected.goose"
grep -q 'class-alias.cs.*error DG0001' "$work/rejected.stderr"
printf 'C# and Goose samples agree. Class alias diagnostic passed.\n'

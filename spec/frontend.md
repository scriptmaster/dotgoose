# Goose-native C# frontend

Implement C# from the [language specification](https://learn.microsoft.com/dotnet/csharp/specification/) and the versioned feature specifications linked there. The first target is the [starter conversion profile](language.md). Roslyn can serve as a development oracle for disputed inputs. Building and running the native compiler requires Goose and its normal toolchain, with no .NET SDK, CLR, Roslyn assemblies or subprocess.

## Pipeline

1. **Lexing.** Scan C# source into tokens with byte spans and map source offsets to diagnostic locations. The first slice covers ASCII words, decimal integers, regular strings with a limited escape set, comments, whitespace and the starter punctuation. Its diagnostics use one-based byte columns and ignore a leading UTF-8 BOM when calculating the column. Later slices add Unicode identifiers, contextual directives and the remaining literal forms.
2. **Parsing.** Use recursive descent for declarations and statements, and precedence climbing for expressions. Keep tokens and a flat syntax tree in separate arenas. Each node has a token range, an index marking the start of its postorder subtree, and child and sibling links. This keeps source ranges available for binding and diagnostics. The parser stops at the first syntax error. Its syntax checks are independent of name lookup and type checking.
3. **Binding.** Build scopes and symbol tables from source and versioned BCL signatures. Resolve fields, overloads, constructors, conversions and entry points. Check accessibility, definite assignment and the starter restrictions on object identity. Extend with native metadata reading and a documented subset of SDK-style project evaluation as the backend profile grows. Project loading and NuGet resolution must run without MSBuild or the `dotnet` CLI.
4. **Lowering and emission.** Lower bound nodes according to the starter rules, then emit deterministic Goose source. Keep evaluation order and arithmetic behavior explicit. Preserve source spans for unsupported-feature diagnostics.

## Verification

- Run the native syntax fixtures with Goose alone. Check successful trees, malformed syntax, lexical failures and source locations.
- Reproduce the starter golden Goose files byte for byte. Run the emitted programs and compare their stdout with the checked-in expected output. Check negative cases, including class aliases and invalid source, before writing any output.
- For every new positive fixture, compile and run the original C# and emitted Goose under the same invariant culture and compare stdout and stderr. The suite builds a Goose executable and also runs Goose with debug checks. The native frontend checks run independently of .NET.

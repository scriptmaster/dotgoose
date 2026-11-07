# Starter language profile

## Input and output

Run `goose run compiler/native/dotgoose.goose -- input.cs [--output output.goose]`. With no output path the compiler writes Goose to stdout. The program reads one UTF-8 C# compilation unit with optional `using System;` and exactly one explicit `static class Program` containing only `static void Main()`. Additional top-level declarations can be simple nonempty structs or sealed classes. The native binder uses source declarations and the supported console signatures. Project loading, implicit usings, project-specific defines and source generators are later work.

Exit codes are 0 on success, 1 for invalid or unsupported source, and 2 for invalid invocation or file errors. Lexical and syntax failures report `DG1001` and `DG1002`. Binding and lowering failures report `DG0001`. Diagnostics include the source position. Translation errors leave stdout empty and any existing output file intact. Output uses UTF-8, LF, four-space indentation and a final newline.

## Values and statements

| C# | Goose | Starter rules |
| --- | --- | --- |
| `int`, `bool`, `void` | `i32`, `bool`, omitted result | Scalar declarations carry explicit types to avoid Goose literal inference. |
| Decimal integer and Boolean literals | Canonical decimal and Boolean literals | An integer literal may have a leading unary minus. |
| String literals | Goose UTF-8 literals | Regular printable ASCII strings with quote, backslash, tab, LF and CR escapes. Raw literals support UTF-8 content, literal backslashes, variable quote delimiters, and closing-delimiter indentation removal. |
| String locals | Owned Goose byte arrays | Literal and interpolated initializers, copying, assignment, and console output. Reference identity, indexing, and string operators require later profiles. |
| `$"...{expression}..."` and single-line interpolated raw literals | `str(...)` | Parse and bind each expression through the normal frontend. Holes support text, Int32, and Boolean. Preserve expression evaluation order and C# `True`/`False` text under invariant culture. Raw interpolation uses the dollar count to determine the brace delimiter. |
| Initialized locals and simple assignments | `var` and `=` | Assign scalar locals or fields, or whole struct locals. Struct assignment copies the value. |
| `+` on `int` | `a.add(b)` | `import .dotgoose;` provides the global `i32` overload. `dotgoose::add(a, b)` is the qualified form. Reject overflowing compile-time constants and preserve unchecked 32-bit wrap for runtime values in every Goose build. |
| `==`, `!=`, `<`, `<=`, `>`, `>=` | Corresponding Goose operators | Identical scalar types. Ordered comparisons require integers. |
| Braced `if`, `else`, `while`, `return` | Corresponding Goose statements | Branch and loop bodies require braces. Value-returning methods require an explicit return on all structural paths, independent of constant-condition reachability. |
| `System.Console.WriteLine(int/string)` | `print(value)` | Matches the bound overload. Integer output uses the invariant decimal form. Sample parity is defined under invariant culture and LF output. |

Directives and source comments have different roles. Directives require project-level policy and are rejected. Source comments are omitted in the starter profile. Unsupported statements and expressions are rejected even in unreachable code.

The [strings sample](../samples/strings/Program.cs) and its [generated Goose](../samples/strings/expected.goose) cover JSON raw literals, backslashes, indentation, longer quote delimiters, brace escaping, interpolation expressions, Boolean formatting, text locals, and side effects. Triple-quoted C# literals retain the same raw form in Goose when their newline semantics agree. Longer delimiters and CRLF raw contents are decoded and emitted with Goose escapes. The differential suite includes a generated CRLF source file. Interpolation format specifiers, alignment, culture providers, and multiline interpolated literals are diagnosed by this profile. [C# raw string rules](https://learn.microsoft.com/dotnet/csharp/language-reference/tokens/raw-string)

## Data and construction

A C# struct becomes a Goose struct. A sealed class can use the same representation if every instance is confined to its construction local. The starter permits field access and direct receiver calls through that local. A class cannot be copied, reassigned, passed, returned, stored in another object or compared. These restrictions preserve reference identity by ensuring it is never observed. Structs retain value semantics and can be copied between locals.

Types have instance fields of `int` or `bool` without field initializers. One optional explicit constructor has scalar parameters and no initializer clause. A constructor becomes `new_Type(...)`, which initializes fields to C# defaults, runs the original body against `receiver`, and returns the finished value. An implicit parameterless constructor becomes a struct literal with default field values. `new Type(...)` is supported in local initializers. Object initializers and target-typed `new` require separate rules.

Instance methods become Goose functions with a writable `receiver: Type&` receiver and keep `s.Method(...)` call syntax through Goose's receiver-call rule. Methods have scalar parameters and return scalars or void. Calls must resolve to an in-source method on the exact receiver type with positional arguments. Validate access modifiers before dropping them from the closed program. Inheritance, interfaces, readonly storage, overloads within a type, recursion and implicit conversions beyond identity are outside the starter profile.

The starter accepts Goose-compatible ASCII identifiers. Type and instance method names begin with an uppercase letter. It reserves Goose keywords, the generated `receiver` and `main` identifiers, the `new_` prefix, and names used by emitted library calls. Later profiles require deterministic symbol mangling, including namespace, overload and generic identities.

If the output imports `dotgoose`, place `lib/dotgoose.goose` beside the emitted program. The import resolves relative to the emitted source file.

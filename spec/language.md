# Starter language profile

## Input and output

Run `dotgoose input.cs [--output output.goose]`. With no output path the compiler writes Goose to stdout. The program reads one UTF-8 C# compilation unit with optional `using System;` and exactly one explicit `static class Program` containing only `static void Main()`. Additional top-level declarations can be simple nonempty structs or sealed classes. Source compilation uses regular C# and the host framework references. Project loading, implicit usings, project-specific defines and source generators are later work.

Exit codes are 0 on success, 1 for invalid or unsupported source, and 2 for invalid invocation or file errors. Preserve Roslyn errors. Report unsupported constructs with `DG0001` and a source position. Translation errors leave stdout empty and any existing output file intact. Output uses UTF-8, LF, four-space indentation and a final newline.

## Values and statements

| C# | Goose | Starter rules |
| --- | --- | --- |
| `int`, `bool`, `void` | `i32`, `bool`, omitted result | Scalar declarations carry explicit types to avoid Goose literal inference. |
| Integer and Boolean literals | Canonical decimal and Boolean literals | Integer constants may include a unary minus. |
| String literals | Goose UTF-8 literals | Only as direct arguments to the supported string overload of `Console.WriteLine`. Printable ASCII plus tab, LF and CR. |
| Initialized locals and simple assignments | `var` and `=` | Assign scalar locals or fields, or whole struct locals. Struct assignment copies the value. |
| `+` on `int` | `dotgoose::add_i32(a, b)` | Preserve unchecked 32-bit wrap in every Goose build. Explicit checked or unchecked blocks and expressions are outside the starter profile. |
| `==`, `!=`, `<`, `<=`, `>`, `>=` | Corresponding Goose operators | Identical scalar types. Ordered comparisons require integers. |
| Braced `if`, `else`, `while`, `return` | Corresponding Goose statements | Branch and loop bodies require braces. |
| `System.Console.WriteLine(int/string)` | `print(value)` | Matches the bound overload. Integer output uses the invariant decimal form. Sample parity is defined under invariant culture and LF output. |

Directives and source comments have different roles. Directives require project-level policy and are rejected. Source comments are omitted in the starter profile. Unsupported statements and expressions are rejected even in unreachable code.

## Data and construction

A C# struct becomes a Goose struct. A sealed class can use the same representation if every instance is confined to its construction local. The starter permits field access and direct receiver calls through that local. A class cannot be copied, reassigned, passed, returned, stored in another object or compared. These restrictions preserve reference identity by ensuring it is never observed. Structs retain value semantics and can be copied between locals.

Types have instance fields of `int` or `bool` without field initializers. One optional explicit constructor has scalar parameters and no initializer clause. A constructor becomes `new_Type(...)`, which initializes fields to C# defaults, runs the original body against `receiver`, and returns the finished value. An implicit parameterless constructor becomes a struct literal with default field values. `new Type(...)` is supported in local initializers. Object initializers and target-typed `new` require separate rules.

Instance methods become Goose functions with a writable `receiver: Type&` receiver and keep `s.Method(...)` call syntax through Goose's receiver-call rule. Methods have scalar parameters and return scalars or void. Calls must resolve to an in-source method on the exact receiver type with positional arguments. Access modifiers are validated by Roslyn, then dropped from the closed program. Inheritance, interfaces, readonly storage, overloads within a type, recursion and implicit conversions beyond identity are outside the starter profile.

The starter accepts Goose-compatible ASCII identifiers. Type and instance method names begin with an uppercase letter. It reserves Goose keywords, the generated `receiver` and `main` identifiers, the `new_` prefix, and names used by emitted library calls. Later profiles require deterministic symbol mangling, including namespace, overload and generic identities.

If the output imports `dotgoose`, place `lib/dotgoose.goose` beside the emitted program. The import resolves relative to the emitted source file.

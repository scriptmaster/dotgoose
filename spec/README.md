# DotGoose conversion specification

DotGoose translates C# source to readable, compilable Goose source. Observable behavior takes precedence over line-by-line similarity. Where Goose can represent the same behavior directly, preserve source names, declaration order, and receiver-call syntax. Use the DotGoose library for semantic differences and curated .NET APIs. Require a source-located diagnostic whenever a translation rule is missing or its preconditions cannot be established.

The target is [Aardappel Goose](https://github.com/aardappel/goose/tree/7b90f91d91845f4ef1712e16ed053f395e4e6e1c), pinned to revision `7b90f91d91845f4ef1712e16ed053f395e4e6e1c`. The native compiler implements the starter profile in Goose and runs with the Goose toolchain alone. The differential suite uses .NET 10 to compile and run the original C# fixtures.

- [Starter language profile](language.md) specifies the implemented single-file conversion.
- [Native frontend](frontend.md) specifies the Goose-only compiler and its migration gates.
- [Backend and library](backend.md) specifies planned BCL, package and ASP.NET Core compatibility.
- [Windows platform](windows.md) specifies the 2.0 scope and acceptance gates.

Add a runnable C#/Goose pair before implementing each lowering. A positive fixture checks expected Goose source and compares program output. Negative fixtures cover behaviors that would silently change if mapped to a superficially similar Goose construct.

## Design directions

1. **Native Goose with a small compatibility library** is the starting profile. Use local storage, concrete types and direct calls. Reject CLR semantics that cannot be preserved with proven lowering rules. This gives the cleanest output and the shortest path to runnable ports.
2. **Managed behavior in Goose** adds explicit object handles, dispatch and an async runtime where required. It supports more existing code at the cost of runtime complexity and more generated machinery. Choose this where identity, escaping aliases or scheduling are unavoidable.
3. **Interop-assisted migration** keeps selected components behind a native or managed boundary while the rest runs as Goose. It helps when source is unavailable or native platform APIs are essential. A project must opt in and record the dependency and ABI.

A feature may move from the second or third direction to the first when the compiler can prove equivalence. The backend release must specify which features require each direction.

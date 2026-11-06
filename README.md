# DotGoose

DotGoose converts C# into readable [Goose](https://github.com/aardappel/goose) source. It starts with runnable pairs of C# and Goose programs. The [spec](spec/README.md) defines the conversion and the [DotGoose library](lib/dotgoose.goose) supplies compatibility operations that need explicit .NET semantics.

The starter translates a single C# file. It supports scalar code, basic control flow, selected console calls, value-type structs and scoped sealed classes. In the [objects sample](samples/objects/Program.cs), `new Counter(40)` becomes `new_Counter(40)` and `counter.Add(2)` keeps the same call shape. [See the Goose output.](samples/objects/expected.goose)

## Goose-native frontend

The compiler is moving to a Goose implementation of the C# specification. The native syntax checker reads both starter samples and builds a syntax tree with source spans. It runs with the pinned Goose toolchain alone.

```sh
goose run compiler/native/check.goose -- samples/objects/Program.cs
GOOSE=goose bash samples/verify-native.sh
```

## Run a conversion sample

The reference converter uses the .NET 10 SDK while the native binder and emitter are being built. Run this from the repository root with the [pinned Goose toolchain](spec/README.md).

```sh
cp lib/dotgoose.goose samples/objects/dotgoose.goose
dotnet run --project compiler -- samples/objects/Program.cs --output samples/objects/actual.goose
goose run samples/objects/actual.goose
```

Run `bash samples/verify.sh` to compare generated source and output for both programs. Set `GOOSE` to the path to your Goose executable if it is outside `PATH`.

## Roadmap

| Release | Status | Feature set | Complexity |
| --- | --- | --- | --- |
| Starter reference | Implemented | Single-file conversion with Roslyn, explicit entry point, `int` and `bool`, basic control flow, console output, struct copies, scoped classes, constructors, receiver methods and unchecked addition | Low to medium. Each rule has a small, closed input domain. |
| Goose-native starter | In progress | Lexer and syntax tree for the sample grammar, followed by native binding, lowering, diagnostics and a Goose-only conversion CLI | High. The native converter must match the reference samples and reject unsupported semantics before replacing it. |
| 1.0 frontend | Planned | Extend the native compiler with SDK-style project ingestion, multiple files, namespaces, source maps, overloads, conversions, operators, arrays, nullable types, tuples, pattern matching, records, properties, initializers, generics, interfaces and delegates | Very high. Contextual grammar and semantic binding must agree, and project loading needs its own dependency model. |
| 1.0 object and execution semantics | Planned | Escaping references, identity, inheritance, virtual dispatch, closures, boxing, exception handling, disposal, iterators, async/await, cancellation and synchronization | Very high. These require lifetime analysis or an explicit runtime representation. |
| 1.0 BCL | Planned | Text, encoding, numeric and date types, collections, LINQ, spans, streams, files, environment, JSON, HTTP clients and cryptography | High. Match encodings, culture, comparer, errors, ordering and resource behavior. |
| 1.0 NuGet | Planned | Curated Newtonsoft.Json, Serilog and Dapper mappings, plus locked package resolution, licensed C# source acquisition and conversion through the normal compiler | Very high. Package source and platform compatibility vary by version. |
| 1.0 ASP.NET Core | Planned | Full HTTP server sample, minimal APIs, middleware, routing, validation, dependency injection, configuration, JSON, logging, auth, health, TLS and graceful shutdown | Very high. Transport, cancellation, request ownership and observable HTTP behavior must agree. |
| 2.0 Windows | Planned | Windows SDK projection, Win32, P/Invoke, COM, WinRT, Windows services, and staged WinForms, WPF and WinUI support | Very high. ABI, architecture, apartment, UI thread and packaging coverage must be validated on Windows. |

Read the [backend and package spec](spec/backend.md) and the [Windows spec](spec/windows.md) for release acceptance criteria.

# DotGoose

DotGoose converts C# into readable [Goose](https://github.com/aardappel/goose) source. It starts with runnable pairs of C# and Goose programs. The [spec](spec/README.md) defines the conversion and the [DotGoose library](lib/dotgoose.goose) supplies compatibility operations that need explicit .NET semantics.

The starter translates a single C# file. It supports scalar code, basic control flow, selected console calls, value-type structs and scoped sealed classes. In the [objects sample](samples/objects/Program.cs), `new Counter(40)` becomes `new_Counter(40)` and `counter.Add(2)` keeps the same call shape. [See the Goose output.](samples/objects/expected.goose)

## Run a sample

Use the .NET 10 SDK and the [pinned Goose toolchain](spec/README.md). From the repository root:

```sh
cp lib/dotgoose.goose samples/objects/dotgoose.goose
dotnet run --project compiler -- samples/objects/Program.cs --output samples/objects/actual.goose
goose run samples/objects/actual.goose
```

Run `bash samples/verify.sh` to compare generated source and output for both programs. Set `GOOSE` to the path to your Goose executable if it is outside `PATH`.

## Roadmap

| Release | Status | Feature set | Complexity |
| --- | --- | --- | --- |
| Starter | Implemented | Roslyn parser and binding, single-file CLI, explicit entry point, `int` and `bool`, basic control flow, console output, struct copies, scoped classes, constructors, receiver methods and unchecked addition | Low to medium. Each rule has a small, closed input domain. |
| 1.0 frontend | Planned | SDK-style projects, multiple files, namespaces, source maps, overloads, conversions, operators, arrays, nullable types, tuples, pattern matching, records, properties, initializers, generics, interfaces and delegates | High. Symbol identity, overloads, reachability and evaluation order must survive lowering. |
| 1.0 object and execution semantics | Planned | Escaping references, identity, inheritance, virtual dispatch, closures, boxing, exception handling, disposal, iterators, async/await, cancellation and synchronization | Very high. These require lifetime analysis or an explicit runtime representation. |
| 1.0 BCL | Planned | Text, encoding, numeric and date types, collections, LINQ, spans, streams, files, environment, JSON, HTTP clients and cryptography | High. Match encodings, culture, comparer, errors, ordering and resource behavior. |
| 1.0 NuGet | Planned | Curated Newtonsoft.Json, Serilog and Dapper mappings, plus locked package resolution, licensed C# source acquisition and conversion through the normal compiler | Very high. Package source and platform compatibility vary by version. |
| 1.0 ASP.NET Core | Planned | Full HTTP server sample, minimal APIs, middleware, routing, validation, dependency injection, configuration, JSON, logging, auth, health, TLS and graceful shutdown | Very high. Transport, cancellation, request ownership and observable HTTP behavior must agree. |
| 2.0 Windows | Planned | Windows SDK projection, Win32, P/Invoke, COM, WinRT, Windows services, and staged WinForms, WPF and WinUI support | Very high. ABI, architecture, apartment, UI thread and packaging coverage must be validated on Windows. |

Read the [backend and package spec](spec/backend.md) and the [Windows spec](spec/windows.md) for release acceptance criteria.

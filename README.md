# DotGoose

DotGoose converts C# into readable [Goose](https://github.com/aardappel/goose) source. It starts with runnable pairs of C# and Goose programs. The [spec](spec/README.md) defines the conversion and the [DotGoose library](lib/dotgoose.goose) supplies compatibility operations that need explicit .NET semantics.

The starter translates a single C# file. It supports scalar code, basic control flow, selected console calls, value-type structs and scoped sealed classes. In the [objects sample](samples/objects/Program.cs), `new Counter(40)` becomes `new_Counter(40)` and `counter.Add(2)` keeps the same call shape. [See the Goose output.](samples/objects/expected.goose)

## Explainer video

https://github.com/user-attachments/assets/de94fdad-7123-40a4-9df9-f241230994cb

[Download Part 1 · C# to Goose (MP4)](https://github.com/scriptmaster/dotgoose/raw/refs/heads/main/videos/dotgoose-part-1.mp4) · [English captions](videos/dotgoose-part-1.en.srt)

Eight numbered examples compare C# with the generated Goose and show the matching output. The final section compares the build sizes for the same programs.

### Part 1 binary sizes

| Part 1 example | Goose executable | .NET Native AOT executable | .NET managed DLL |
| --- | ---: | ---: | ---: |
| 1. [A first translation](samples/basics/Program.cs) | 14,552 B | 1,118,704 B | 4,608 B |
| 2. [Console escapes](test/programs/console-escapes.cs) | 14,552 B | 1,118,704 B | 4,608 B |
| 3. [Loops and branches](test/programs/control-flow.cs) | 14,552 B | 1,118,704 B | 4,608 B |
| 4. [Integer overflow](test/programs/overflow.cs) | 14,552 B | 1,118,688 B | 4,608 B |
| 5. [From classes to structs](samples/objects/Program.cs) | 14,552 B | 1,118,688 B | 4,608 B |
| 6. [Defaults and struct copies](test/programs/struct-defaults.cs) | 14,552 B | 1,118,688 B | 4,608 B |
| 7. [Same name, different receiver](test/programs/receiver-dispatch.cs) | 14,552 B | 1,118,688 B | 4,608 B |
| 8. [Evaluation order with side effects](test/programs/receiver-order.cs) | 14,552 B | 1,118,688 B | 4,608 B |

Measured on Ubuntu 22.04 x64 using the pinned Goose toolchain with GCC 11.4 and the .NET SDK 10.0.400. The native columns show stripped executable file sizes. Both executables include the runtime code they need and use the host system libraries. The managed DLL is shown separately and requires an installed .NET runtime. All three builds produced identical stdout for each fixture.

To reproduce, put one C# fixture at `Program.cs` in a clean directory with a copy of [the test project](test/Sample.csproj), the generated `program.goose`, and [the DotGoose library](lib/dotgoose.goose). Then run the following commands.

```sh
goose build program.goose --standalone --cc gcc -o goose-app
dotnet publish Sample.csproj -c Release -r linux-x64 -p:PublishAot=true \
    -p:OptimizationPreference=Size -p:StripSymbols=true -p:InvariantGlobalization=true -o aot
dotnet build Sample.csproj -c Release -o managed
strip --strip-all goose-app aot/Sample
stat -c '%n %s bytes' goose-app aot/Sample managed/Sample.dll
```

## Run a conversion sample

The starter compiler runs with the [pinned Goose toolchain](spec/README.md). Run this from the repository root.

```sh
cp lib/dotgoose.goose samples/objects/dotgoose.goose
goose run compiler/native/dotgoose.goose -- samples/objects/Program.cs --output samples/objects/actual.goose
goose run samples/objects/actual.goose
```

## Tests

Run `bash test/run.sh` with the .NET 10 SDK, Goose, and a C compiler. The suite runs each positive fixture in .NET, builds and runs its generated Goose executable, and reruns the generated program in Goose debug mode. It compares stdout and stderr byte for byte, checks the sample source snapshots, and verifies that rejected programs leave existing output intact. .NET runs the original fixtures as the comparison runtime.

Run `bash test/syntax.sh` for the Goose-only frontend checks. Set `GOOSE` to the path to your Goose executable if it is outside `PATH`. The [Differential tests workflow](.github/workflows/differential.yml) runs on pushes and pull requests.

## Roadmap

| Release | Status | Feature set | Complexity |
| --- | --- | --- | --- |
| Goose-native starter | Implemented | Goose-only lexer, parser, binding and emission for the documented single-file subset, with differential tests against .NET | Medium. Supported declarations, receiver semantics and built-ins are deliberately bounded. |
| 1.0 frontend | Planned | Extend the native compiler with SDK-style project ingestion, multiple files, namespaces, source maps, overloads, conversions, operators, arrays, nullable types, tuples, pattern matching, records, properties, initializers, generics, interfaces and delegates | Very high. Contextual grammar and semantic binding must agree, and project loading needs its own dependency model. |
| 1.0 object and execution semantics | Planned | Escaping references, identity, inheritance, virtual dispatch, closures, boxing, exception handling, disposal, iterators, async/await, cancellation and synchronization | Very high. These require lifetime analysis or an explicit runtime representation. |
| 1.0 BCL | Planned | Text, encoding, numeric and date types, collections, LINQ, spans, streams, files, environment, JSON, HTTP clients and cryptography | High. Match encodings, culture, comparer, errors, ordering and resource behavior. |
| 1.0 NuGet | Planned | Curated Newtonsoft.Json, Serilog and Dapper mappings, plus locked package resolution, licensed C# source acquisition and conversion through the normal compiler | Very high. Package source and platform compatibility vary by version. |
| 1.0 ASP.NET Core | Planned | Full HTTP server sample, minimal APIs, middleware, routing, validation, dependency injection, configuration, JSON, logging, auth, health, TLS and graceful shutdown | Very high. Transport, cancellation, request ownership and observable HTTP behavior must agree. |
| 2.0 Windows | Planned | Windows SDK projection, Win32, P/Invoke, COM, WinRT, Windows services, and staged WinForms, WPF and WinUI support | Very high. ABI, architecture, apartment, UI thread and packaging coverage must be validated on Windows. |

Read the [backend and package spec](spec/backend.md) and the [Windows spec](spec/windows.md) for release acceptance criteria.

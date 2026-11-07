# DotGoose

DotGoose converts C# into readable [Goose](https://github.com/aardappel/goose) source. It starts with runnable pairs of C# and Goose programs. The [spec](spec/README.md) defines the conversion and the [DotGoose library](lib/dotgoose.goose) supplies compatibility operations that need explicit .NET semantics.

The starter translates a single C# file. It supports scalar code, basic control flow, selected console calls, value-type structs and scoped sealed classes. In the [objects sample](samples/objects/Program.cs), `new Counter(40)` becomes `new_Counter(40)` and `counter.Add(2)` keeps the same call shape. [See the Goose output.](samples/objects/expected.goose)

For C# `int` addition, the compiler emits `x.add(y)` with `import .dotgoose;`. The library provides the `i32` overload and the qualified form `dotgoose::add(x, y)`. Both preserve unchecked 32-bit wrapping.

The [strings sample](samples/strings/Program.cs) shows raw JSON literals and interpolation, with [generated Goose](samples/strings/expected.goose) and output checked against .NET. Both C# and Goose accept `"""{"status":"ok"}"""` directly. C# `$"Item {id}"` becomes Goose `str("Item ", id, "")`. The Boolean helper preserves C# `True` and `False` text, and the compiler preserves expression evaluation order.

## Explainer video

https://github.com/user-attachments/assets/ba69e609-fb06-4d32-864e-c17db9d70af0

[Download Part 1 · C# to Goose (MP4)](https://github.com/scriptmaster/dotgoose/raw/refs/heads/main/videos/dotgoose-part-1.mp4) · [English captions](videos/dotgoose-part-1.en.srt)

Nine numbered examples compare C# with the generated Goose and show matching output, including raw strings and interpolation. The final sections compare executable sizes and explain what each build needs to run in a container.

### Part 1 binary sizes

| Part 1 example | Goose with system libc | Goose fully static | .NET Native AOT | .NET self-contained single-file | .NET managed DLL |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1. [A first translation](samples/basics/Program.cs) | 14.6 KB | 954.8 KB | 1.1 MB | 39.2 MB | 4.6 KB |
| 2. [Console escapes](test/programs/console-escapes.cs) | 14.6 KB | 954.8 KB | 1.1 MB | 39.2 MB | 4.6 KB |
| 3. [Loops and branches](test/programs/control-flow.cs) | 14.6 KB | 954.8 KB | 1.1 MB | 39.2 MB | 4.6 KB |
| 4. [Integer overflow](test/programs/overflow.cs) | 14.6 KB | 954.8 KB | 1.1 MB | 39.2 MB | 4.6 KB |
| 5. [From classes to structs](samples/objects/Program.cs) | 14.6 KB | 954.8 KB | 1.1 MB | 39.2 MB | 4.6 KB |
| 6. [Defaults and struct copies](test/programs/struct-defaults.cs) | 14.6 KB | 954.8 KB | 1.1 MB | 39.2 MB | 4.6 KB |
| 7. [Same name, different receiver](test/programs/receiver-dispatch.cs) | 14.6 KB | 954.8 KB | 1.1 MB | 39.2 MB | 4.6 KB |
| 8. [Evaluation order with side effects](test/programs/receiver-order.cs) | 14.6 KB | 954.8 KB | 1.1 MB | 39.2 MB | 4.6 KB |
| 9. [Raw strings and interpolation](samples/strings/Program.cs) | 18.6 KB | 954.8 KB | 1.1 MB | 39.2 MB | 5.6 KB |

Measured on Ubuntu 22.04 x64 with the pinned Goose toolchain, GCC 11.4, and .NET SDK 10.0.400. Sizes are decimal KB and MB, rounded to one decimal place. All five builds produced the same stdout for each example.

- **Goose with system libc** bundles the Goose runtime and dynamically links to glibc. It needs `libc.so.6` and the system loader at `/lib64/ld-linux-x86-64.so.2`.
- **Goose fully static** links the Goose runtime and glibc into the executable. `readelf` found no ELF interpreter or shared-library dependencies. All nine ran in a Linux chroot containing only the executable. These console programs can use a Docker `FROM scratch` image on compatible Linux x64 Kubernetes nodes. Backend programs can still need files such as TLS certificates. [Docker scratch images](https://docs.docker.com/build/building/base-images/#create-a-minimal-base-image-using-scratch)
- **.NET Native AOT** includes the .NET runtime code the app needs and uses system libraries. **.NET self-contained single-file** bundles the .NET runtime into one compressed executable, extracts native runtime libraries at startup, and runs the managed code with the JIT. Both run without a separately installed .NET runtime. The managed DLL requires one. [Native AOT](https://learn.microsoft.com/dotnet/core/deploying/native-aot/) · [Single-file deployment](https://learn.microsoft.com/dotnet/core/deploying/single-file/)

To reproduce, put one C# fixture at `Program.cs` in a clean directory with a copy of [the test project](test/Sample.csproj), the generated `program.goose`, and [the DotGoose library](lib/dotgoose.goose). Then run these commands.

```sh
goose build program.goose --standalone --cc gcc -o goose-app
goose --standalone -o standalone.c program.goose
gcc -O2 -static -s standalone.c -o goose-static -lm -pthread

dotnet publish Sample.csproj -c Release -r linux-x64 -p:PublishAot=true \
    -p:OptimizationPreference=Size -p:StripSymbols=true -p:InvariantGlobalization=true -o aot
dotnet publish Sample.csproj -c Release -r linux-x64 --self-contained true \
    -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true \
    -p:EnableCompressionInSingleFile=true -p:InvariantGlobalization=true -p:DebugType=None -o single
dotnet build Sample.csproj -c Release -o managed

strip --strip-all goose-app aot/Sample
stat -c '%n %s bytes' goose-app goose-static aot/Sample single/Sample managed/Sample.dll
```

## Part 2 web examples

https://github.com/user-attachments/assets/9fba8434-4eec-4a36-b1de-65843cc6471c

[Download Part 2 (MP4)](https://github.com/scriptmaster/dotgoose/raw/refs/heads/main/videos/dotgoose-part-2.mp4) · [English captions](videos/dotgoose-part-2.en.srt)

Six paired ASP.NET Core and Goose programs cover health checks, route and query binding, middleware, JSON validation, request scope, and an MVC controller with a Razor view. The Goose examples are hand-ported and share a small Linux HTTP transport.

The [web comparison](samples/web/README.md#part-2-measurements) reports application lines, executable sizes, CPU time, and peak RAM. Every build was checked against the same HTTP response contract. The recorded measurements use 2,000 sequential loopback requests per run.

Each [web example](samples/web/README.md#application-startup) uses the DotGoose builder API with `WebApplication.CreateSlimBuilder(args)`, `builder.Logging.ClearProviders()`, `builder.Build()`, route registration, and `app.Run()`. The application statements live in `program_main(args)`, called once from `main()`. The MVC example uses `CreateBuilder`, controller registration, and the same Razor template compiled into a reusable Goose function. The line-count table includes complete source totals and identifies the four Goose entry-point lines separately.

## Run a conversion sample

The starter compiler runs with the [pinned Goose toolchain](spec/README.md). Run this from the repository root.

```sh
cp lib/dotgoose.goose samples/objects/dotgoose.goose
goose run compiler/native/dotgoose.goose -- samples/objects/Program.cs --output samples/objects/actual.goose
goose run samples/objects/actual.goose
```

## Tests

Run `bash test/run.sh` with the .NET 10 SDK, Goose, and a C compiler. The suite runs each positive fixture in .NET, builds and runs its generated Goose executable, and reruns the generated program in Goose debug mode. It compares stdout and stderr byte for byte, checks the sample source snapshots, and verifies that rejected programs leave existing output intact. .NET runs the original fixtures as the comparison runtime.

Run `bash test/syntax.sh` for the Goose-only frontend checks and `python3 test/web.py` for HTTP parity. Set `GOOSE` to the path to your Goose executable if it is outside `PATH`. The [Differential tests workflow](.github/workflows/differential.yml) runs on pushes and pull requests.

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

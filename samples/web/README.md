# Part 2 web examples

These six pairs compare ASP.NET Core with hand-ported Goose applications on Linux x64. Each pair lives in one directory, with `Program.cs` and `main.goose`. The [native C# converter](../../spec/language.md) handles the starter language profile. The web examples use the shared [DotGoose web library](../../lib/web/web.goose) and the Goose hosting compiler pass.

## Application startup

The Goose health program keeps all five ASP.NET Core startup statements inside `program_main(args)`. `main()` calls it once.

```goose
import web from "../../../lib/web";

fn program_main(args: u8[:][:]) {
    var builder = WebApplication.CreateSlimBuilder(args);
    builder.Logging.ClearProviders();

    var app = builder.Build();
    app.MapGet("/healthz") { req => req.Send(Results.Text("""{"status":"ok"}""", "application/json")); };
    app.Run();
}

fn main() { program_main(args()); }
```

`GET /healthz` returns HTTP 200, `Content-Type: application/json`, and the exact body `{"status":"ok"}`. `POST /healthz` returns HTTP 405 with `Allow: GET`. `Results.Text` sends the text directly. The triple quotes are Goose raw-string syntax, so JSON quotation marks stay readable.

Inside a handler, Goose `str(...)` combines literal text with runtime values. `Results.Text("pong")` defaults to `text/plain; charset=utf-8`. The host tests also send dynamically formatted JSON through `Results.Text`.

```goose
let body = str("""{"id":""", req.id, "}");
req.Send(Results.Text(body, "application/json"));
```

`CreateSlimBuilder` and `CreateBuilder` supply `Logging` and `Services`. `ClearProviders()` disables console startup logging. `Build()` snapshots configuration. `MapGet`, `MapPost`, and `Use` register handlers once, and `app.Run()` starts the listener. Middleware runs in registration order and can respond early. A scoped service is initialized for each request and shared by that request's middleware and endpoint. The MVC example registers explicit controller routes and compiles the original Razor view.

Goose function arguments are compile-time values. The `dotgoose web` pass extracts the callback bodies into functions and builds a dispatcher. Route registration stores handler IDs and owned copies of route strings. Application startup executes once, while the dispatcher invokes compiled handlers for matching requests. The first implementation supports one application, one value-type scoped service, 64 registrations, and routes up to 256 bytes. Handlers use their request parameter, their own locals, and module declarations. See the [builder specification](../../spec/backend.md#web-application-builder).

## HTTP contracts

| Example | HTTP behavior |
| --- | --- |
| [1. Health](01-health) | `GET /healthz` returns HTTP 200 with `{"status":"ok"}`. `GET /missing` returns HTTP 404. |
| [2. Routing and query](02-routing) | `GET /api/items/42?includeDetails=true` returns item 42 with details. `GET /api/items/7?includeDetails=false` returns item 7. `GET /api/items/42?includeDetails=maybe` returns HTTP 400. `GET /api/items/abc` returns HTTP 404. |
| [3. Middleware](03-middleware) | `GET /api/ping` with a valid `X-Request-Id` returns `pong`, echoes the ID, and reports `X-Stages: id,endpoint`. A missing or invalid ID returns HTTP 400 with `X-Stages: id`. |
| [4. JSON validation](04-json) | `POST /api/items` with `{"name":"Gear","quantity":2}` and JSON content type returns HTTP 201 and `Location: /api/items/42`. Malformed or invalid input returns HTTP 400. |
| [5. Request scope](05-scope) | `GET /api/visit` returns `{"step":2}` on every request. Its middleware and endpoint share one `Visit` instance, which starts over on the next request. |
| [6. MVC and views](06-mvc) | `GET /catalog/42` renders the same HTML from `Show.cshtml`. `GET /catalog/999` returns HTTP 404. `POST /catalog/42` returns HTTP 405 with `Allow: GET`. |

The loopback transport is a sequential HTTP/1.1 demonstration with one request per connection, an 8 KiB header cap, and a 4 KiB body cap. ASP.NET Core uses Kestrel. The contract checks status, selected headers, content type, and response bytes.

## Build and reuse compiled handlers and views

Use the pinned Goose compiler, .NET 10 SDK, GCC, Python 3.10 or newer, and GNU time on Linux x64. From the repository root, compile the health application with these commands.

```sh
goose run compiler/native/dotgoose.goose -- web \
    samples/web/01-health/main.goose --output samples/web/01-health/compiled.goose
goose build samples/web/01-health/compiled.goose --cc gcc -o /tmp/dotgoose-health
/tmp/dotgoose-health 5512
```

For MVC, first compile the Razor file, then compile the host. The resulting executable reuses `render_Show` on each request.

```sh
goose run compiler/native/dotgoose.goose -- razor \
    samples/web/06-mvc/Views/Catalog/Show.cshtml render_Show \
    --output samples/web/06-mvc/view.goose
goose run compiler/native/dotgoose.goose -- web \
    samples/web/06-mvc/main.goose --output samples/web/06-mvc/compiled.goose
goose build samples/web/06-mvc/compiled.goose --cc gcc -o /tmp/dotgoose-mvc
/tmp/dotgoose-mvc 5512
```

The view subset supports `@model Type`, HTML-escaped `@Model.Property`, and `@@` for a literal at sign. See the [view compilation specification](../../spec/backend.md#razor-view-compilation).

## Verify and measure

```sh
python3 test/web.py
python3 test/web.py --benchmark /tmp/dotgoose-web.json
```

Tests cover all 26 HTTP cases on both implementations, repeated renders, Razor escaping and diagnostics, startup occurring once, logging configuration snapshots, copied route paths, and registration order. The measurement run also verifies every release variant, then cycles through the cases for 2,000 requests per trial with a new loopback connection for each request. Values are medians across three trials. GNU time records server user plus system CPU time from startup through shutdown and peak resident memory. The client runs outside the server process. Results depend on this workload and host.

## Application source lines

Counts exclude blank lines and comments and include the same Razor template for MVC. The complete Goose source column includes the web import, the two `program_main` boundary lines, and the `main` forwarder. These four entry-point lines appear separately so the application statements can also be compared with the C# source. Generated dispatcher and view code and shared framework code are excluded from both application counts.

| Example | Goose application lines | Goose entry-point lines | Complete Goose source | ASP.NET Core source |
| --- | ---: | ---: | ---: | ---: |
| [Health](01-health) | 5 | 4 | 9 | 5 |
| [Routing and query](02-routing) | 13 | 4 | 17 | 14 |
| [Middleware](03-middleware) | 14 | 4 | 18 | 26 |
| [JSON validation](04-json) | 18 | 4 | 22 | 29 |
| [Request scope](05-scope) | 11 | 4 | 15 | 17 |
| [MVC and views](06-mvc) | 25 | 4 | 29 | 26 |

The reusable Goose web package and C transport total 413 code lines.

## Executable size and server cost

Measured on Ubuntu 22.04 x64 with two logical CPUs on an AMD EPYC 9354P, GCC 11.4, .NET SDK 10.0.400, and the pinned Goose toolchain. Executable sizes use decimal KB and MB with one decimal place. Peak RAM uses MiB. [Raw sizes and trials](results.json)

The Goose dynamic build bundles the Goose runtime and uses system libc. The fully static build includes libc. The compressed self-contained .NET single-file build bundles the .NET runtime and uses JIT compilation. MVC uses single-file because ASP.NET Core MVC is outside the supported Native AOT feature set. [ASP.NET Core Native AOT compatibility](https://learn.microsoft.com/aspnet/core/fundamentals/native-aot?view=aspnetcore-10.0)

| Example | Build | Executable size | CPU time | Peak RAM |
| --- | --- | ---: | ---: | ---: |
| Health | Goose with system libc | 30.9 KB | 100 ms | 1.9 MiB |
| Health | Goose fully static | 967.2 KB | 110 ms | 1.7 MiB |
| Health | .NET Native AOT | 9.2 MB | 700 ms | 18.3 MiB |
| Health | .NET single-file | 51.6 MB | 1440 ms | 103.3 MiB |
| Routing and query | Goose with system libc | 30.9 KB | 90 ms | 1.8 MiB |
| Routing and query | Goose fully static | 967.2 KB | 90 ms | 1.8 MiB |
| Routing and query | .NET Native AOT | 9.1 MB | 750 ms | 18.2 MiB |
| Routing and query | .NET single-file | 51.6 MB | 1460 ms | 104.5 MiB |
| Middleware | Goose with system libc | 30.9 KB | 100 ms | 1.9 MiB |
| Middleware | Goose fully static | 967.2 KB | 100 ms | 1.8 MiB |
| Middleware | .NET Native AOT | 9.2 MB | 720 ms | 18.2 MiB |
| Middleware | .NET single-file | 51.6 MB | 1540 ms | 103.4 MiB |
| JSON validation | Goose with system libc | 59.6 KB | 240 ms | 2.1 MiB |
| JSON validation | Goose fully static | 999.9 KB | 320 ms | 1.8 MiB |
| JSON validation | .NET Native AOT | 9.4 MB | 900 ms | 18.9 MiB |
| JSON validation | .NET single-file | 51.6 MB | 1710 ms | 104.4 MiB |
| Request scope | Goose with system libc | 30.9 KB | 100 ms | 1.8 MiB |
| Request scope | Goose fully static | 967.2 KB | 100 ms | 1.7 MiB |
| Request scope | .NET Native AOT | 9.5 MB | 760 ms | 18.6 MiB |
| Request scope | .NET single-file | 51.6 MB | 1500 ms | 104.6 MiB |
| MVC and views | Goose with system libc | 30.9 KB | 110 ms | 1.9 MiB |
| MVC and views | Goose fully static | 967.2 KB | 100 ms | 1.8 MiB |
| MVC and views | .NET single-file | 51.6 MB | 1820 ms | 148.2 MiB |

# Part 2 web examples

Six pairs compare ASP.NET Core with hand-ported Goose handlers on Linux x64. The current DotGoose converter translates its [starter C# subset](../../spec/language.md). The Goose examples use a shared POSIX transport and keep routing, validation, and response generation in Goose.

| Example | HTTP behavior |
| --- | --- |
| [1. Health](01-health) | `GET /healthz` returns HTTP 200 with `{"status":"ok"}`. `GET /missing` returns HTTP 404. |
| [2. Routing and query](02-routing) | `GET /api/items/42?includeDetails=true` returns item 42 with details. `GET /api/items/7?includeDetails=false` returns just item 7. `GET /api/items/42?includeDetails=maybe` returns HTTP 400. `GET /api/items/abc` returns HTTP 404. |
| [3. Middleware](03-middleware) | `GET /api/ping` with a valid `X-Request-Id` returns `pong`, echoes the ID, and reports `X-Stages: id,endpoint`. A missing or invalid ID returns HTTP 400 with `X-Stages: id`. |
| [4. JSON validation](04-json) | `POST /api/items` with JSON `{"name":"Gear","quantity":2}` returns HTTP 201, echoes the accepted item, and sets `Location: /api/items/42`. Malformed or invalid input returns HTTP 400. |
| [5. Request scope](05-scope) | `GET /api/visit` returns `{"step":2}` on every request. The middleware and endpoint share one counter, which starts over on the next request. |
| [6. MVC and views](06-mvc) | `GET /catalog/42` renders an HTML view for item 42. `GET /catalog/999` returns HTTP 404. The ASP.NET Core app uses an MVC controller and a Razor view. The Goose app maps the path to a model and an explicit view function. |

The test contract covers canonical paths, selected headers, status codes, media types, and response bytes. The Goose transport binds to loopback, serves one request per connection, and caps request headers at 8 KiB and bodies at 4 KiB. It accepts length-delimited HTTP/1.1 requests. It is a sequential demonstration transport. ASP.NET Core uses Kestrel and its standard HTTP stack.

## Enhanced ports

The [enhanced examples](enhanced) use the reusable [DotGoose web package](../../lib/web/web.goose) with the same ASP.NET Core programs and HTTP contract. The package handles the server loop, exact and integer-parameter routes, middleware ordering, 404 and 405 responses, request headers, JSON parsing and serialization, and HTML responses.

```goose
import web from "../../../../lib/web";

fn routes(app: web::App<i32>&) {
    app.MapGet("/healthz") { req => req.Json("status", "ok"); };
}
fn main() { web::Run(routes); }
```

`GET /healthz` returns HTTP 200 with `{"status":"ok"}`. `POST /healthz` returns HTTP 405 with `Allow: GET`.

`Run(routes)` invokes the route block for each request. Goose resolves the handler calls at compile time. Declare `app.Use()` middleware before the routes it applies to. Middleware can respond early, which skips subsequent hooks and handlers. `RunWith(initialState, routes)` gives each request its own state. Route templates support a final `{id:int}` or `{id:int:min(1)}` segment, with the bound value in `req.id`.

| Example | Goose code lines | ASP.NET Core code lines | Physical lines, Goose / ASP.NET Core |
| --- | ---: | ---: | ---: |
| [Health](enhanced/01-health) | 5 | 5 | 6 / 6 |
| [Routing and query](enhanced/02-routing) | 13 | 14 | 15 / 15 |
| [Middleware](enhanced/03-middleware) | 14 | 26 | 18 / 30 |
| [JSON validation](enhanced/04-json) | 18 | 29 | 20 / 36 |
| [Request scope](enhanced/05-scope) | 9 | 17 | 11 / 21 |
| [MVC and views](enhanced/06-mvc) | 23 | 26 | 26 / 31 |

The MVC counts include the same seven-line Razor template on both sides. Generated view code and shared framework code are outside the application counts. The reusable Goose web package and its C transport total 339 code lines.

### Compile and reuse a Razor view

The MVC app uses the original [Show.cshtml](06-mvc/Views/Catalog/Show.cshtml). The `razor` subcommand emits `render_Show` as ordinary Goose code. Build the app once, then the handler calls that compiled function for every matching request.

```sh
goose run compiler/native/dotgoose.goose -- razor \
    samples/web/06-mvc/Views/Catalog/Show.cshtml render_Show \
    --output samples/web/enhanced/06-mvc/view.goose
goose build samples/web/enhanced/06-mvc/main.goose --cc gcc -o /tmp/dotgoose-mvc
/tmp/dotgoose-mvc 5512
```

`GET /catalog/42` renders the HTML for item 42. `GET /catalog/999` returns HTTP 404. The template subset supports `@model Type`, HTML-escaped `@Model.Property`, and `@@` for a literal at sign. See the [view compilation spec](../../spec/backend.md#razor-view-compilation) for the grammar.

## Verify and measure

Use the pinned Goose compiler, .NET 10 SDK, GCC, Python 3.10 or newer, and GNU time on Linux x64.

```sh
python3 test/web.py
python3 test/web.py --enhanced
python3 test/web.py --benchmark /tmp/dotgoose-web.json
```

The verification run checks every HTTP case in both implementations. The measurement run builds release executables, runs the same contract against every executable, then cycles through the cases for 2,000 requests per trial, with a new loopback connection for each request. It reports medians across three trials. GNU time measures server user plus system CPU time from startup through shutdown and peak resident memory (RSS). The client runs outside the server process. The self-contained .NET app is warmed once so its native library extraction directory exists before measurements. Results are specific to this workload and host.

Application line counts exclude blank lines and comments, include Razor for MVC, and exclude the shared Goose HTTP implementation. Shared support is reported separately. The Goose dynamic binary bundles the Goose runtime and uses system libc. The fully static build includes libc. The self-contained .NET single-file build includes the compressed .NET runtime and uses JIT compilation. MVC is measured with the single-file build because ASP.NET Core MVC is outside the supported Native AOT feature set. [ASP.NET Core Native AOT compatibility](https://learn.microsoft.com/aspnet/core/fundamentals/native-aot?view=aspnetcore-10.0)

## Part 2 measurements

Measured on Ubuntu 22.04 x64 with two logical CPUs on an AMD EPYC 9354P, GCC 11.4, .NET SDK 10.0.400, and the pinned Goose toolchain. Executable sizes use decimal KB and MB. Peak RSS uses MiB. [Raw sizes and trials](results.json)

### Application source lines

| Example | Goose app lines | ASP.NET Core app lines |
| --- | ---: | ---: |
| [Health](01-health) | 11 | 5 |
| [Routing and query](02-routing) | 18 | 14 |
| [Middleware](03-middleware) | 24 | 26 |
| [JSON validation](04-json) | 27 | 29 |
| [Request scope](05-scope) | 24 | 17 |
| [MVC and views](06-mvc) | 20 | 26 |

The original measured snapshot shares 188 additional source lines across the Goose HTTP module and C transport. Its request-scope example also imports the 7-line addition library. The ASP.NET Core counts cover application source and leave framework internals outside the line counts.

### Executable size and server cost

| Example | Build | Executable size | CPU time | Peak RSS |
| --- | --- | ---: | ---: | ---: |
| Health | Goose with system libc | 22.7 KB | 90 ms | 1.8 MiB |
| Health | Goose fully static | 963.1 KB | 80 ms | 1.8 MiB |
| Health | .NET Native AOT | 9.2 MB | 700 ms | 18.0 MiB |
| Health | .NET single-file | 51.6 MB | 1370 ms | 102.9 MiB |
| Routing and query | Goose with system libc | 26.8 KB | 110 ms | 1.8 MiB |
| Routing and query | Goose fully static | 967.2 KB | 100 ms | 1.8 MiB |
| Routing and query | .NET Native AOT | 9.1 MB | 730 ms | 18.1 MiB |
| Routing and query | .NET single-file | 51.6 MB | 1430 ms | 104.1 MiB |
| Middleware | Goose with system libc | 22.7 KB | 100 ms | 1.8 MiB |
| Middleware | Goose fully static | 963.1 KB | 90 ms | 1.8 MiB |
| Middleware | .NET Native AOT | 9.2 MB | 750 ms | 18.3 MiB |
| Middleware | .NET single-file | 51.6 MB | 1470 ms | 103.4 MiB |
| JSON validation | Goose with system libc | 55.5 KB | 100 ms | 2.2 MiB |
| JSON validation | Goose fully static | 995.8 KB | 100 ms | 1.8 MiB |
| JSON validation | .NET Native AOT | 9.4 MB | 790 ms | 18.8 MiB |
| JSON validation | .NET single-file | 51.6 MB | 1650 ms | 105.0 MiB |
| Request scope | Goose with system libc | 22.7 KB | 90 ms | 1.7 MiB |
| Request scope | Goose fully static | 963.1 KB | 90 ms | 1.8 MiB |
| Request scope | .NET Native AOT | 9.5 MB | 890 ms | 18.6 MiB |
| Request scope | .NET single-file | 51.6 MB | 1680 ms | 105.0 MiB |
| MVC and views | Goose with system libc | 22.7 KB | 80 ms | 1.8 MiB |
| MVC and views | Goose fully static | 963.1 KB | 90 ms | 1.8 MiB |
| MVC and views | .NET single-file | 51.6 MB | 1770 ms | 148.2 MiB |

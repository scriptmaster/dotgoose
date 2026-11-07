namespace web;

struct WebApplicationFactory { version: u8 = 1 }
struct ResultFactory { version: u8 = 1 }
struct LoggingBuilder { console: bool = true }
struct ServiceCollection { scoped: bool = false, controllers: bool = false }

struct WebApplicationBuilder {
    Logging: LoggingBuilder,
    Services: ServiceCollection,
    port: i32,
    slim: bool,
}

enum RegistrationKind { Get, Post, Middleware }

struct Registration {
    kind: RegistrationKind,
    path: u8[..256] = [],
    handler: i32,
}

struct Application {
    Logging: LoggingBuilder,
    Services: ServiceCollection,
    port: i32,
    registrations: Registration[..64] = [],
    started: bool = false,
}

struct Result {
    status: i32,
    mime: const u8[:],
    body: const u8[:],
}

fn CreateSlimBuilder(factory: WebApplicationFactory, argv: u8[:][:]) -> WebApplicationBuilder {
    guard argv.len == 2 else { abort("usage: server PORT"); }
    let port, valid = parse_int(argv[1]);
    guard valid && port > 0 && port <= 65535 else { abort("invalid port"); }
    return WebApplicationBuilder { Logging: LoggingBuilder {}, Services: ServiceCollection {},
                                   port: port as i32, slim: true };
}

fn CreateBuilder(factory: WebApplicationFactory, argv: u8[:][:]) -> WebApplicationBuilder {
    var builder = factory.CreateSlimBuilder(argv);
    builder.slim = false;
    return builder;
}

fn ClearProviders(logging: LoggingBuilder&) { logging.console = false; }

fn AddScoped<T>(services: ServiceCollection&) {
    guard !services.scoped else { abort("one scoped service is supported"); }
    services.scoped = true;
}

fn AddControllersWithViews(services: ServiceCollection&) { services.controllers = true; }

fn Build(builder: WebApplicationBuilder&) -> Application {
    guard !builder.slim || !builder.Services.controllers else {
        abort("controllers require WebApplication.CreateBuilder");
    }
    return Application { Logging: builder.Logging, Services: builder.Services, port: builder.port };
}

fn RequireControllers(app: Application&) {
    guard app.Services.controllers else { abort("call Services.AddControllersWithViews before Build"); }
}

fn register(app: Application&, kind: RegistrationKind, path: const u8[:], handler: i32) {
    guard !app.started else { abort("cannot register handlers after Run"); }
    guard app.registrations.len < 64 else { abort("at most 64 handlers are supported"); }
    guard path.len <= 256 else { abort("route exceeds 256 bytes"); }
    app.registrations.push(Registration { kind: kind, path: path, handler: handler });
}

fn RegisterGet(app: Application&, path: const u8[:], handler: i32) {
    register(app, RegistrationKind.Get, path, handler);
}

fn RegisterPost(app: Application&, path: const u8[:], handler: i32) {
    register(app, RegistrationKind.Post, path, handler);
}

fn RegisterMiddleware(app: Application&, handler: i32) {
    register(app, RegistrationKind.Middleware, "", handler);
}

fn Run<Dispatch>(app: Application&) {
    guard !app.Services.scoped else { abort("scoped hosting requires the DotGoose web compiler"); }
    run_application(app, 0 as i32, Dispatch);
}

fn RunScoped<T, Dispatch>(app: Application&, initial_state: T) {
    guard app.Services.scoped else { abort("call Services.AddScoped before Build"); }
    run_application(app, initial_state, Dispatch);
}

fn run_application<T, Dispatch>(app: Application&, initial_state: T) {
    guard !app.started else { abort("application has already started"); }
    app.started = true;
    if app.Logging.console { write_stderr(str("Listening on http://127.0.0.1:", app.port, "\n")); }
    serve_port(app.port) { client, method, target, body =>
        var request = App<T> { client: client, method: method, path: path_of(target),
                               query: query_of(target), body: body, state: initial_state };
        for registration in app.registrations {
            if request.handled { break; }
            if registration.kind == RegistrationKind.Middleware {
                Dispatch(request, registration.handler);
            } else if match_path(request, registration.path) {
                let get = registration.kind == RegistrationKind.Get;
                let method = if get { "GET" } else { "POST" };
                if request.method == method {
                    Dispatch(request, registration.handler);
                    if !request.handled { request.NotFound(); }
                } else if get { request.allow_get = true; }
                else { request.allow_post = true; }
            }
        }
        if !request.handled {
            if request.allow_get || request.allow_post {
                dg_method_not_allowed(client, if request.allow_get && request.allow_post { "GET, POST" }
                    else if request.allow_get { "GET" } else { "POST" });
            } else { request.NotFound(); }
        }
    };
}

fn GetRequiredService<T>(request: App<T>&) -> T& { return request.state; }

fn Text(factory: ResultFactory, text: const u8[:], mime: const u8[:] = "text/plain; charset=utf-8") -> Result {
    return Result { status: 200, mime: mime, body: text };
}

fn Send(request, result: Result) { request.Reply(result.status, result.mime, result.body); }

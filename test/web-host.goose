import web from "../lib/web";

var startup_count: i32 = 0;

fn program_main(args: u8[:][:]) {
    startup_count++;
    var builder = WebApplication.CreateSlimBuilder(args);
    assert(builder.Logging.console);
    builder.Logging.ClearProviders();

    let plain = Results.Text("pong");
    assert(plain.status == 200 && plain.body == "pong" && plain.mime == "text/plain; charset=utf-8");

    var app = builder.Build();
    builder.Logging.console = true;
    assert(!app.Logging.console);

    var path: u8[..256] = "/healthz";
    app.Use() { req => req.state++; };
    app.MapGet(path) { req =>
        assert(startup_count == 1 && req.state == 1);
        req.Send(Results.Text("""{"status":"ok"}""", "application/json"));
    };
    path = "/mutated";
    app.MapGet("/healthz") { req => req.Text("wrong-order"); };
    app.MapGet("/value") { req =>
        req.Send(Results.Text(str("""{"step":""", req.state, "}"), "application/json"));
    };

    write_stderr("startup-once\n");
    app.Run();
}

fn main() { program_main(args()); }

import web from "../../../lib/web";

fn program_main(args: u8[:][:]) {
    var builder = WebApplication.CreateSlimBuilder(args);
    builder.Logging.ClearProviders();

    var app = builder.Build();
    app.Use() { req =>
        if req.method == "GET" && req.path == "/api/ping" {
            req.Stages("id");
            req.RequireRequestId();
        }
    };

    app.Use() { req =>
        if req.request_id.len > 0 { req.Stages("id,endpoint"); }
    };

    app.MapGet("/api/ping") { req => req.Text("pong"); };
    app.Run();
}

fn main() { program_main(args()); }

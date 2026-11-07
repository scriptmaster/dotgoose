import web from "../../../lib/web";

struct Visit { step: i32 = 0 }

fn Advance(visit: Visit&) -> i32 { visit.step++; return visit.step; }

fn program_main(args: u8[:][:]) {
    var builder = WebApplication.CreateSlimBuilder(args);
    builder.Logging.ClearProviders();
    builder.Services.AddScoped<Visit>();

    var app = builder.Build();
    app.Use() { req => req.GetRequiredService<Visit>().Advance(); };
    app.MapGet("/api/visit") { req =>
        req.Json("step", req.GetRequiredService<Visit>().Advance());
    };
    app.Run();
}

fn main() { program_main(args()); }

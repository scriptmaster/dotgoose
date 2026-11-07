import web from "../../../lib/web";

fn program_main(args: u8[:][:]) {
    var builder = WebApplication.CreateSlimBuilder(args);
    builder.Logging.ClearProviders();

    var app = builder.Build();
    app.MapGet("/healthz") { req => req.Send(Results.Text("""{"status":"ok"}""", "application/json")); };
    app.Run();
}

fn main() { program_main(args()); }

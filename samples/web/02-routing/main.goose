import web from "../../../lib/web";

fn program_main(args: u8[:][:]) {
    var builder = WebApplication.CreateSlimBuilder(args);
    builder.Logging.ClearProviders();

    var app = builder.Build();
    app.MapGet("/api/items/{id:int:min(1)}") { req =>
        if req.query == "includeDetails=true" {
            req.Json("id", req.id, "details", "starter");
        } else if req.query.len == 0 || req.query == "includeDetails=false" {
            req.Json("id", req.id);
        } else {
            req.BadRequest();
        }
    };
    app.Run();
}

fn main() { program_main(args()); }

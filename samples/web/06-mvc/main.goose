import web from "../../../lib/web";
import .view;

struct CatalogItem { Id: i32, Name: const u8[:] }

fn MapControllers(app: web::Application&) {
    app.RequireControllers();
    app.MapGet("/catalog/{id:int}") { req =>
        if req.id == 42 {
            req.Html(render_Show(CatalogItem { Id: req.id, Name: "Goose" }));
        } else {
            req.NotFound();
        }
    };
}

fn program_main(args: u8[:][:]) {
    var builder = WebApplication.CreateBuilder(args);
    builder.Logging.ClearProviders();
    builder.Services.AddControllersWithViews();

    var app = builder.Build();
    app.MapControllers();
    app.Run();
}

fn main() { program_main(args()); }

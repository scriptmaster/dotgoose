import web from "../../../../lib/web";
import .view;

struct CatalogItem {
    Id: i32,
    Name: const u8[:],
}

fn routes(app: web::App<i32>&) {
    app.MapGet("/catalog/{id:int}") { req =>
        if req.id == 42 {
            req.Html(render_Show(CatalogItem { Id: req.id, Name: "Goose" }));
        } else {
            req.NotFound();
        }
    };
}

fn main() { web::Run(routes); }

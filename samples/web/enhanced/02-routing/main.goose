import web from "../../../../lib/web";

fn routes(app: web::App<i32>&) {
    app.MapGet("/api/items/{id:int:min(1)}") { req =>
        if req.query == "includeDetails=true" {
            req.Json("id", req.id, "details", "starter");
        } else if req.query.len == 0 || req.query == "includeDetails=false" {
            req.Json("id", req.id);
        } else {
            req.BadRequest();
        }
    };
}

fn main() { web::Run(routes); }

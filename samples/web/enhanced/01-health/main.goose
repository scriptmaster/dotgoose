import web from "../../../../lib/web";

fn routes(app: web::App<i32>&) {
    app.MapGet("/healthz") { req => req.Json("status", "ok"); };
}
fn main() { web::Run(routes); }

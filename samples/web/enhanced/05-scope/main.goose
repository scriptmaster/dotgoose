import web from "../../../../lib/web";

fn routes(app: web::App<i32>&) {
    app.Use() { req => req.state++; };
    app.MapGet("/api/visit") { req =>
        req.state++;
        req.Json("step", req.state);
    };
}

fn main() { web::RunWith(0 as i32, routes); }

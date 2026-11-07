import web from "../../../../lib/web";

fn routes(app: web::App<i32>&) {
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
}

fn main() { web::Run(routes); }

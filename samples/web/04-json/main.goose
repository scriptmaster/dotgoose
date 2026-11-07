import web from "../../../lib/web";
import json;

fn program_main(args: u8[:][:]) {
    var builder = WebApplication.CreateSlimBuilder(args);
    builder.Logging.ClearProviders();

    var app = builder.Build();
    app.MapPost("/api/items") { req =>
        req.ReadJson() { item =>
            let name, has_name = json::as_string(json::member(item, "name"));
            let quantity, has_quantity = json::as_i64(json::member(item, "quantity"));
            let valid_name = name.len >= 1 && name.len <= 32 &&
                all(name) { ascii::is_alpha(it) || ascii::is_digit(it) };
            if has_name && has_quantity && valid_name && quantity >= 1 && quantity <= 99 {
                req.Created("/api/items/42", "name", name, "quantity", quantity);
            } else {
                req.BadRequest();
            }
        };
    };
    app.Run();
}

fn main() { program_main(args()); }

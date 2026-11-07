import .http;
import json;

fn bad(client: i32) {
    respond(client, 400, "", "");
}

fn handle(client: i32, method: u8[:], target: u8[:], body: u8[:]) {
    guard method == "POST" && path_of(target) == "/api/items" else { missing(client); return; }

    var mime: u8[>..] = [];
    dg_header("Content-Type", mime);
    guard mime[..] == "application/json" else { bad(client); return; }

    var doc: json::Node[>..] = [];
    var decoded: u8[>..] = [];
    let item, error = json::parse(body, doc, decoded);
    guard error.len == 0 else { bad(client); return; }

    let name, has_name = json::as_string(json::member(item, "name"));
    let quantity, has_quantity = json::as_i64(json::member(item, "quantity"));
    guard has_name && has_quantity && name.len > 0 && name.len <= 32 &&
          quantity >= 1 && quantity <= 99 else { bad(client); return; }
    for c in name {
        if !(ascii::is_alpha(c) || ascii::is_digit(c)) { bad(client); return; }
    }

    let response = str("{\"name\":\"", name, "\",\"quantity\":", quantity, "}");
    dg_reply(client, 201, "application/json; charset=utf-8", response, "", "", "/api/items/42");
}

fn main() {
    serve(handle);
}

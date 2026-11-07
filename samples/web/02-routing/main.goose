import .http;

fn handle(client: i32, method: u8[:], target: u8[:], body: u8[:]) {
    let path = path_of(target);
    guard method == "GET" && starts_with(path, "/api/items/") else { missing(client); return; }

    let id, valid = parse_int(path[11..]);
    guard valid && id > 0 && id <= 2147483647 else { missing(client); return; }

    let query = query_of(target);
    if query == "includeDetails=true" {
        respond(client, 200, "application/json", str("{\"id\":", id, ",\"details\":\"starter\"}"));
    } else if query.len == 0 || query == "includeDetails=false" {
        respond(client, 200, "application/json", str("{\"id\":", id, "}"));
    } else {
        respond(client, 400, "", "");
    }
}

fn main() {
    serve(handle);
}

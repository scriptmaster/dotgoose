import .http;

fn endpoint(client: i32, id: u8[:]) {
    dg_reply(client, 200, "text/plain; charset=utf-8", "pong", id, "id,endpoint", "");
}

fn valid_id(id: u8[:]) -> bool {
    guard id.len > 0 && id.len <= 64 else { return false; }
    for c in id {
        if !(ascii::is_alpha(c) || ascii::is_digit(c)) && c != '_' && c != '-' { return false; }
    }
    return true;
}

fn handle(client: i32, method: u8[:], target: u8[:], body: u8[:]) {
    guard method == "GET" && path_of(target) == "/api/ping" else { missing(client); return; }

    var id: u8[>..] = [];
    dg_header("X-Request-Id", id);
    guard valid_id(id) else {
        dg_reply(client, 400, "", "", "", "id", "");
        return;
    }

    endpoint(client, id);
}

fn main() {
    serve(handle);
}

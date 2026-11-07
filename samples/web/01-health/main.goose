import .http;

fn handle(client: i32, method: u8[:], target: u8[:], body: u8[:]) {
    if method == "GET" && path_of(target) == "/healthz" {
        respond(client, 200, "application/json", "{\"status\":\"ok\"}");
    } else {
        missing(client);
    }
}

fn main() {
    serve(handle);
}

import .http;
import .dotgoose;

struct Visit {
    step: i32,
}

fn advance(visit: Visit&) -> i32 {
    visit.step = visit.step.add(1);
    return visit.step;
}

fn endpoint(client: i32, visit: Visit&) {
    respond(client, 200, "application/json", str("{\"step\":", visit.advance(), "}"));
}

fn handle(client: i32, method: u8[:], target: u8[:], body: u8[:]) {
    var visit = Visit { step: 0 };
    visit.advance();

    if method == "GET" && path_of(target) == "/api/visit" {
        endpoint(client, visit);
    } else {
        missing(client);
    }
}

fn main() {
    serve(handle);
}

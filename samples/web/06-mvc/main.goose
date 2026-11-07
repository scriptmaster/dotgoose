import .http;

struct CatalogItem {
    id: i32,
    name: const u8[:],
}

fn view(item: CatalogItem) -> u8[>..] {
    return str("<!doctype html>\n<html lang=\"en\">\n<title>Catalog</title>\n<h1>",
               item.name, "</h1>\n<p>Item ", item.id, "</p>\n</html>\n");
}

fn handle(client: i32, method: u8[:], target: u8[:], body: u8[:]) {
    let path = path_of(target);
    guard method == "GET" && starts_with(path, "/catalog/") else { missing(client); return; }

    let id, valid = parse_int(path[9..]);
    guard valid && id == 42 else { missing(client); return; }

    let item = CatalogItem { id: 42, name: "Goose" };
    respond(client, 200, "text/html; charset=utf-8", item.view());
}

fn main() {
    serve(handle);
}

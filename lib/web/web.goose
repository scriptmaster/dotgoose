namespace web;

import .http;
import .hosting;
import json;
import std;

extern fn dg_method_not_allowed(client: i32, allow: const u8[:]);

struct App<T> {
    client: i32,
    method: u8[:],
    path: u8[:],
    query: u8[:],
    body: u8[:],
    id: i32 = 0,
    state: T,
    handled: bool = false,
    allow_get: bool = false,
    allow_post: bool = false,
    request_id: u8[..64] = [],
    stages: u8[..16] = [],
}

fn match_path<T>(app: App<T>&, route: const u8[:]) -> bool {
    let positive = ends_with(route, "/{id:int:min(1)}");
    let marker = if positive { "{id:int:min(1)}" } else { "{id:int}" };
    if !positive && !ends_with(route, "/{id:int}") { return app.path == route; }

    let prefix = route[..route.len-marker.len];
    if !starts_with(app.path, prefix) { return false; }
    let id, ok = parse_int(app.path[prefix.len..]);
    if !ok || id < -2147483648 || id > 2147483647 || (positive && id < 1) { return false; }
    app.id = id as i32;
    return true;
}

fn Reply(app, status: i32, mime: const u8[:], body: const u8[:], location: const u8[:] = "") {
    if app.handled { return; }
    app.handled = true;
    dg_reply(app.client, status, mime, body, app.request_id, app.stages, location);
}

fn BadRequest(app) { app.Reply(400, "", ""); }
fn NotFound(app) { app.Reply(404, "", ""); }
fn Text(app, body: const u8[:]) { app.Reply(200, "text/plain; charset=utf-8", body); }
fn Html(app, body: const u8[:]) { app.Reply(200, "text/html; charset=utf-8", body); }

fn Header(app, name: const u8[:]) -> u8[>..] {
    var value: u8[>..] = [];
    dg_header(name, value);
    return value;
}

fn Stages(app, value: const u8[:]) {
    app.stages = value;
}

fn RequireRequestId(app) {
    let id = app.Header("X-Request-Id");
    if id.len < 1 || id.len > 64 { app.BadRequest(); return; }
    for c in id {
        if !(ascii::is_alpha(c) || ascii::is_digit(c) || c == '_' || c == '-') {
            app.BadRequest();
            return;
        }
    }
    app.request_id = id;
}

fn ReadJson<Read>(app) {
    var mime = app.Header("Content-Type");
    to_lower(mime);
    if mime[..] != "application/json" { app.BadRequest(); return; }

    var nodes: json::Node[>..] = [];
    var decoded: u8[>..] = [];
    let root, error = json::parse(app.body, nodes, decoded);
    if error.len != 0 { app.BadRequest(); return; }
    Read(root);
}

fn json_value(out: u8[>..]&, value: const u8[:]) { json::format_string(out, value); }
fn json_value(out: u8[>..]&, value: i64) { json::format_int(out, value); }

fn json_object(key: const u8[:], value) -> u8[>..] {
    var out: u8[>..] = ['{'];
    json::format_key(out, key);
    json_value(out, value);
    out.push('}');
    return out;
}

fn json_object(key: const u8[:], value, second_key: const u8[:], second_value) -> u8[>..] {
    var out: u8[>..] = ['{'];
    json::format_key(out, key);
    json_value(out, value);
    out.push(',');
    json::format_key(out, second_key);
    json_value(out, second_value);
    out.push('}');
    return out;
}

fn Json(app, key: const u8[:], value) {
    app.Reply(200, "application/json", json_object(key, value));
}

fn Json(app, key: const u8[:], value, second_key: const u8[:], second_value) {
    app.Reply(200, "application/json", json_object(key, value, second_key, second_value));
}

fn Created(app, location: const u8[:], key: const u8[:], value, second_key: const u8[:], second_value) {
    app.Reply(201, "application/json", json_object(key, value, second_key, second_value), location);
}

fn HtmlValue(out: u8[>..]&, text: const u8[:]) {
    for c in text {
        if c == '&' { out.append("&amp;"); }
        else if c == '<' { out.append("&lt;"); }
        else if c == '>' { out.append("&gt;"); }
        else if c == '"' { out.append("&quot;"); }
        else if c == '\'' { out.append("&#39;"); }
        else { out.push(c); }
    }
}

fn HtmlValue(out: u8[>..]&, value: i64) {
    format(out, value);
}

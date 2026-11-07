import os;
import std;

extern fn dg_listen(port: i32) -> i32;
extern fn dg_accept(listener: i32) -> i32;
extern fn dg_request(method: u8[>..]&, target: u8[>..]&, body: u8[>..]&);
extern fn dg_header(key: const u8[:], out: u8[>..]&);
extern fn dg_reply(client: i32, status: i32, mime: const u8[:], body: const u8[:],
                   request_id: const u8[:], stages: const u8[:], location: const u8[:]);

fn serve_port<Handle>(port: i32) {
    let listener = dg_listen(port);
    guard listener >= 0 else { abort("could not listen on loopback"); }

    loop {
        let client = dg_accept(listener);
        if client == -1 { continue; }
        guard client >= 0 else { abort("could not accept connection"); }

        var method: u8[>..] = [];
        var target: u8[>..] = [];
        var body: u8[>..] = [];
        dg_request(method, target, body);
        Handle(client, method[..], target[..], body[..]);
    }
}

fn path_of(target: u8[:]) -> u8[:] {
    let index = position(target, '?');
    return if index < 0 { target } else { target[..index] };
}

fn query_of(target: u8[:]) -> u8[:] {
    let index = position(target, '?');
    return if index < 0 { target[target.len..] } else { target[index+1..] };
}

import .dotgoose;

struct Counter {
    Value: i32,
}

fn Next(receiver: Counter&) -> i32 {
    receiver.Value = receiver.Value.add(1);
    return receiver.Value;
}

fn main() {
    print("""{"status":"ok"}""");
    print("""C:\temp\new "quoted" \n""");
    print("A triple quote is \"\"\" in this string.");
    print("""
            {
              "status": "ok"
            }
            """);
    var id: i32 = 42;
    var enabled: bool = true;
    var name: u8[>..] = str("Goose");
    print(str("Item ", id, ": ", name, ", enabled=", dotgoose::interpolate(enabled), "."));
    print(str("{\"id\":", id, ",\"status\":\"ok\"}"));
    print(str("Next ID: ", id.add(1), ". Escaped braces: {", id, "}."));
    print(str("Braces: {", id, "}; Boolean: ", dotgoose::interpolate((enabled == false)), "."));
    print(str("Escapes: \"quoted\"\t", id, "\nend"));
    print(str("Nested text: ", "ok", "."));
    print(str(""));
    var copy: u8[>..] = str(name);
    name = str("DotGoose");
    print(str("", copy, " -> ", name, ""));
    var counter: Counter = Counter { Value: 0 };
    print(str("", counter.Next(), " then ", counter.Next(), ""));
}

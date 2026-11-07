import .dotgoose;

struct Counter {
    value: i32,
}

fn new_Counter(start: i32) -> Counter {
    var receiver = Counter { value: 0 };
    receiver.value = start;
    return receiver;
}

fn Add(receiver: Counter&, delta: i32) {
    receiver.value = receiver.value.add(delta);
}

fn Read(receiver: Counter&) -> i32 {
    return receiver.value;
}

struct Point {
    X: i32,
    Y: i32,
}

fn Sum(receiver: Point&) -> i32 {
    return receiver.X.add(receiver.Y);
}

fn main() {
    var counter: Counter = new_Counter(40);
    counter.Add(2);
    print(counter.Read());
    var point: Point = Point { X: 0, Y: 0 };
    point.X = 8;
    point.Y = 5;
    var copy: Point = point;
    copy.X = 0;
    print(point.Sum());
    print(copy.Sum());
}

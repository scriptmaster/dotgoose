import .dotgoose;

fn main() {
    print("DotGoose");
    var value: i32 = 40;
    value = value.add(2);
    if (value == 42) {
        print(value);
    }
    var max: i32 = 2147483647;
    print(max.add(1));
}

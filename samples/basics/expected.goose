import .dotgoose;

fn main() {
    print("DotGoose");
    var value: i32 = 40;
    value = dotgoose::add_i32(value, 2);
    if (value == 42) {
        print(value);
    }
    var max: i32 = 2147483647;
    print(dotgoose::add_i32(max, 1));
}

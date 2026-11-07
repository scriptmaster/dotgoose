import .dotgoose;

fn main() {
    let max: i32 = 2147483647;
    assert(max.add(1) == -2147483648);
    assert(dotgoose::add(max, 1) == -2147483648);
    assert(1.add(max) == -2147483648);
    assert((-1).add(-2147483648) == max);
}

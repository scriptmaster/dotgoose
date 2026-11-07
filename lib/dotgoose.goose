namespace dotgoose;

fn add(a: i32, b: i32) -> i32 {
    return ((a as! u32) + (b as! u32)) as! i32;
}

fn ::add(a: i32, b: i32) -> i32 {
    return dotgoose::add(a, b);
}

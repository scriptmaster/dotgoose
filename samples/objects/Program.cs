using System;

sealed class Counter
{
    int value;

    public Counter(int start)
    {
        value = start;
    }

    public void Add(int delta)
    {
        value = value + delta;
    }

    public int Read()
    {
        return value;
    }
}

struct Point
{
    public int X;
    public int Y;

    public int Sum()
    {
        return X + Y;
    }
}

static class Program
{
    static void Main()
    {
        var counter = new Counter(40);
        counter.Add(2);
        Console.WriteLine(counter.Read());
        var point = new Point();
        point.X = 8;
        point.Y = 5;
        var copy = point;
        copy.X = 0;
        Console.WriteLine(point.Sum());
        Console.WriteLine(copy.Sum());
    }
}

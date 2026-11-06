using System;

struct Point
{
    public int X;
    public int Read()
    {
        return X;
    }
}

sealed class Counter
{
    public int Value;

    public void Set(int value, bool enabled)
    {
        if (enabled)
        {
            Value = value;
            return;
        }
        Value = -1;
    }

    public int Read()
    {
        return Value;
    }

    public int ReadTwice()
    {
        return this.Read() + this.Read();
    }
}

static class Program
{
    static void Main()
    {
        var point = new Point();
        var counter = new Counter();
        point.X = 7;
        counter.Set(21, true);
        Console.WriteLine(point.Read());
        Console.WriteLine(counter.Read());
        Console.WriteLine(counter.ReadTwice());
        counter.Set(30, false);
        Console.WriteLine(counter.Read());
    }
}

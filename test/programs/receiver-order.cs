using System;

static class Program
{
    static void Main()
    {
        var counter = new Counter(10);
        Console.WriteLine(counter.Next() + counter.Take(counter.Next(), counter.Next()));
        Console.WriteLine(counter.Current());
    }
}

sealed class Counter
{
    int value;

    public Counter(int start)
    {
        this.value = start;
    }

    public int Next()
    {
        value = value + 1;
        Console.WriteLine(value);
        return value;
    }

    public int Take(int first, int second)
    {
        Console.WriteLine(first);
        return second;
    }

    public int Current()
    {
        return this.value;
    }
}

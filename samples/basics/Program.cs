using System;

static class Program
{
    static void Main()
    {
        Console.WriteLine("DotGoose");
        int value = 40;
        value = value + 2;
        if (value == 42)
        {
            Console.WriteLine(value);
        }
        int max = 2147483647;
        Console.WriteLine(max + 1);
    }
}

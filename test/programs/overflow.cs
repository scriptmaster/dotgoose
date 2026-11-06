using System;

static class Program
{
    static void Main()
    {
        int max = 2147483647;
        int min = -2147483648;
        Console.WriteLine(max + 1);
        Console.WriteLine(min + -1);
        Console.WriteLine((max + max) + 2);
    }
}

using System;

static class Program
{
    static void Main()
    {
        int index = 0, stop = 5;
        int total = -2;
        bool active = true;
        while (index < stop)
        {
            if (index != 2)
            {
                total = total + index;
            }
            else
            {
                active = false;
            }
            index = index + 1;
        }
        if ((total >= 6) == (active == false))
        {
            Console.WriteLine(total);
        }
        else
        {
            Console.WriteLine("unexpected");
        }
    }
}

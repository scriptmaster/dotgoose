struct Point
{
    public int X, Y;
    public bool Ready;

    public Point(int x)
    {
        X = x;
        Ready = true;
    }

    public int Value()
    {
        if (Ready)
        {
            return X + Y;
        }
        else
        {
            return -1;
        }
    }
}

static class Program
{
    static void Main()
    {
        Point point = new Point(7), blank = new Point();
        blank.Y = 4;
        Point copy = blank;
        copy = point;
        copy.X = 9;
        System.Console.WriteLine(point.Value());
        System.Console.WriteLine(blank.Value());
        System.Console.WriteLine(copy.Value());
    }
}

sealed class Counter
{
    public int Value;
}

static class Program
{
    static void Main()
    {
        var original = new Counter();
        var alias = original;
        alias.Value = 1;
    }
}

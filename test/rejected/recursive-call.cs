sealed class Counter
{
    public int Value;
    public int Read() { return this.Read(); }
}
static class Program { static void Main() { var counter = new Counter(); } }

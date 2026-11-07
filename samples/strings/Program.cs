using System;

struct Counter
{
    public int Value;

    public int Next()
    {
        this.Value = this.Value + 1;
        return this.Value;
    }
}

static class Program
{
    static void Main()
    {
        Console.WriteLine("""{"status":"ok"}""");
        Console.WriteLine("""C:\temp\new "quoted" \n""");
        Console.WriteLine(""""A triple quote is """ in this string."""");
        Console.WriteLine("""
            {
              "status": "ok"
            }
            """);

        int id = 42;
        bool enabled = true;
        string name = "Goose";
        Console.WriteLine($"Item {id}: {name}, enabled={enabled}.");
        Console.WriteLine($$"""{"id":{{id}},"status":"ok"}""");
        Console.WriteLine($"Next ID: {id + 1}. Escaped braces: {{{id}}}.");
        Console.WriteLine($$"""Braces: {{{id}}}; Boolean: {{enabled == false}}.""");
        Console.WriteLine($"Escapes: \"quoted\"\t{id}\nend");
        Console.WriteLine($"Nested text: {"ok"}.");
        Console.WriteLine($"");

        var copy = name;
        name = "DotGoose";
        Console.WriteLine($"{copy} -> {name}");

        Counter counter = new Counter();
        Console.WriteLine($"{counter.Next()} then {counter.Next()}");
    }
}

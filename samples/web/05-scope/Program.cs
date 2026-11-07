var builder = WebApplication.CreateSlimBuilder(args);
builder.Logging.ClearProviders();
builder.Services.AddScoped<Visit>();

var app = builder.Build();
app.Use(async (context, next) =>
{
    context.RequestServices.GetRequiredService<Visit>().Advance();
    await next(context);
});

app.MapGet("/api/visit", (Visit visit) =>
    Results.Text($$"""{"step":{{visit.Advance()}}}""", "application/json"));
app.Run();

public sealed class Visit
{
    private int step;

    public int Advance() => ++step;
}

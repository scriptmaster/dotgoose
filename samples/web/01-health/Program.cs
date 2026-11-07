var builder = WebApplication.CreateSlimBuilder(args);
builder.Logging.ClearProviders();

var app = builder.Build();
app.MapGet("/healthz", () => Results.Text("""{"status":"ok"}""", "application/json"));
app.Run();

var builder = WebApplication.CreateSlimBuilder(args);
builder.Logging.ClearProviders();

var app = builder.Build();
app.Use(async (context, next) =>
{
    if (context.Request.Method == "GET" && context.Request.Path == "/api/ping")
    {
        var id = context.Request.Headers["X-Request-Id"].ToString();
        context.Response.Headers["X-Stages"] = "id";
        if (id.Length is < 1 or > 64 || id.Any(c => !char.IsAsciiLetterOrDigit(c) && c is not '_' and not '-'))
        {
            context.Response.StatusCode = 400;
            return;
        }

        context.Response.Headers["X-Request-Id"] = id;
    }
    await next(context);
});

app.Use(async (context, next) =>
{
    if (context.Response.Headers.ContainsKey("X-Request-Id"))
        context.Response.Headers["X-Stages"] = "id,endpoint";
    await next(context);
});

app.MapGet("/api/ping", () => Results.Text("pong"));
app.Run();

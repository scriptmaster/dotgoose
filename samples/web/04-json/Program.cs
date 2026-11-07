using System.Text.Json;
using System.Text.Json.Serialization;

var builder = WebApplication.CreateSlimBuilder(args);
builder.Logging.ClearProviders();

var app = builder.Build();
app.MapPost("/api/items", async (HttpRequest request) =>
{
    if (!string.Equals(request.ContentType, "application/json", StringComparison.OrdinalIgnoreCase))
        return Results.BadRequest();

    NewItem? item;
    try
    {
        item = await JsonSerializer.DeserializeAsync(request.Body, WebJson.Default.NewItem);
    }
    catch (JsonException)
    {
        return Results.BadRequest();
    }

    if (item?.Name is not { Length: >= 1 and <= 32 } name ||
        name.Any(c => !char.IsAsciiLetterOrDigit(c)) || item.Quantity is < 1 or > 99)
        return Results.BadRequest();

    request.HttpContext.Response.Headers.Location = "/api/items/42";
    return Results.Json(new NewItem(name, item.Quantity), WebJson.Default.NewItem, statusCode: 201);
});
app.Run();

public sealed record NewItem(string? Name, int Quantity);

[JsonSourceGenerationOptions(PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase)]
[JsonSerializable(typeof(NewItem))]
internal partial class WebJson : JsonSerializerContext;

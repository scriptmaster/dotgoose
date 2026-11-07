var builder = WebApplication.CreateSlimBuilder(args);
builder.Logging.ClearProviders();

var app = builder.Build();
app.MapGet("/api/items/{id:int:min(1)}", (int id, HttpRequest request) =>
{
    var details = request.QueryString.Value;
    return details switch
    {
        null or "" or "?includeDetails=false" => Results.Text($$"""{"id":{{id}}}""", "application/json"),
        "?includeDetails=true" => Results.Text($$"""{"id":{{id}},"details":"starter"}""", "application/json"),
        _ => Results.BadRequest()
    };
});
app.Run();

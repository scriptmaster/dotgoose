using Microsoft.AspNetCore.Mvc;

var builder = WebApplication.CreateBuilder(args);
builder.Logging.ClearProviders();
builder.Services.AddControllersWithViews();

var app = builder.Build();
app.MapControllers();
app.Run();

public sealed record CatalogItem(int Id, string Name);

[Route("catalog")]
public sealed class CatalogController : Controller
{
    [HttpGet("{id:int}")]
    public IActionResult Show(int id)
    {
        if (id != 42)
            return NotFound();

        return View(new CatalogItem(id, "Goose"));
    }
}

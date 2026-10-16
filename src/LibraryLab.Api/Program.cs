using System.Text.Encodings.Web;
using Dapper;
using LibraryLab.Api;
using LibraryLab.Api.Data;
using LibraryLab.Api.Services;
using Npgsql;

var builder = WebApplication.CreateBuilder(args);

// snake_case columns from views map to PascalCase properties: library_card_number -> LibraryCardNumber
DefaultTypeMap.MatchNamesWithUnderscores = true;

var connectionString = builder.Configuration.GetConnectionString("Library")
    ?? throw new InvalidOperationException("Connection string 'Library' is missing in appsettings.json");

builder.Services.AddSingleton(NpgsqlDataSource.Create(connectionString));
builder.Services.AddSingleton<IUnitOfWorkFactory, UnitOfWorkFactory>();
builder.Services.AddScoped<LibraryService>();

builder.Services
    .AddControllers(o => o.Filters.Add<ApiExceptionFilter>())
    // keep Cyrillic and "+" readable in JSON instead of Ук...
    .AddJsonOptions(o => o.JsonSerializerOptions.Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping);

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(o =>
{
    o.SwaggerDoc("v1", new() { Title = "Library Lab API", Version = "v1" });
    o.OperationFilter<StaffHeaderOperationFilter>();
    o.IncludeXmlComments(Path.Combine(AppContext.BaseDirectory, "LibraryLab.Api.xml"));
});

var app = builder.Build();

// expected errors are answered by ApiExceptionFilter; anything else is logged and becomes 500
app.UseExceptionHandler(errorApp => errorApp.Run(async context =>
{
    context.Response.StatusCode = StatusCodes.Status500InternalServerError;
    await context.Response.WriteAsJsonAsync(new { error = "Unexpected server error, see the server log" });
}));

app.UseSwagger();
app.UseSwaggerUI();

app.MapControllers();
app.MapGet("/", () => Results.Redirect("/swagger")).ExcludeFromDescription();

app.Run();

using Consware.Reimbursements.Api.Data;
using Consware.Reimbursements.Api.Services;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));
builder.Services.AddScoped<IReimbursementService, ReimbursementService>();

// Angular (navegador) necesita el origen declarado; Flutter no depende de CORS.
// En desarrollo ng serve cambia de puerto si el 4200 está ocupado (p. ej.
// http://localhost:49718), así que se acepta cualquier puerto siempre que el
// host sea local. Fuera de localhost no se autoriza ningún origen.
static bool IsLocalOrigin(string origin) =>
    Uri.TryCreate(origin, UriKind.Absolute, out var uri) &&
    uri.Scheme == "http" &&
    (uri.Host == "localhost" || uri.Host == "127.0.0.1");

builder.Services.AddCors(options =>
    options.AddPolicy("AngularLocal", policy =>
        policy.SetIsOriginAllowed(IsLocalOrigin)
              .AllowAnyHeader()
              .AllowAnyMethod()));

var app = builder.Build();

app.UseCors("AngularLocal");
app.MapControllers();
app.Run();

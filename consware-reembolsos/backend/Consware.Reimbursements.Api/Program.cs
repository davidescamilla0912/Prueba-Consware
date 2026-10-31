using Consware.Reimbursements.Api.Data;
using Consware.Reimbursements.Api.Services;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));
builder.Services.AddScoped<IReimbursementService, ReimbursementService>();

// Angular (navegador) necesita el origen declarado; Flutter no depende de CORS.
builder.Services.AddCors(options =>
    options.AddPolicy("AngularLocal", policy =>
        policy.WithOrigins("http://localhost:4200")
              .AllowAnyHeader()
              .AllowAnyMethod()));

var app = builder.Build();

app.UseCors("AngularLocal");
app.MapControllers();
app.Run();

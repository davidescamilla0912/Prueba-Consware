using Api;
using Microsoft.EntityFrameworkCore;
using System.Text.Json.Serialization;

var b = WebApplication.CreateBuilder(args);
b.Services.AddDbContext<AppDbContext>(o => o.UseSqlServer(b.Configuration.GetConnectionString("Default")));
b.Services.AddScoped<ReimbursementService>();
b.Services.AddControllers().AddJsonOptions(o => o.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter()));
b.Services.AddCors(o => o.AddDefaultPolicy(p => p.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod()));

var app = b.Build();
app.UseCors();
app.MapControllers();
app.Run();

using Consware.Reimbursements.Api.Models;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage.ValueConversion;

namespace Consware.Reimbursements.Api.Data;

public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<ReimbursementRequest> ReimbursementRequests => Set<ReimbursementRequest>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        var entity = modelBuilder.Entity<ReimbursementRequest>();

        entity.ToTable("ReimbursementRequests");
        entity.HasKey(x => x.Id);

        entity.Property(x => x.EmployeeName).IsRequired().HasMaxLength(100);
        entity.Property(x => x.Amount).HasPrecision(18, 2).IsRequired();
        entity.Property(x => x.Category).IsRequired().HasMaxLength(60);
        entity.Property(x => x.Description).IsRequired().HasMaxLength(500);
        entity.Property(x => x.RejectionReason).HasMaxLength(500);

        // El estado se guarda como texto: 'Pending', 'Approved' o 'Rejected'.
        entity.Property(x => x.Status)
            .HasConversion<string>()
            .HasMaxLength(16)
            .IsUnicode(false);

        // datetime2 se materializa con Kind=Unspecified: System.Text.Json entonces
        // serializa sin 'Z' y Flutter lo interpreta como hora local (5 h de desfase
        // en Colombia). El convertidor sólo fija Kind=Utc en la lectura; no cambia
        // el valor ni el tipo de columna, así que no requiere migración.
        var utc = new ValueConverter<DateTime, DateTime>(
            v => v, v => DateTime.SpecifyKind(v, DateTimeKind.Utc));
        var utcNullable = new ValueConverter<DateTime?, DateTime?>(
            v => v, v => v.HasValue ? DateTime.SpecifyKind(v.Value, DateTimeKind.Utc) : v);

        entity.Property(x => x.CreatedAtUtc).HasColumnType("datetime2").HasConversion(utc);
        entity.Property(x => x.DecidedAtUtc).HasColumnType("datetime2").HasConversion(utcNullable);

        // Defensa en base de datos (la validación sigue viva en el servicio).
        entity.ToTable("ReimbursementRequests", t =>
        {
            t.HasCheckConstraint("CK_Reimbursements_Amount", "[Amount] > 0");
            t.HasCheckConstraint("CK_Reimbursements_Status",
                "[Status] IN ('Pending','Approved','Rejected')");
            t.HasCheckConstraint("CK_Reimbursements_RejectionReason",
                "[Status] <> 'Rejected' OR ([RejectionReason] IS NOT NULL AND LEN(LTRIM(RTRIM([RejectionReason]))) > 0)");
        });

        entity.HasIndex(x => x.Status);
        entity.HasIndex(x => x.EmployeeName);
    }
}

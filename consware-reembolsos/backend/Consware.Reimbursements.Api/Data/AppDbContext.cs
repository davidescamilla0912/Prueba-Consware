using Consware.Reimbursements.Api.Models;
using Microsoft.EntityFrameworkCore;

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

        entity.Property(x => x.CreatedAtUtc).HasColumnType("datetime2");
        entity.Property(x => x.DecidedAtUtc).HasColumnType("datetime2");

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

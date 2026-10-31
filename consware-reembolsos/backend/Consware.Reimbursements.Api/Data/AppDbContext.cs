using Microsoft.EntityFrameworkCore;

namespace Api;

public class AppDbContext(DbContextOptions<AppDbContext> o) : DbContext(o)
{
    public DbSet<ReimbursementRequest> ReimbursementRequests => Set<ReimbursementRequest>();

    protected override void OnModelCreating(ModelBuilder b)
    {
        var e = b.Entity<ReimbursementRequest>();
        e.Property(x => x.Amount).HasColumnType("decimal(18,2)");
        e.Property(x => x.EmployeeName).HasMaxLength(100);
        e.Property(x => x.Category).HasMaxLength(60);
        e.Property(x => x.Description).HasMaxLength(500);
        e.Property(x => x.RejectionReason).HasMaxLength(500);
        e.Property(x => x.Status).HasConversion<string>().HasMaxLength(16);
    }
}

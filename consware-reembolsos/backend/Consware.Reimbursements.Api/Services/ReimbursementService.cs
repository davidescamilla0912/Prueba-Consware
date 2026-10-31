using Microsoft.EntityFrameworkCore;

namespace Api;

public record CreateDto(string? EmployeeName, decimal Amount, string? Category, string? Description);
public record RejectDto(string? Reason);

public class ReimbursementService(AppDbContext db)
{
    public async Task<ReimbursementRequest> CreateAsync(CreateDto d)
    {
        if (d.Amount <= 0) throw new ArgumentException("El monto debe ser mayor que 0.");
        if (string.IsNullOrWhiteSpace(d.Category)) throw new ArgumentException("La categoría es obligatoria.");
        if (string.IsNullOrWhiteSpace(d.Description)) throw new ArgumentException("La descripción es obligatoria.");

        var now = DateTime.UtcNow;
        var auto = d.Amount <= 500000m;
        var r = new ReimbursementRequest
        {
            EmployeeName = string.IsNullOrWhiteSpace(d.EmployeeName) ? "Empleado Demo" : d.EmployeeName.Trim(),
            Amount = d.Amount,
            Category = d.Category.Trim(),
            Description = d.Description.Trim(),
            Status = auto ? ReimbursementStatus.Approved : ReimbursementStatus.Pending,
            CreatedAtUtc = now,
            DecidedAtUtc = auto ? now : null
        };
        db.Add(r);
        await db.SaveChangesAsync();
        return r;
    }

    public Task<List<ReimbursementRequest>> ListAsync(ReimbursementStatus? status, string? employee)
    {
        var q = db.ReimbursementRequests.AsNoTracking().AsQueryable();
        if (status != null) q = q.Where(x => x.Status == status);
        if (!string.IsNullOrWhiteSpace(employee)) q = q.Where(x => x.EmployeeName == employee);
        return q.OrderByDescending(x => x.CreatedAtUtc).ToListAsync();
    }

    public async Task<ReimbursementRequest> GetAsync(int id) =>
        await db.ReimbursementRequests.FindAsync(id)
        ?? throw new KeyNotFoundException("Solicitud no encontrada.");

    public async Task<ReimbursementRequest> ApproveAsync(int id)
    {
        var r = await GetAsync(id);
        if (r.Status != ReimbursementStatus.Pending)
            throw new InvalidOperationException("La solicitud ya fue decidida.");
        r.Status = ReimbursementStatus.Approved;
        r.DecidedAtUtc = DateTime.UtcNow;
        await db.SaveChangesAsync();
        return r;
    }

    public async Task<ReimbursementRequest> RejectAsync(int id, string? reason)
    {
        if (string.IsNullOrWhiteSpace(reason)) throw new ArgumentException("El motivo es obligatorio.");
        var r = await GetAsync(id);
        if (r.Status != ReimbursementStatus.Pending)
            throw new InvalidOperationException("La solicitud ya fue decidida.");
        r.Status = ReimbursementStatus.Rejected;
        r.RejectionReason = reason.Trim();
        r.DecidedAtUtc = DateTime.UtcNow;
        await db.SaveChangesAsync();
        return r;
    }
}

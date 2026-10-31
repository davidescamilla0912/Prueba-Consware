using Consware.Reimbursements.Api.Data;
using Consware.Reimbursements.Api.DTOs;
using Consware.Reimbursements.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace Consware.Reimbursements.Api.Services;

public class ReimbursementService(AppDbContext db) : IReimbursementService
{
    /// <summary>Umbral central: 500.000 COP exactos se aprueba; 500.000,01 queda pendiente.</summary>
    private const decimal AutoApproveLimit = 500000m;

    public async Task<ReimbursementResponseDto> CreateAsync(CreateReimbursementDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.EmployeeName))
            throw new ArgumentException("El nombre del empleado es obligatorio.");
        if (dto.EmployeeName.Trim().Length > 100)
            throw new ArgumentException("El nombre del empleado no puede superar 100 caracteres.");
        if (dto.Amount <= 0)
            throw new ArgumentException("El monto debe ser mayor a cero.");
        if (string.IsNullOrWhiteSpace(dto.Category))
            throw new ArgumentException("La categoría es obligatoria.");
        if (dto.Category.Trim().Length > 60)
            throw new ArgumentException("La categoría no puede superar 60 caracteres.");
        if (string.IsNullOrWhiteSpace(dto.Description))
            throw new ArgumentException("La descripción es obligatoria.");
        if (dto.Description.Trim().Length > 500)
            throw new ArgumentException("La descripción no puede superar 500 caracteres.");

        var now = DateTime.UtcNow;
        var autoApproved = dto.Amount <= AutoApproveLimit;

        var request = new ReimbursementRequest
        {
            EmployeeName = dto.EmployeeName.Trim(),
            Amount = dto.Amount,
            Category = dto.Category.Trim(),
            Description = dto.Description.Trim(),
            Status = autoApproved ? ReimbursementStatus.Approved : ReimbursementStatus.Pending,
            CreatedAtUtc = now,
            DecidedAtUtc = autoApproved ? now : null
        };

        db.ReimbursementRequests.Add(request);
        await db.SaveChangesAsync();

        return ToResponse(request);
    }

    public async Task<List<ReimbursementResponseDto>> GetAllAsync(string? status, string? employeeName)
    {
        var query = db.ReimbursementRequests.AsNoTracking();

        if (!string.IsNullOrWhiteSpace(status))
        {
            if (!TryParseStatus(status, out var parsed))
                throw new ArgumentException("Filtro de estado desconocido. Use Pending, Approved o Rejected.");

            query = query.Where(x => x.Status == parsed);
        }

        if (!string.IsNullOrWhiteSpace(employeeName))
            query = query.Where(x => x.EmployeeName == employeeName);

        var items = await query.OrderByDescending(x => x.CreatedAtUtc).ToListAsync();

        return items.Select(ToResponse).ToList();
    }

    public async Task<ReimbursementResponseDto?> GetByIdAsync(int id) =>
        ToResponseOrNull(await db.ReimbursementRequests.AsNoTracking()
            .FirstOrDefaultAsync(x => x.Id == id));

    public async Task<ReimbursementResponseDto> ApproveAsync(int id)
    {
        var request = await db.ReimbursementRequests.FindAsync(id)
            ?? throw new KeyNotFoundException("Solicitud no encontrada.");

        if (request.Status != ReimbursementStatus.Pending)
            throw new InvalidOperationException("La solicitud ya fue decidida y no puede cambiar de estado.");

        request.Status = ReimbursementStatus.Approved;
        request.DecidedAtUtc = DateTime.UtcNow;
        await db.SaveChangesAsync();

        return ToResponse(request);
    }

    public async Task<ReimbursementResponseDto> RejectAsync(int id, string? reason)
    {
        if (string.IsNullOrWhiteSpace(reason))
            throw new ArgumentException("El motivo del rechazo es obligatorio.");
        if (reason.Trim().Length > 500)
            throw new ArgumentException("El motivo del rechazo no puede superar 500 caracteres.");

        var request = await db.ReimbursementRequests.FindAsync(id)
            ?? throw new KeyNotFoundException("Solicitud no encontrada.");

        if (request.Status != ReimbursementStatus.Pending)
            throw new InvalidOperationException("La solicitud ya fue decidida y no puede cambiar de estado.");

        request.Status = ReimbursementStatus.Rejected;
        request.RejectionReason = reason.Trim();
        request.DecidedAtUtc = DateTime.UtcNow;
        await db.SaveChangesAsync();

        return ToResponse(request);
    }

    private static bool TryParseStatus(string value, out ReimbursementStatus status)
    {
        foreach (var name in Enum.GetNames<ReimbursementStatus>())
        {
            if (string.Equals(name, value, StringComparison.OrdinalIgnoreCase))
            {
                status = Enum.Parse<ReimbursementStatus>(name);
                return true;
            }
        }

        status = default;
        return false;
    }

    private static ReimbursementResponseDto ToResponse(ReimbursementRequest request) => new(
        request.Id,
        request.EmployeeName,
        request.Amount,
        request.Category,
        request.Description,
        request.Status.ToString(),
        request.RejectionReason,
        request.CreatedAtUtc,
        request.DecidedAtUtc);

    private static ReimbursementResponseDto? ToResponseOrNull(ReimbursementRequest? request) =>
        request is null ? null : ToResponse(request);
}

using Consware.Reimbursements.Api.DTOs;

namespace Consware.Reimbursements.Api.Services;

/// <summary>
/// Toda la política de negocio vive aquí, nunca en widgets, componentes ni en el controller.
/// Contrato de errores: ArgumentException -> 400, KeyNotFoundException -> 404,
/// InvalidOperationException -> 409.
/// </summary>
public interface IReimbursementService
{
    Task<ReimbursementResponseDto> CreateAsync(CreateReimbursementDto dto);

    Task<List<ReimbursementResponseDto>> GetAllAsync(string? status, string? employeeName);

    Task<ReimbursementResponseDto?> GetByIdAsync(int id);

    Task<ReimbursementResponseDto> ApproveAsync(int id);

    Task<ReimbursementResponseDto> RejectAsync(int id, string? reason);
}

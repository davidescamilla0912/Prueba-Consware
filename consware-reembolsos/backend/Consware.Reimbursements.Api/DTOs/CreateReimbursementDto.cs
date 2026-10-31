namespace Consware.Reimbursements.Api.DTOs;

/// <summary>Contrato de entrada para POST /api/reimbursements.</summary>
public record CreateReimbursementDto(
    string EmployeeName,
    decimal Amount,
    string Category,
    string Description);

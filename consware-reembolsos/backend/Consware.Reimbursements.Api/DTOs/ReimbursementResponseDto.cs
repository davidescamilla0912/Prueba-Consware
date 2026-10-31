namespace Consware.Reimbursements.Api.DTOs;

/// <summary>Contrato de salida en JSON. El estado viaja como texto: Pending, Approved o Rejected.</summary>
public record ReimbursementResponseDto(
    int Id,
    string EmployeeName,
    decimal Amount,
    string Category,
    string Description,
    string Status,
    string? RejectionReason,
    DateTime CreatedAtUtc,
    DateTime? DecidedAtUtc);

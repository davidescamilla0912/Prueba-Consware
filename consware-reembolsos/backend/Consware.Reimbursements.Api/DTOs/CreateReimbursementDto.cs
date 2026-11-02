namespace Consware.Reimbursements.Api.DTOs;

/// <summary>
/// Contrato de entrada para POST /api/reimbursements.
/// Los textos son anulables a propósito: así [ApiController] no aplica un [Required]
/// implícito (que respondería en inglés y con otro formato) y la validación queda
/// en el servicio con string.IsNullOrWhiteSpace, devolviendo {"message": "..."}.
/// </summary>
public record CreateReimbursementDto(
    string? EmployeeName,
    decimal Amount,
    string? Category,
    string? Description);

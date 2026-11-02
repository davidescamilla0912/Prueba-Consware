namespace Consware.Reimbursements.Api.DTOs;

/// <summary>
/// Contrato de entrada para PATCH /api/reimbursements/{id}/reject.
/// Reason es anulable para que el servicio valide nulo/vacío/espacios con un único mensaje.
/// </summary>
public record RejectReimbursementDto(string? Reason);

namespace Consware.Reimbursements.Api.Models;

/// <summary>Estados de una solicitud. Nunca regresan de Pending a un estado final.</summary>
public enum ReimbursementStatus
{
    Pending,
    Approved,
    Rejected
}

namespace Api;

public class ReimbursementRequest
{
    public int Id { get; set; }
    public string EmployeeName { get; set; } = "Empleado Demo";
    public decimal Amount { get; set; }
    public string Category { get; set; } = "";
    public string Description { get; set; } = "";
    public ReimbursementStatus Status { get; set; }
    public string? RejectionReason { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public DateTime? DecidedAtUtc { get; set; }
}

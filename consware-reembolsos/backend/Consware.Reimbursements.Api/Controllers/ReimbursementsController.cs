using Microsoft.AspNetCore.Mvc;

namespace Api;

[ApiController]
[Route("api/reimbursements")]
public class ReimbursementsController(ReimbursementService s) : ControllerBase
{
    private async Task<IActionResult> Run(Func<Task<IActionResult>> f)
    {
        try { return await f(); }
        catch (ArgumentException e) { return BadRequest(new { error = e.Message }); }
        catch (KeyNotFoundException e) { return NotFound(new { error = e.Message }); }
        catch (InvalidOperationException e) { return Conflict(new { error = e.Message }); }
    }

    [HttpPost]
    public Task<IActionResult> Create(CreateDto d) => Run(async () =>
    {
        var r = await s.CreateAsync(d);
        return CreatedAtAction(nameof(Get), new { id = r.Id }, r);
    });

    [HttpGet]
    public async Task<IActionResult> List([FromQuery] ReimbursementStatus? status, [FromQuery] string? employeeName)
        => Ok(await s.ListAsync(status, employeeName));

    [HttpGet("{id:int}")]
    public Task<IActionResult> Get(int id) => Run(async () => Ok(await s.GetAsync(id)));

    [HttpPatch("{id:int}/approve")]
    public Task<IActionResult> Approve(int id) => Run(async () => Ok(await s.ApproveAsync(id)));

    [HttpPatch("{id:int}/reject")]
    public Task<IActionResult> Reject(int id, RejectDto? d) => Run(async () => Ok(await s.RejectAsync(id, d?.Reason)));
}

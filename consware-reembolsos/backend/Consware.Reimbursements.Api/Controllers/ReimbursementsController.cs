using Consware.Reimbursements.Api.DTOs;
using Consware.Reimbursements.Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Consware.Reimbursements.Api.Controllers;

/// <summary>
/// Expone las rutas HTTP y traduce los resultados del servicio a códigos HTTP.
/// El servicio decide; el controller solo responde: 200/201, 400, 404 y 409.
/// </summary>
[ApiController]
[Route("api/reimbursements")]
public class ReimbursementsController(IReimbursementService service) : ControllerBase
{
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateReimbursementDto dto)
    {
        try
        {
            var created = await service.CreateAsync(dto);
            return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
        }
        catch (ArgumentException e)
        {
            return BadRequest(new { message = e.Message });
        }
    }

    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] string? status, [FromQuery] string? employeeName)
    {
        try
        {
            return Ok(await service.GetAllAsync(status, employeeName));
        }
        catch (ArgumentException e)
        {
            return BadRequest(new { message = e.Message });
        }
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id)
    {
        var found = await service.GetByIdAsync(id);
        return found is null
            ? NotFound(new { message = "Solicitud no encontrada." })
            : Ok(found);
    }

    [HttpPatch("{id:int}/approve")]
    public async Task<IActionResult> Approve(int id)
    {
        try
        {
            return Ok(await service.ApproveAsync(id));
        }
        catch (KeyNotFoundException e)
        {
            return NotFound(new { message = e.Message });
        }
        catch (InvalidOperationException e)
        {
            return Conflict(new { message = e.Message });
        }
    }

    [HttpPatch("{id:int}/reject")]
    public async Task<IActionResult> Reject(int id, [FromBody] RejectReimbursementDto? dto)
    {
        try
        {
            return Ok(await service.RejectAsync(id, dto?.Reason));
        }
        catch (ArgumentException e)
        {
            return BadRequest(new { message = e.Message });
        }
        catch (KeyNotFoundException e)
        {
            return NotFound(new { message = e.Message });
        }
        catch (InvalidOperationException e)
        {
            return Conflict(new { message = e.Message });
        }
    }
}

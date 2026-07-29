using TTSmart.Api.Features.AccessManagement;
using TTSmart.Api.Features.Authorization;
using TTSmart.Api.Common.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace TTSmart.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/functions")]
[Produces("application/json")]
public sealed class FunctionsController(IFunctionAdministrationService service) : ControllerBase
{
    [Authorize(Policy = AccessPolicies.FunctionsList)]
    [HttpGet]
    [ProducesResponseType<IReadOnlyList<FunctionResponse>>(StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<FunctionResponse>>> GetList(
        [FromQuery] FunctionListQuery query,
        CancellationToken cancellationToken) =>
        Ok(await service.GetListAsync(query, cancellationToken));

    [Authorize(Policy = AccessPolicies.FunctionsList)]
    [HttpGet("tree")]
    [ProducesResponseType<IReadOnlyList<FunctionTreeNodeResponse>>(StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<FunctionTreeNodeResponse>>> GetTree(
        [FromQuery] FunctionListQuery query,
        CancellationToken cancellationToken) =>
        Ok(await service.GetTreeAsync(query, cancellationToken));

    [Authorize(Policy = AccessPolicies.FunctionsRead)]
    [HttpGet("{id:int}")]
    [ProducesResponseType<FunctionResponse>(StatusCodes.Status200OK)]
    public async Task<ActionResult<FunctionResponse>> GetById(int id, CancellationToken cancellationToken) =>
        Ok(await service.GetByIdAsync(id, cancellationToken));

    [Authorize(Policy = AccessPolicies.FunctionsCreate)]
    [HttpPost]
    [ProducesResponseType<FunctionResponse>(StatusCodes.Status201Created)]
    public async Task<ActionResult<FunctionResponse>> Create(
        [FromBody] CreateFunctionRequest request,
        CancellationToken cancellationToken)
    {
        var response = await service.CreateAsync(request, User.GetRequiredUserId(), cancellationToken);
        return CreatedAtAction(nameof(GetById), new { id = response.Id }, response);
    }

    [Authorize(Policy = AccessPolicies.FunctionsUpdate)]
    [HttpPut("{id:int}")]
    [ProducesResponseType<FunctionResponse>(StatusCodes.Status200OK)]
    public async Task<ActionResult<FunctionResponse>> Update(
        int id,
        [FromBody] UpdateFunctionRequest request,
        CancellationToken cancellationToken) =>
        Ok(await service.UpdateAsync(id, request, User.GetRequiredUserId(), cancellationToken));

    [Authorize(Policy = AccessPolicies.FunctionsUpdate)]
    [HttpPut("{id:int}/status")]
    [ProducesResponseType<FunctionResponse>(StatusCodes.Status200OK)]
    public async Task<ActionResult<FunctionResponse>> SetStatus(
        int id,
        [FromBody] SetFunctionStatusRequest request,
        CancellationToken cancellationToken) =>
        Ok(await service.SetStatusAsync(id, User.GetRequiredUserId(), request, cancellationToken));

    [Authorize(Policy = AccessPolicies.FunctionsDelete)]
    [HttpDelete("{id:int}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Delete(int id, CancellationToken cancellationToken)
    {
        await service.DeleteAsync(id, User.GetRequiredUserId(), cancellationToken);
        return NoContent();
    }
}

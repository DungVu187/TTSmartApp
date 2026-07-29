using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TTSmart.Api.Common.Models;
using TTSmart.Api.Common.Security;
using TTSmart.Api.Features.Authorization;
using TTSmart.Api.Features.BranchManagement;

namespace TTSmart.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/branches")]
[Produces("application/json")]
public sealed class BranchesController(IBranchManagementService service) : ControllerBase
{
    [Authorize(Policy = AccessPolicies.BranchesList)]
    [HttpGet]
    [ProducesResponseType<PagedResponse<BranchListItemResponse>>(StatusCodes.Status200OK)]
    public async Task<ActionResult<PagedResponse<BranchListItemResponse>>> GetPage(
        [FromQuery] BranchListQuery query,
        CancellationToken cancellationToken) =>
        Ok(await service.GetPageAsync(query, User.GetRequiredUserId(), cancellationToken));

    [Authorize(Policy = AccessPolicies.BranchesRead)]
    [HttpGet("{id:int}")]
    [ProducesResponseType<BranchResponse>(StatusCodes.Status200OK)]
    public async Task<ActionResult<BranchResponse>> GetById(int id, CancellationToken cancellationToken) =>
        Ok(await service.GetByIdAsync(id, User.GetRequiredUserId(), cancellationToken));

    [Authorize(Policy = AccessPolicies.BranchesCreate)]
    [HttpPost]
    [ProducesResponseType<BranchResponse>(StatusCodes.Status201Created)]
    public async Task<ActionResult<BranchResponse>> Create(
        [FromBody] CreateBranchRequest request,
        CancellationToken cancellationToken)
    {
        var response = await service.CreateAsync(request, User.GetRequiredUserId(), cancellationToken);
        return CreatedAtAction(nameof(GetById), new { id = response.Id }, response);
    }

    [Authorize(Policy = AccessPolicies.BranchesUpdate)]
    [HttpPut("{id:int}")]
    [ProducesResponseType<BranchResponse>(StatusCodes.Status200OK)]
    public async Task<ActionResult<BranchResponse>> Update(
        int id,
        [FromBody] UpdateBranchRequest request,
        CancellationToken cancellationToken) =>
        Ok(await service.UpdateAsync(id, request, User.GetRequiredUserId(), cancellationToken));

    [Authorize(Policy = AccessPolicies.BranchesDelete)]
    [HttpDelete("{id:int}")]
    [ProducesResponseType<BranchResponse>(StatusCodes.Status200OK)]
    public async Task<ActionResult<BranchResponse>> Delete(int id, CancellationToken cancellationToken) =>
        Ok(await service.DeleteAsync(id, User.GetRequiredUserId(), cancellationToken));

    [Authorize(Policy = AccessPolicies.BranchesUpdate)]
    [HttpPost("{id:int}/restore")]
    [ProducesResponseType<BranchResponse>(StatusCodes.Status200OK)]
    public async Task<ActionResult<BranchResponse>> Restore(int id, CancellationToken cancellationToken) =>
        Ok(await service.RestoreAsync(id, User.GetRequiredUserId(), cancellationToken));
}

using TTSmart.Api.Common.Models;
using TTSmart.Api.Common.Security;
using TTSmart.Api.Features.AccessManagement;
using TTSmart.Api.Features.Authorization;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace TTSmart.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/roles")]
[Produces("application/json")]
public sealed class RolesController(IRoleAdministrationService service) : ControllerBase
{
    [Authorize(Policy = AccessPolicies.RolesList)]
    [HttpGet]
    [ProducesResponseType<PagedResponse<RoleListItemResponse>>(StatusCodes.Status200OK)]
    public async Task<ActionResult<PagedResponse<RoleListItemResponse>>> GetPage(
        [FromQuery] RoleListQuery query,
        CancellationToken cancellationToken) =>
        Ok(await service.GetPageAsync(query, cancellationToken));

    [Authorize(Policy = AccessPolicies.RolesRead)]
    [HttpGet("{id:int}")]
    [ProducesResponseType<RoleResponse>(StatusCodes.Status200OK)]
    public async Task<ActionResult<RoleResponse>> GetById(int id, CancellationToken cancellationToken) =>
        Ok(await service.GetByIdAsync(id, cancellationToken));

    [Authorize(Policy = AccessPolicies.RolesCreate)]
    [HttpPost]
    [ProducesResponseType<RoleResponse>(StatusCodes.Status201Created)]
    public async Task<ActionResult<RoleResponse>> Create(
        [FromBody] CreateRoleRequest request,
        CancellationToken cancellationToken)
    {
        var response = await service.CreateAsync(request, User.GetRequiredUserId(), cancellationToken);
        return CreatedAtAction(nameof(GetById), new { id = response.Id }, response);
    }

    [Authorize(Policy = AccessPolicies.RolesUpdate)]
    [HttpPut("{id:int}")]
    [ProducesResponseType<RoleResponse>(StatusCodes.Status200OK)]
    public async Task<ActionResult<RoleResponse>> Update(
        int id,
        [FromBody] UpdateRoleRequest request,
        CancellationToken cancellationToken) =>
        Ok(await service.UpdateAsync(id, request, User.GetRequiredUserId(), cancellationToken));

    [Authorize(Policy = AccessPolicies.RolesUpdate)]
    [HttpPut("{id:int}/status")]
    [ProducesResponseType<RoleResponse>(StatusCodes.Status200OK)]
    public async Task<ActionResult<RoleResponse>> SetStatus(
        int id,
        [FromBody] SetRoleStatusRequest request,
        CancellationToken cancellationToken) =>
        Ok(await service.SetStatusAsync(id, User.GetRequiredUserId(), request, cancellationToken));

    [Authorize(Policy = AccessPolicies.RolesRead)]
    [HttpGet("{id:int}/function-matrix")]
    [ProducesResponseType<IReadOnlyList<RoleFunctionMatrixItemResponse>>(StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<RoleFunctionMatrixItemResponse>>> GetFunctionMatrix(
        int id,
        CancellationToken cancellationToken) =>
        Ok(await service.GetFunctionMatrixAsync(id, cancellationToken));

    [Authorize(Policy = AccessPolicies.RolesUpdate)]
    [HttpPut("{id:int}/functions")]
    [ProducesResponseType<RoleResponse>(StatusCodes.Status200OK)]
    public async Task<ActionResult<RoleResponse>> SetFunctions(
        int id,
        [FromBody] SetRoleFunctionsRequest request,
        CancellationToken cancellationToken) =>
        Ok(await service.SetFunctionsAsync(id, User.GetRequiredUserId(), request, cancellationToken));

    [Authorize(Policy = AccessPolicies.RolesUpdate)]
    [HttpPut("{id:int}/functions/{functionId:int}/active-key")]
    [ProducesResponseType<RoleResponse>(StatusCodes.Status200OK)]
    public async Task<ActionResult<RoleResponse>> SetFunctionActiveKey(
        int id,
        int functionId,
        [FromBody] SetRoleFunctionActiveKeyRequest request,
        CancellationToken cancellationToken) =>
        Ok(await service.SetFunctionActiveKeyAsync(
            id,
            functionId,
            User.GetRequiredUserId(),
            request,
            cancellationToken));

    [Authorize(Policy = AccessPolicies.RolesDelete)]
    [HttpDelete("{id:int}/functions/{functionId:int}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> RemoveFunction(
        int id,
        int functionId,
        CancellationToken cancellationToken)
    {
        await service.RemoveFunctionAsync(
            id,
            functionId,
            User.GetRequiredUserId(),
            cancellationToken);
        return NoContent();
    }

    [Authorize(Policy = AccessPolicies.RolesDelete)]
    [HttpDelete("{id:int}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Delete(int id, CancellationToken cancellationToken)
    {
        await service.DeleteAsync(id, User.GetRequiredUserId(), cancellationToken);
        return NoContent();
    }
}

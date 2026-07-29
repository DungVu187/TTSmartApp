using TTSmart.Api.Common.Models;
using TTSmart.Api.Common.Security;
using TTSmart.Api.Features.AccessManagement;
using TTSmart.Api.Features.Authorization;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace TTSmart.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/users")]
[Produces("application/json")]
public sealed class UsersController(IUserAdministrationService service) : ControllerBase
{
    [Authorize(Policy = AccessPolicies.UsersList)]
    [HttpGet]
    [ProducesResponseType<PagedResponse<UserResponse>>(StatusCodes.Status200OK)]
    public async Task<ActionResult<PagedResponse<UserResponse>>> GetPage(
        [FromQuery] UserListQuery query,
        CancellationToken cancellationToken) =>
        Ok(await service.GetPageAsync(query, User.GetRequiredUserId(), cancellationToken));

    [Authorize(Policy = AccessPolicies.UsersRead)]
    [HttpGet("{id:int}")]
    [ProducesResponseType<UserResponse>(StatusCodes.Status200OK)]
    public async Task<ActionResult<UserResponse>> GetById(int id, CancellationToken cancellationToken) =>
        Ok(await service.GetByIdAsync(id, User.GetRequiredUserId(), cancellationToken));

    [Authorize(Policy = AccessPolicies.UsersCreate)]
    [HttpPost]
    [ProducesResponseType<UserResponse>(StatusCodes.Status201Created)]
    [ProducesResponseType<ValidationProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<UserResponse>> Create(
        [FromBody] CreateUserRequest request,
        CancellationToken cancellationToken)
    {
        var response = await service.CreateAsync(request, User.GetRequiredUserId(), cancellationToken);
        return CreatedAtAction(nameof(GetById), new { id = response.Id }, response);
    }

    [Authorize(Policy = AccessPolicies.UsersUpdate)]
    [HttpPut("{id:int}")]
    [ProducesResponseType<UserResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ValidationProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<UserResponse>> Update(
        int id,
        [FromBody] UpdateUserRequest request,
        CancellationToken cancellationToken) =>
        Ok(await service.UpdateAsync(id, request, User.GetRequiredUserId(), cancellationToken));

    [Authorize(Policy = AccessPolicies.UsersUpdate)]
    [HttpPut("{id:int}/status")]
    [ProducesResponseType<UserResponse>(StatusCodes.Status200OK)]
    public async Task<ActionResult<UserResponse>> SetStatus(
        int id,
        [FromBody] SetUserStatusRequest request,
        CancellationToken cancellationToken) =>
        Ok(await service.SetStatusAsync(id, User.GetRequiredUserId(), request, cancellationToken));

    [Authorize(Policy = AccessPolicies.UsersUpdate)]
    [HttpPut("{id:int}/roles")]
    [ProducesResponseType<UserResponse>(StatusCodes.Status200OK)]
    public async Task<ActionResult<UserResponse>> SetRoles(
        int id,
        [FromBody] SetUserRolesRequest request,
        CancellationToken cancellationToken) =>
        Ok(await service.SetRolesAsync(id, User.GetRequiredUserId(), request, cancellationToken));

    [Authorize(Policy = AccessPolicies.UsersUpdate)]
    [HttpPost("{id:int}/reset-password")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> ResetPassword(
        int id,
        [FromBody] ResetPasswordRequest request,
        CancellationToken cancellationToken)
    {
        await service.ResetPasswordAsync(id, User.GetRequiredUserId(), request, cancellationToken);
        return NoContent();
    }

    [Authorize(Policy = AccessPolicies.UsersDelete)]
    [HttpDelete("{id:int}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Delete(int id, CancellationToken cancellationToken)
    {
        await service.DeleteAsync(id, User.GetRequiredUserId(), cancellationToken);
        return NoContent();
    }
}

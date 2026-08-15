using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TTSmart.Api.Common.Security;
using TTSmart.Api.Features.Dashboard;

namespace TTSmart.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/dashboard")]
[Produces("application/json")]
public sealed class DashboardController(IDashboardService service) : ControllerBase
{
    [HttpGet("scopes")]
    [ProducesResponseType<IReadOnlyList<DashboardScopeResponse>>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<IReadOnlyList<DashboardScopeResponse>>> GetScopes(
        CancellationToken cancellationToken) =>
        Ok(await service.GetScopesAsync(User.GetRequiredUserId(), cancellationToken));

    [HttpGet]
    [ProducesResponseType<DashboardResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status404NotFound)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status503ServiceUnavailable)]
    public async Task<ActionResult<DashboardResponse>> GetDashboard(
        [FromQuery] DashboardQuery query,
        CancellationToken cancellationToken) =>
        Ok(await service.GetDashboardAsync(
            query,
            User.GetRequiredUserId(),
            cancellationToken));
}

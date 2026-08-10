using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TTSmart.Api.Common.Security;
using TTSmart.Api.Features.Authorization;
using TTSmart.Api.Features.MixDesignManagement;

namespace TTSmart.Api.Controllers;

[ApiController]
[Authorize(Policy = AccessPolicies.MixDesignsList)]
[Route("api/mix-designs")]
[Produces("application/json")]
public sealed class MixDesignsController(IMixDesignService service) : ControllerBase
{
    [HttpGet("stations")]
    [ProducesResponseType<IReadOnlyList<MixDesignStationResponse>>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<IReadOnlyList<MixDesignStationResponse>>> GetStations(
        [FromQuery] MixDesignStationQuery query,
        CancellationToken cancellationToken) =>
        Ok(await service.GetStationsAsync(query, User.GetRequiredUserId(), cancellationToken));

    [HttpGet]
    [ProducesResponseType<MixDesignResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status403Forbidden)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status503ServiceUnavailable)]
    public async Task<ActionResult<MixDesignResponse>> Get(
        [FromQuery] MixDesignQuery query,
        CancellationToken cancellationToken) =>
        Ok(await service.GetAsync(query, User.GetRequiredUserId(), cancellationToken));
}

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TTSmart.Api.Common.Security;
using TTSmart.Api.Features.Authorization;
using TTSmart.Api.Features.MaterialReporting;

namespace TTSmart.Api.Controllers;

[ApiController]
[Authorize(Policy = AccessPolicies.MaterialReportsView)]
[Route("api/material-reports")]
[Produces("application/json")]
public sealed class MaterialReportsController(IMaterialReportService service) : ControllerBase
{
    [HttpGet("stations")]
    [ProducesResponseType<IReadOnlyList<MaterialReportStationResponse>>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<IReadOnlyList<MaterialReportStationResponse>>> GetStations(
        [FromQuery] MaterialReportStationQuery query,
        CancellationToken cancellationToken) =>
        Ok(await service.GetStationsAsync(query, User.GetRequiredUserId(), cancellationToken));

    [HttpGet]
    [ProducesResponseType<MaterialReportResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status403Forbidden)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status503ServiceUnavailable)]
    public async Task<ActionResult<MaterialReportResponse>> Get(
        [FromQuery] MaterialReportQuery query,
        CancellationToken cancellationToken) =>
        Ok(await service.GetAsync(query, User.GetRequiredUserId(), cancellationToken));
}

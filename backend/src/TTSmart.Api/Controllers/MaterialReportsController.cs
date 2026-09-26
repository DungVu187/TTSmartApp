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

    /// <summary>
    /// The report, or 202 with the progress while the station's mixing history is read for the
    /// first time (large stations: a few minutes, once); ask again a few seconds later.
    /// </summary>
    [HttpGet]
    [ProducesResponseType<MaterialReportResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<MaterialReportPreparingResponse>(StatusCodes.Status202Accepted)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status403Forbidden)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status503ServiceUnavailable)]
    public async Task<ActionResult<MaterialReportResponse>> Get(
        [FromQuery] MaterialReportQuery query,
        CancellationToken cancellationToken)
    {
        try
        {
            return Ok(await service.GetAsync(query, User.GetRequiredUserId(), cancellationToken));
        }
        catch (MaterialReportPreparingException preparing)
        {
            return StatusCode(
                StatusCodes.Status202Accepted,
                new MaterialReportPreparingResponse(
                    "preparing",
                    preparing.ProgressPercent,
                    "Đang tổng hợp dữ liệu tiêu hao của trạm lần đầu."));
        }
    }
}

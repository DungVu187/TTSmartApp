using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TTSmart.Api.Common.Security;
using TTSmart.Api.Features.Authorization;
using TTSmart.Api.Features.OrderStatistics;

namespace TTSmart.Api.Controllers;

[ApiController]
[Authorize(Policy = AccessPolicies.OrderStatisticsList)]
[Route("api/order-statistics")]
[Produces("application/json")]
public sealed class OrderStatisticsController(
    IOrderStatisticsService service,
    IOrderStatisticsExportService exportService)
    : ControllerBase
{
    [HttpGet("stations")]
    [ProducesResponseType<IReadOnlyList<OrderStatisticsStationResponse>>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<IReadOnlyList<OrderStatisticsStationResponse>>> GetStations(
        [FromQuery] OrderStatisticsStationQuery query,
        CancellationToken cancellationToken) =>
        Ok(await service.GetStationsAsync(query, User.GetRequiredUserId(), cancellationToken));

    [HttpGet("filters")]
    [ProducesResponseType<OrderStatisticsFilterOptionsResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status403Forbidden)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status404NotFound)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status503ServiceUnavailable)]
    public async Task<ActionResult<OrderStatisticsFilterOptionsResponse>> GetFilters(
        [FromQuery] OrderStatisticsFilterOptionsQuery query,
        CancellationToken cancellationToken) =>
        Ok(await service.GetFilterOptionsAsync(query, User.GetRequiredUserId(), cancellationToken));

    [HttpGet]
    [ProducesResponseType<OrderStatisticsResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status403Forbidden)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status404NotFound)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status503ServiceUnavailable)]
    public async Task<ActionResult<OrderStatisticsResponse>> Search(
        [FromQuery] OrderStatisticsQuery query,
        CancellationToken cancellationToken) =>
        Ok(await service.SearchAsync(query, User.GetRequiredUserId(), cancellationToken));

    [HttpGet("export")]
    [Authorize(Policy = AccessPolicies.OrderStatisticsExport)]
    [Produces(OrderStatisticsExportDefaults.ContentType)]
    [ProducesResponseType<FileContentResult>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status403Forbidden)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status404NotFound)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status503ServiceUnavailable)]
    public async Task<IActionResult> Export(
        [FromQuery] OrderStatisticsExportQuery query,
        CancellationToken cancellationToken)
    {
        var file = await exportService.ExportAsync(
            query,
            User.GetRequiredUserId(),
            cancellationToken);
        return File(file.Content, file.ContentType, file.FileName);
    }
}

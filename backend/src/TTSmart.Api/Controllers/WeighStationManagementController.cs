using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TTSmart.Api.Common.Security;
using TTSmart.Api.Features.Authorization;
using TTSmart.Api.Features.WeighStationManagement;

namespace TTSmart.Api.Controllers;

[ApiController]
[Authorize(Policy = AccessPolicies.WeighStationsList)]
[Route("api/weigh-station-management")]
[Produces("application/json")]
public sealed class WeighStationManagementController(
    IWeighStationService service,
    IWeighStationExportService exportService,
    IAuthorizationService authorizationService) : ControllerBase
{
    [HttpGet("stations")]
    [ProducesResponseType<IReadOnlyList<WeighStationStationResponse>>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<IReadOnlyList<WeighStationStationResponse>>> GetStations(
        [FromQuery] WeighStationStationQuery query,
        CancellationToken cancellationToken) =>
        Ok(await service.GetStationsAsync(query, User.GetRequiredUserId(), cancellationToken));

    [HttpGet("filters")]
    [ProducesResponseType<WeighStationFilterOptionsResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status403Forbidden)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status503ServiceUnavailable)]
    public async Task<ActionResult<WeighStationFilterOptionsResponse>> GetFilters(
        [FromQuery] WeighStationFilterOptionsQuery query,
        CancellationToken cancellationToken) =>
        Ok(await service.GetFilterOptionsAsync(query, User.GetRequiredUserId(), cancellationToken));

    [HttpGet]
    [ProducesResponseType<WeighStationResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status403Forbidden)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status503ServiceUnavailable)]
    public async Task<ActionResult<WeighStationResponse>> Search(
        [FromQuery] WeighStationQuery query,
        CancellationToken cancellationToken) =>
        Ok(await service.SearchAsync(
            query,
            User.GetRequiredUserId(),
            await CanViewMaterialValueAsync(),
            cancellationToken));

    [HttpGet("summary")]
    [ProducesResponseType<WeighStationSummaryResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status403Forbidden)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status503ServiceUnavailable)]
    public async Task<ActionResult<WeighStationSummaryResponse>> GetSummary(
        [FromQuery] WeighStationQuery query,
        CancellationToken cancellationToken) =>
        Ok(await service.GetSummaryAsync(
            query,
            User.GetRequiredUserId(),
            await CanViewMaterialValueAsync(),
            cancellationToken));

    [HttpGet("export")]
    [Authorize(Policy = AccessPolicies.WeighStationsExport)]
    [Produces(WeighStationExportDefaults.ContentType)]
    [ProducesResponseType<FileContentResult>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status403Forbidden)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status503ServiceUnavailable)]
    public async Task<IActionResult> ExportDetail(
        [FromQuery] WeighStationQuery query,
        CancellationToken cancellationToken)
    {
        var file = await exportService.ExportDetailAsync(
            query,
            User.GetRequiredUserId(),
            await CanViewMaterialValueAsync(),
            cancellationToken);
        return File(file.Content, file.ContentType, file.FileName);
    }

    [HttpGet("summary/export")]
    [Authorize(Policy = AccessPolicies.WeighStationsExport)]
    [Produces(WeighStationExportDefaults.ContentType)]
    [ProducesResponseType<FileContentResult>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status403Forbidden)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status503ServiceUnavailable)]
    public async Task<IActionResult> ExportSummary(
        [FromQuery] WeighStationQuery query,
        CancellationToken cancellationToken)
    {
        var file = await exportService.ExportSummaryAsync(
            query,
            User.GetRequiredUserId(),
            await CanViewMaterialValueAsync(),
            cancellationToken);
        return File(file.Content, file.ContentType, file.FileName);
    }

    private async Task<bool> CanViewMaterialValueAsync() =>
        (await authorizationService.AuthorizeAsync(
            User,
            AccessPolicies.WeighStationsPrice)).Succeeded;
}

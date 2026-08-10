using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TTSmart.Api.Common.Security;
using TTSmart.Api.Features.Authorization;
using TTSmart.Api.Features.OrderReporting;

namespace TTSmart.Api.Controllers;

[ApiController]
[Authorize(Policy = AccessPolicies.OrderReportsList)]
[Route("api/order-reports")]
[Produces("application/json")]
public sealed class OrderReportsController(IOrderReportService service) : ControllerBase
{
    [HttpGet("stations")]
    [ProducesResponseType<IReadOnlyList<OrderReportStationResponse>>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<IReadOnlyList<OrderReportStationResponse>>> GetStations(
        [FromQuery] OrderReportStationQuery query,
        CancellationToken cancellationToken) =>
        Ok(await service.GetStationsAsync(query, User.GetRequiredUserId(), cancellationToken));

    [HttpGet("employees")]
    [ProducesResponseType<IReadOnlyList<OrderReportEmployeeResponse>>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status403Forbidden)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status404NotFound)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status503ServiceUnavailable)]
    public async Task<ActionResult<IReadOnlyList<OrderReportEmployeeResponse>>> GetEmployees(
        [FromQuery] OrderReportEmployeeQuery query,
        CancellationToken cancellationToken) =>
        Ok(await service.GetEmployeesAsync(query, User.GetRequiredUserId(), cancellationToken));

    [HttpGet]
    [ProducesResponseType<OrderReportResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status403Forbidden)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status404NotFound)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status503ServiceUnavailable)]
    public async Task<ActionResult<OrderReportResponse>> Search(
        [FromQuery] OrderReportQuery query,
        CancellationToken cancellationToken) =>
        Ok(await service.SearchAsync(query, User.GetRequiredUserId(), cancellationToken));
}

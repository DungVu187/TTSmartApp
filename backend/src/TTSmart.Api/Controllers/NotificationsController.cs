using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TTSmart.Api.Common.Models;
using TTSmart.Api.Common.Security;
using TTSmart.Api.Features.Notifications;

namespace TTSmart.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/notifications")]
[Produces("application/json")]
public sealed class NotificationsController(INotificationService service) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<PagedResponse<NotificationResponse>>> Get(
        [FromQuery] NotificationListQuery query, CancellationToken cancellationToken) =>
        Ok(await service.GetAsync(query, User.GetRequiredUserId(), cancellationToken));

    [HttpGet("unread-count")]
    public async Task<ActionResult<UnreadNotificationCountResponse>> GetUnreadCount(CancellationToken cancellationToken) =>
        Ok(await service.GetUnreadCountAsync(User.GetRequiredUserId(), cancellationToken));

    [HttpPost("{id:long}/read")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> MarkRead(long id, CancellationToken cancellationToken)
    {
        await service.MarkReadAsync(id, User.GetRequiredUserId(), cancellationToken);
        return NoContent();
    }

    [HttpPost("read-all")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> MarkAllRead(CancellationToken cancellationToken)
    {
        await service.MarkAllReadAsync(User.GetRequiredUserId(), cancellationToken);
        return NoContent();
    }
}

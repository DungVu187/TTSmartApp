using Microsoft.EntityFrameworkCore;
using TTSmart.Api.Common.Exceptions;
using TTSmart.Api.Common.Models;
using TTSmart.Api.Data.Notifications;

namespace TTSmart.Api.Features.Notifications;

public sealed class NotificationService(NotificationDbContext dbContext, TimeProvider timeProvider) : INotificationService
{
    public async Task<PagedResponse<NotificationResponse>> GetAsync(
        NotificationListQuery query, int userId, CancellationToken cancellationToken)
    {
        var notifications = dbContext.UserNotifications.AsNoTracking()
            .Where(item => item.UserId == userId)
            .OrderByDescending(item => item.CreatedAtUtc).ThenByDescending(item => item.Id);
        var totalCount = await notifications.CountAsync(cancellationToken);
        var items = await notifications.Skip((query.PageNumber - 1) * query.PageSize).Take(query.PageSize)
            .Select(item => new NotificationResponse(
                item.Id, item.Event.EventType, item.Event.CompanyId, item.Event.StationId, item.Event.EntityType,
                item.Event.EntityId, item.Event.Title, item.Event.Body, item.Event.PayloadJson, item.Event.OccurredAtUtc,
                item.CreatedAtUtc, item.ReadAtUtc)).ToArrayAsync(cancellationToken);
        return new PagedResponse<NotificationResponse>(items, query.PageNumber, query.PageSize, totalCount,
            totalCount == 0 ? 0 : (int)Math.Ceiling(totalCount / (double)query.PageSize));
    }

    public async Task<UnreadNotificationCountResponse> GetUnreadCountAsync(int userId, CancellationToken cancellationToken) =>
        new(await dbContext.UserNotifications.CountAsync(item => item.UserId == userId && item.ReadAtUtc == null, cancellationToken));

    public async Task MarkReadAsync(long notificationId, int userId, CancellationToken cancellationToken)
    {
        var notification = await dbContext.UserNotifications.SingleOrDefaultAsync(
            item => item.Id == notificationId && item.UserId == userId, cancellationToken)
            ?? throw new NotFoundException("Không tìm thấy thông báo.");
        if (notification.ReadAtUtc is null)
        {
            notification.ReadAtUtc = timeProvider.GetUtcNow().UtcDateTime;
            await dbContext.SaveChangesAsync(cancellationToken);
        }
    }

    public async Task MarkAllReadAsync(int userId, CancellationToken cancellationToken)
    {
        var now = timeProvider.GetUtcNow().UtcDateTime;
        var notifications = await dbContext.UserNotifications
            .Where(item => item.UserId == userId && item.ReadAtUtc == null)
            .ToArrayAsync(cancellationToken);
        foreach (var notification in notifications)
        {
            notification.ReadAtUtc = now;
        }
        if (notifications.Length > 0)
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
    }
}

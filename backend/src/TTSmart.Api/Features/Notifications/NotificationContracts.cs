using System.ComponentModel.DataAnnotations;
using TTSmart.Api.Common.Models;

namespace TTSmart.Api.Features.Notifications;

public sealed class NotificationListQuery
{
    [Range(1, int.MaxValue)]
    public int PageNumber { get; init; } = 1;

    [Range(1, 100)]
    public int PageSize { get; init; } = 20;
}

public sealed record NotificationResponse(
    long Id,
    string EventType,
    int? CompanyId,
    int StationId,
    string EntityType,
    string EntityId,
    string Title,
    string Body,
    string? PayloadJson,
    DateTime OccurredAtUtc,
    DateTime CreatedAtUtc,
    DateTime? ReadAtUtc);

public sealed record UnreadNotificationCountResponse(int Count);

public interface INotificationService
{
    Task<PagedResponse<NotificationResponse>> GetAsync(NotificationListQuery query, int userId, CancellationToken cancellationToken);
    Task<UnreadNotificationCountResponse> GetUnreadCountAsync(int userId, CancellationToken cancellationToken);
    Task MarkReadAsync(long notificationId, int userId, CancellationToken cancellationToken);
    Task MarkAllReadAsync(int userId, CancellationToken cancellationToken);
}

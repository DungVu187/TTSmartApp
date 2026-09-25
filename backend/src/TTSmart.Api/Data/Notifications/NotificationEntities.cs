namespace TTSmart.Api.Data.Notifications;

public sealed class NotificationEvent
{
    public long Id { get; set; }
    public string EventType { get; set; } = string.Empty;
    public int? CompanyId { get; set; }
    public int StationId { get; set; }
    public string EntityType { get; set; } = string.Empty;
    public string EntityId { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string Body { get; set; } = string.Empty;
    public string? PayloadJson { get; set; }
    public string DeduplicationKey { get; set; } = string.Empty;
    public DateTime OccurredAtUtc { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public ICollection<UserNotification> UserNotifications { get; } = [];
}

public sealed class UserNotification
{
    public long Id { get; set; }
    public long EventId { get; set; }
    public int UserId { get; set; }
    public DateTime? ReadAtUtc { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public NotificationEvent Event { get; set; } = null!;
}

public sealed class NotificationSourceState
{
    public long Id { get; set; }
    public string DetectorType { get; set; } = string.Empty;
    public int StationId { get; set; }
    public string SourceKey { get; set; } = string.Empty;
    public string? SourceVersion { get; set; }
    public string? Fingerprint { get; set; }
    public string? PayloadJson { get; set; }
    public DateTime LastObservedAtUtc { get; set; }
    public DateTime UpdatedAtUtc { get; set; }
}

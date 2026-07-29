namespace TTSmart.Api.Common.Time;

public static class VietnamTime
{
    public static DateTime Now => DateTime.SpecifyKind(DateTime.UtcNow.AddHours(7), DateTimeKind.Unspecified);

    public static DateTime? ToStorage(DateOnly? date)
    {
        if (!date.HasValue)
        {
            return null;
        }

        return DateTime.SpecifyKind(
            date.Value.ToDateTime(TimeOnly.MinValue).AddSeconds(-1),
            DateTimeKind.Unspecified);
    }

    public static DateOnly? ToBusinessDate(DateTime? storedDate) =>
        storedDate.HasValue
            ? DateOnly.FromDateTime(storedDate.Value.AddSeconds(1))
            : null;

    public static DateTime? ToUtc(DateTime? storedDate) =>
        storedDate.HasValue
            ? DateTime.SpecifyKind(storedDate.Value.AddHours(-7), DateTimeKind.Utc)
            : null;

    public static DateTime FromUtc(DateTime utcDate) =>
        DateTime.SpecifyKind(utcDate.ToUniversalTime().AddHours(7), DateTimeKind.Unspecified);
}

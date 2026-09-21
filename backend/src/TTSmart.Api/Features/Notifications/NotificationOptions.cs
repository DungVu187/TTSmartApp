namespace TTSmart.Api.Features.Notifications;

public sealed class NotificationOptions
{
    public const string SectionName = "Notifications";
    public bool Enabled { get; init; } = true;
    public int PollingIntervalSeconds { get; init; } = 10;
    public int MaxParallelStations { get; init; } = 12;
    public int StationRosterRefreshSeconds { get; init; } = 60;
    public int StationScanTimeoutSeconds { get; init; } = 5;
    public int FailedStationInitialBackoffSeconds { get; init; } = 30;
    public int FailedStationMaxBackoffSeconds { get; init; } = 300;
    public IReadOnlyList<int> StationIds { get; init; } = [];
    public int OrderIdOverlap { get; init; } = 500;
}

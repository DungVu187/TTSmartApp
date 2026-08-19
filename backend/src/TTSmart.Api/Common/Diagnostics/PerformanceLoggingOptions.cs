namespace TTSmart.Api.Common.Diagnostics;

public sealed class PerformanceLoggingOptions
{
    public const string SectionName = "PerformanceLogging";

    public bool LogRequestStart { get; init; }

    public bool LogAllDatabaseCommands { get; init; }

    public bool LogOrderStatisticsStages { get; init; }

    public bool LogWeighStationStages { get; init; }

    public int SlowRequestThresholdMilliseconds { get; init; } = 2000;

    public int SlowDatabaseCommandThresholdMilliseconds { get; init; } = 500;
}

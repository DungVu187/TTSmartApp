using TTSmart.Api.Features.Notifications;

namespace TTSmart.Api.Tests;

public sealed class NotificationStationScheduleTests
{
    [Fact]
    public void FailureBackoffForOneStationDoesNotDelayHealthyStations()
    {
        var schedule = new NotificationStationSchedule();
        var start = new DateTimeOffset(2026, 8, 24, 8, 0, 0, TimeSpan.Zero);
        schedule.Synchronize([Station(10), Station(20)], start);

        Assert.Equal([10, 20], schedule.StartDue(start).Select(item => item.Id).ToArray());

        Assert.Equal(1, schedule.CompleteFailure(
            10,
            start,
            TimeSpan.FromSeconds(30),
            TimeSpan.FromMinutes(5)));
        schedule.CompleteSuccess(20, start, TimeSpan.FromSeconds(5));

        Assert.Equal([20], schedule.StartDue(start.AddSeconds(5)).Select(item => item.Id).ToArray());
        Assert.Empty(schedule.StartDue(start.AddSeconds(29)));
        Assert.Equal([10], schedule.StartDue(start.AddSeconds(30)).Select(item => item.Id).ToArray());
    }

    [Fact]
    public void StationCannotBeStartedAgainUntilItsPreviousScanCompletes()
    {
        var schedule = new NotificationStationSchedule();
        var start = new DateTimeOffset(2026, 8, 24, 8, 0, 0, TimeSpan.Zero);
        schedule.Synchronize([Station(10)], start);

        Assert.Single(schedule.StartDue(start));
        Assert.Empty(schedule.StartDue(start.AddMinutes(1)));

        schedule.CompleteSuccess(10, start.AddMinutes(1), TimeSpan.FromSeconds(5));
        Assert.Single(schedule.StartDue(start.AddMinutes(1).AddSeconds(5)));
    }

    private static NotificationStation Station(int id) => new(id, 1, $"Station {id}", "unused", 1);
}

using TTSmart.Api.Data.StationOperations;
using TTSmart.Api.Features.MaterialReporting;

namespace TTSmart.Api.Tests;

internal sealed class TestMaterialReportDataSource : IMaterialReportDataSource
{
    private MaterialReportSnapshot snapshot = Empty();

    public int CallCount { get; private set; }
    public List<StationDatabaseTarget> SeenTargets { get; } = [];
    public List<(DateTime From, DateTime To)> SeenRanges { get; } = [];

    public void SetSnapshot(MaterialReportSnapshot value) => snapshot = value;

    public void Reset()
    {
        snapshot = Empty();
        CallCount = 0;
        SeenTargets.Clear();
        SeenRanges.Clear();
    }

    public Task<MaterialReportSnapshot> LoadAsync(
        StationDatabaseTarget target,
        DateTime fromLocal,
        DateTime toLocal,
        CancellationToken cancellationToken)
    {
        CallCount++;
        SeenTargets.Add(target);
        SeenRanges.Add((fromLocal, toLocal));
        return Task.FromResult(snapshot);
    }

    private static MaterialReportSnapshot Empty() => new([], [], [], [], []);
}

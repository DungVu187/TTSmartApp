using TTSmart.Api.Common.Exceptions;
using TTSmart.Api.Data.StationOperations;
using TTSmart.Api.Features.WeighStationManagement;

namespace TTSmart.Api.Tests;

internal sealed class TestWeighStationDataSource : IWeighStationDataSource
{
    private WeighStationFilterOptions filterOptions = new([], [], [], [], []);
    private WeighStationPage page = new([], 0);
    private IReadOnlyList<WeighStationRow> allRows = [];
    private IReadOnlyList<WeighStationSummaryAggregate> summary = [];
    private bool unavailable;

    public List<StationDatabaseTarget> SeenTargets { get; } = [];
    public List<WeighStationStage?> SeenStages { get; } = [];
    public List<WeighStationFilter> SeenFilters { get; } = [];
    public List<int> SeenPageOffsets { get; } = [];
    public int FilterCallCount { get; private set; }
    public int SearchCallCount { get; private set; }
    public int SearchAllCallCount { get; private set; }
    public int SummaryCallCount { get; private set; }

    public void Reset()
    {
        filterOptions = new([], [], [], [], []);
        page = new([], 0);
        allRows = [];
        summary = [];
        unavailable = false;
        SeenTargets.Clear();
        SeenStages.Clear();
        SeenFilters.Clear();
        SeenPageOffsets.Clear();
        FilterCallCount = 0;
        SearchCallCount = 0;
        SearchAllCallCount = 0;
        SummaryCallCount = 0;
    }

    public void SetFilterOptions(WeighStationFilterOptions value) => filterOptions = value;

    public void SetPage(WeighStationPage value) => page = value;

    public void SetAllRows(IReadOnlyList<WeighStationRow> value) => allRows = value;

    public void SetSummary(IReadOnlyList<WeighStationSummaryAggregate> value) => summary = value;

    public void SetUnavailable() => unavailable = true;

    public Task<WeighStationFilterOptions> GetFilterOptionsAsync(
        StationDatabaseTarget target,
        WeighStationStage? stage,
        WeighStationFilter filter,
        CancellationToken cancellationToken)
    {
        FilterCallCount++;
        Record(target, stage, filter);
        EnsureAvailable();
        return Task.FromResult(filterOptions);
    }

    public Task<WeighStationPage> SearchAsync(
        StationDatabaseTarget target,
        WeighStationStage? stage,
        WeighStationFilter filter,
        int pageOffset,
        CancellationToken cancellationToken)
    {
        SearchCallCount++;
        Record(target, stage, filter);
        SeenPageOffsets.Add(pageOffset);
        EnsureAvailable();
        return Task.FromResult(page);
    }

    public Task<IReadOnlyList<WeighStationRow>> SearchAllAsync(
        StationDatabaseTarget target,
        WeighStationStage? stage,
        WeighStationFilter filter,
        CancellationToken cancellationToken)
    {
        SearchAllCallCount++;
        Record(target, stage, filter);
        EnsureAvailable();
        return Task.FromResult(allRows);
    }

    public Task<IReadOnlyList<WeighStationSummaryAggregate>> GetSummaryAsync(
        StationDatabaseTarget target,
        WeighStationStage? stage,
        WeighStationFilter filter,
        CancellationToken cancellationToken)
    {
        SummaryCallCount++;
        Record(target, stage, filter);
        EnsureAvailable();
        return Task.FromResult(summary);
    }

    private void Record(
        StationDatabaseTarget target,
        WeighStationStage? stage,
        WeighStationFilter filter)
    {
        SeenTargets.Add(target);
        SeenStages.Add(stage);
        SeenFilters.Add(filter);
    }

    private void EnsureAvailable()
    {
        if (!unavailable)
        {
            return;
        }

        throw new ServiceUnavailableException(
            "Dữ liệu trạm cân chưa sẵn sàng",
            new InvalidOperationException(
                "SqlException Server=internal;Database=WEIGH;SensitiveDetail=should-not-leak"));
    }
}

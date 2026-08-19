using TTSmart.Api.Data.StationOperations;
using TTSmart.Api.Features.WeighStationManagement;

namespace TTSmart.Api.Tests;

internal sealed class TestWeighStationMaterialValueDataSource
    : IWeighStationMaterialValueDataSource
{
    private WeighStationMaterialValues values = WeighStationMaterialValues.Empty;
    private Exception? exception;

    public int CallCount { get; private set; }
    public IReadOnlyList<WeighStationRow> LastScaleRows { get; private set; } = [];

    public void SetValues(IReadOnlyDictionary<int, decimal> value) =>
        values = new WeighStationMaterialValues(value);

    public void SetException(Exception value) => exception = value;

    public void Reset()
    {
        values = WeighStationMaterialValues.Empty;
        exception = null;
        CallCount = 0;
        LastScaleRows = [];
    }

    public Task<WeighStationMaterialValues> CalculateAsync(
        StationDatabaseTarget scaleTarget,
        IReadOnlyList<StationDatabaseTarget> mixingTargets,
        IReadOnlyList<WeighStationRow> scaleRows,
        CancellationToken cancellationToken)
    {
        CallCount++;
        LastScaleRows = scaleRows;
        if (exception is not null)
        {
            return Task.FromException<WeighStationMaterialValues>(exception);
        }
        return Task.FromResult(values);
    }
}

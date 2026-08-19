namespace TTSmart.Api.Features.WeighStationManagement;

public sealed class WeighStationMaterialValueOptions
{
    public const string SectionName = "WeighStationManagement";

    public int MaterialValueTimeoutMilliseconds { get; init; } = 3000;
}

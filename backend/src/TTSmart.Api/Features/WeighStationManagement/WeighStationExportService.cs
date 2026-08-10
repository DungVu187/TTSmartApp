namespace TTSmart.Api.Features.WeighStationManagement;

public static class WeighStationExportDefaults
{
    public const string ContentType =
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
    public const string DetailFileName = "quan-ly-can-o-to.xlsx";
    public const string SummaryFileName = "tong-hop-can-o-to.xlsx";
}

public sealed record WeighStationExportFile(
    byte[] Content,
    string ContentType,
    string FileName);

public interface IWeighStationExportService
{
    Task<WeighStationExportFile> ExportDetailAsync(
        WeighStationQuery query,
        int currentUserId,
        bool canViewMaterialValue,
        CancellationToken cancellationToken);

    Task<WeighStationExportFile> ExportSummaryAsync(
        WeighStationQuery query,
        int currentUserId,
        bool canViewMaterialValue,
        CancellationToken cancellationToken);
}

public sealed class WeighStationExportService(IWeighStationService service)
    : IWeighStationExportService
{
    public async Task<WeighStationExportFile> ExportDetailAsync(
        WeighStationQuery query,
        int currentUserId,
        bool canViewMaterialValue,
        CancellationToken cancellationToken)
    {
        var response = await service.SearchAllAsync(
            query,
            currentUserId,
            canViewMaterialValue,
            cancellationToken);
        return new WeighStationExportFile(
            WeighStationXlsxWriter.CreateDetail(response),
            WeighStationExportDefaults.ContentType,
            WeighStationExportDefaults.DetailFileName);
    }

    public async Task<WeighStationExportFile> ExportSummaryAsync(
        WeighStationQuery query,
        int currentUserId,
        bool canViewMaterialValue,
        CancellationToken cancellationToken)
    {
        var response = await service.GetSummaryAllAsync(
            query,
            currentUserId,
            canViewMaterialValue,
            cancellationToken);
        return new WeighStationExportFile(
            WeighStationXlsxWriter.CreateSummary(response),
            WeighStationExportDefaults.ContentType,
            WeighStationExportDefaults.SummaryFileName);
    }
}

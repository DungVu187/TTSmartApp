namespace TTSmart.Api.Features.MaterialReporting;

public interface IMaterialReportService
{
    Task<IReadOnlyList<MaterialReportStationResponse>> GetStationsAsync(
        MaterialReportStationQuery query,
        int currentUserId,
        CancellationToken cancellationToken);

    Task<MaterialReportResponse> GetAsync(
        MaterialReportQuery query,
        int currentUserId,
        CancellationToken cancellationToken);
}

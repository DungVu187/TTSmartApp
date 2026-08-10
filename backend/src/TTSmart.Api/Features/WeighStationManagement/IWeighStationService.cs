namespace TTSmart.Api.Features.WeighStationManagement;

public interface IWeighStationService
{
    Task<IReadOnlyList<WeighStationStationResponse>> GetStationsAsync(
        WeighStationStationQuery query,
        int currentUserId,
        CancellationToken cancellationToken);

    Task<WeighStationFilterOptionsResponse> GetFilterOptionsAsync(
        WeighStationFilterOptionsQuery query,
        int currentUserId,
        CancellationToken cancellationToken);

    Task<WeighStationResponse> SearchAsync(
        WeighStationQuery query,
        int currentUserId,
        bool canViewMaterialValue,
        CancellationToken cancellationToken);

    Task<WeighStationResponse> SearchAllAsync(
        WeighStationQuery query,
        int currentUserId,
        bool canViewMaterialValue,
        CancellationToken cancellationToken);

    Task<WeighStationSummaryResponse> GetSummaryAsync(
        WeighStationQuery query,
        int currentUserId,
        bool canViewMaterialValue,
        CancellationToken cancellationToken);

    Task<WeighStationSummaryResponse> GetSummaryAllAsync(
        WeighStationQuery query,
        int currentUserId,
        bool canViewMaterialValue,
        CancellationToken cancellationToken);
}

namespace TTSmart.Api.Features.MixDesignManagement;

public interface IMixDesignService
{
    Task<IReadOnlyList<MixDesignStationResponse>> GetStationsAsync(
        MixDesignStationQuery query,
        int currentUserId,
        CancellationToken cancellationToken);

    Task<MixDesignResponse> GetAsync(
        MixDesignQuery query,
        int currentUserId,
        CancellationToken cancellationToken);
}

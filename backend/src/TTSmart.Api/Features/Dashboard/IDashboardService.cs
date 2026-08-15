namespace TTSmart.Api.Features.Dashboard;

public interface IDashboardService
{
    Task<IReadOnlyList<DashboardScopeResponse>> GetScopesAsync(
        int currentUserId,
        CancellationToken cancellationToken);

    Task<DashboardResponse> GetDashboardAsync(
        DashboardQuery query,
        int currentUserId,
        CancellationToken cancellationToken);
}

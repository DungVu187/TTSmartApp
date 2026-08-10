using TTSmart.Api.Data.StationOperations;

namespace TTSmart.Api.Tests;

internal sealed class TestStationDatabaseAvailabilityResolver
    : IStationDatabaseAvailabilityResolver
{
    private readonly HashSet<int> unavailableBranchIds = [];

    public void Reset() => unavailableBranchIds.Clear();

    public void SetUnavailable(int branchId) => unavailableBranchIds.Add(branchId);

    public Task<StationDatabaseAvailabilityResult> ResolveAsync(
        IReadOnlyList<StationDatabaseTarget> targets,
        CancellationToken cancellationToken)
    {
        var available = targets
            .Select(target => target.BranchId)
            .Where(branchId => !unavailableBranchIds.Contains(branchId))
            .ToHashSet();
        var unavailable = targets
            .Select(target => target.BranchId)
            .Where(unavailableBranchIds.Contains)
            .ToHashSet();
        return Task.FromResult(new StationDatabaseAvailabilityResult(
            available,
            unavailable));
    }
}
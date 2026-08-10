using TTSmart.Api.Common.Exceptions;
using TTSmart.Api.Data.StationOperations;
using TTSmart.Api.Features.MixDesignManagement;

namespace TTSmart.Api.Tests;

internal sealed class TestMixDesignDataSource : IMixDesignDataSource
{
    private MixDesignPage page = EmptyPage();
    private bool unavailable;

    public List<StationDatabaseTarget> SeenTargets { get; } = [];
    public List<int> SeenPageNumbers { get; } = [];
    public int CallCount { get; private set; }

    public void Reset()
    {
        page = EmptyPage();
        unavailable = false;
        SeenTargets.Clear();
        SeenPageNumbers.Clear();
        CallCount = 0;
    }

    public void SetPage(MixDesignPage value) => page = value;

    public void SetUnavailable() => unavailable = true;

    public Task<MixDesignPage> GetPageAsync(
        StationDatabaseTarget target,
        int pageNumber,
        CancellationToken cancellationToken)
    {
        CallCount++;
        SeenTargets.Add(target);
        SeenPageNumbers.Add(pageNumber);
        if (unavailable)
        {
            throw new ServiceUnavailableException(
                "Dữ liệu trạm chưa sẵn sàng",
                new InvalidOperationException(
                    "SqlException Server=internal;Database=TRAM_online;SensitiveDetail=should-not-leak"));
        }

        return Task.FromResult(page with { PageNumber = pageNumber });
    }

    private static MixDesignPage EmptyPage() =>
        new([], 1, MixDesignContractDefaults.PageSize, 0, []);
}

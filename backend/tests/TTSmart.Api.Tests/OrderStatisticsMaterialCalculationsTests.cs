using TTSmart.Api.Features.OrderStatistics;

namespace TTSmart.Api.Tests;

public sealed class OrderStatisticsMaterialCalculationsTests
{
    [Fact]
    public void CalculateVariance_CongLuongTTheoCongThucWebsite()
    {
        var result = OrderStatisticsMaterialCalculations.CalculateVariance(
            designQuantity: 100,
            tQuantity: 5,
            actualQuantity: 97);

        Assert.Equal(2d, result);
    }
}

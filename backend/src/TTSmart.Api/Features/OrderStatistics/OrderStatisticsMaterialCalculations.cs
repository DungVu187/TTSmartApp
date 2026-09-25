namespace TTSmart.Api.Features.OrderStatistics;

internal static class OrderStatisticsMaterialCalculations
{
    public static double CalculateVariance(
        double designQuantity,
        double tQuantity,
        double actualQuantity) =>
        actualQuantity + tQuantity - designQuantity;
}

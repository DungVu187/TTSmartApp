namespace TTSmart.Api.Data.StationOperations;

public sealed class StationCompletedWeighTicket
{
    public int Sequence { get; set; }
    public Guid Id { get; set; }
    public string? TicketCode { get; set; }
    public string? VehiclePlate { get; set; }
    public string? DriverName { get; set; }
    public string? SealNumber { get; set; }
    public double? FirstWeight { get; set; }
    public double? SecondWeight { get; set; }
    public decimal? GoodsWeight { get; set; }
    public float? ConversionFactor { get; set; }
    public string? ConversionUnit { get; set; }
    public string? UnitName { get; set; }
    public string? GoodsName { get; set; }
    public string? WeighingType { get; set; }
    public string? FirstOperatorName { get; set; }
    public string? SecondOperatorName { get; set; }
    public DateTime? FirstWeighedAt { get; set; }
    public DateTime? SecondWeighedAt { get; set; }
    public DateTime? LastUpdatedAt { get; set; }
}

public sealed class StationPendingWeighTicket
{
    public int Sequence { get; set; }
    public Guid Id { get; set; }
    public string? TicketCode { get; set; }
    public string? VehiclePlate { get; set; }
    public string? DriverName { get; set; }
    public string? SealNumber { get; set; }
    public double? FirstWeight { get; set; }
    public double? SecondWeight { get; set; }
    public decimal? GoodsWeight { get; set; }
    public float? ConversionFactor { get; set; }
    public string? ConversionUnit { get; set; }
    public string? UnitName { get; set; }
    public string? GoodsName { get; set; }
    public string? WeighingType { get; set; }
    public string? FirstOperatorName { get; set; }
    public string? SecondOperatorName { get; set; }
    public DateTime? FirstWeighedAt { get; set; }
    public DateTime? SecondWeighedAt { get; set; }
    public DateTime? LastUpdatedAt { get; set; }
}

namespace TTSmart.Api.Data.StationOperations;

public sealed class StationOrder
{
    public int OrderId { get; set; }
    public int? CustomerId { get; set; }
    public int? EmployeeId { get; set; }
    public int? ProjectId { get; set; }
    public float? OrderedVolume { get; set; }
    public DateTime? OrderedAt { get; set; }
    public float? ProducedVolume { get; set; }
    public int? ConcreteGradeId { get; set; }
}

public sealed class StationCustomer
{
    public int CustomerId { get; set; }
    public string? Name { get; set; }
}

public sealed class StationProject
{
    public int ProjectId { get; set; }
    public string? Name { get; set; }
}

public sealed class StationConcreteGrade
{
    public int ConcreteGradeId { get; set; }
    public string? Name { get; set; }
    public int? Strength { get; set; }
    public int? MaximumAggregateSize { get; set; }
    public string? Slump { get; set; }
}

public sealed class StationEmployee
{
    public int EmployeeId { get; set; }
    public string? Name { get; set; }
}

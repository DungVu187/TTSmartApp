using System.ComponentModel.DataAnnotations;

namespace TTSmart.Api.Features.MixDesignManagement;

public static class MixDesignContractDefaults
{
    public const int DefaultPageNumber = 1;
    public const int PageSize = 10;
}

public sealed class MixDesignStationQuery
{
    [Range(1, int.MaxValue)]
    public int? CompanyId { get; init; }
}

public sealed record MixDesignStationResponse(
    int StationId,
    string? StationName);

public sealed class MixDesignQuery
{
    [Range(1, int.MaxValue)]
    public int? CompanyId { get; init; }

    [Range(1, int.MaxValue)]
    public int? StationId { get; init; }

    public int PageNumber { get; init; } = MixDesignContractDefaults.DefaultPageNumber;
}

public sealed record MixDesignMaterialColumnResponse(
    int MaterialSlotId,
    int SlotNumber,
    string MaterialName,
    string Category,
    string CategoryCode,
    int TypePosition,
    string ColumnKey);

public sealed record MixDesignMaterialResponse(
    int MaterialSlotId,
    int SlotNumber,
    string ColumnKey,
    decimal Quantity);

public sealed record MixDesignItemResponse(
    int Stt,
    string? ConcreteGradeName,
    int Strength,
    int MaxAggregate,
    string Slump,
    decimal Sand1,
    decimal Sand2,
    decimal Stone1,
    decimal Stone2,
    decimal Stone3,
    decimal Cement1,
    decimal Cement2,
    decimal Cement3,
    decimal Cement4,
    decimal Water,
    decimal Sika,
    decimal Tulog,
    decimal Sikaroad,
    decimal Bifi)
{
    public IReadOnlyList<MixDesignMaterialResponse> Materials { get; init; } = [];
}

public sealed record MixDesignResponse(
    IReadOnlyList<MixDesignItemResponse> Items,
    int PageNumber,
    int PageSize,
    int TotalCount,
    int TotalPages)
{
    public IReadOnlyList<MixDesignMaterialColumnResponse> MaterialColumns { get; init; } = [];
}

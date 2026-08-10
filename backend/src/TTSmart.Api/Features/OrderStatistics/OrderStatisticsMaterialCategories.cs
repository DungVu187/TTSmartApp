using System.Globalization;
using System.Text;

namespace TTSmart.Api.Features.OrderStatistics;

internal static class OrderStatisticsMaterialCategories
{
    public const string Sand = "CAT";
    public const string Stone = "DA";
    public const string Cement = "XIMANG";
    public const string Water = "NUOC";
    public const string Additive = "PHUGIA";
    public const string Unknown = "UNKNOWN";

    public static IReadOnlyList<string> StandardCodes { get; } =
        [Sand, Stone, Cement, Water, Additive];

    public static string NormalizeCurrent(int? materialTypeId, string? materialTypeName) =>
        materialTypeId switch
        {
            1 => Sand,
            2 => Stone,
            3 => Cement,
            4 => Water,
            5 => Additive,
            _ => NormalizeValue(materialTypeName)
        };

    public static string NormalizeHistorical(string? materialTypeName) =>
        NormalizeValue(materialTypeName);

    public static string Normalize(
        string? sourceCategoryCode,
        string? category,
        string? materialName)
    {
        foreach (var value in new[] { sourceCategoryCode, category, materialName })
        {
            var categoryCode = NormalizeValue(value);
            if (categoryCode != Unknown)
            {
                return categoryCode;
            }
        }

        return Unknown;
    }

    public static string DisplayName(string categoryCode) =>
        categoryCode switch
        {
            Sand => "Cát",
            Stone => "Đá",
            Cement => "Xi măng",
            Water => "Nước",
            Additive => "Phụ gia",
            _ => "Khác"
        };

    public static int SortOrder(string categoryCode) =>
        categoryCode switch
        {
            Sand => 1,
            Stone => 2,
            Cement => 3,
            Water => 4,
            Additive => 5,
            _ => int.MaxValue
        };

    public static string Unit(string categoryCode) =>
        categoryCode == Water ? "LÍT" : "KG";

    private static string NormalizeValue(string? materialTypeName)
    {
        var token = NormalizeToken(materialTypeName);
        if (token is "1")
        {
            return Sand;
        }

        if (token is "2")
        {
            return Stone;
        }

        if (token is "3")
        {
            return Cement;
        }

        if (token is "4")
        {
            return Water;
        }

        if (token is "5")
        {
            return Additive;
        }

        if (token.StartsWith(Sand, StringComparison.Ordinal))
        {
            return Sand;
        }

        if (token.StartsWith(Stone, StringComparison.Ordinal) ||
            token.Contains("STONE", StringComparison.Ordinal) ||
            token.Contains("AGGREGATE", StringComparison.Ordinal))
        {
            return Stone;
        }

        if (token.StartsWith(Cement, StringComparison.Ordinal) ||
            token.StartsWith("XI", StringComparison.Ordinal) ||
            token.Contains("CEMENT", StringComparison.Ordinal))
        {
            return Cement;
        }

        if (token.StartsWith(Water, StringComparison.Ordinal) ||
            token.Contains("WATER", StringComparison.Ordinal))
        {
            return Water;
        }

        if (token.StartsWith(Additive, StringComparison.Ordinal) ||
            token.StartsWith("PG", StringComparison.Ordinal) ||
            token.Contains("ADDITIVE", StringComparison.Ordinal) ||
            token.Contains("ADMIXTURE", StringComparison.Ordinal))
        {
            return Additive;
        }

        return Unknown;
    }

    private static string NormalizeToken(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return string.Empty;
        }

        var normalized = value.Trim().Normalize(NormalizationForm.FormD);
        var builder = new StringBuilder(normalized.Length);
        foreach (var character in normalized)
        {
            if (character is 'Đ' or 'đ')
            {
                builder.Append('D');
                continue;
            }

            if (CharUnicodeInfo.GetUnicodeCategory(character) == UnicodeCategory.NonSpacingMark)
            {
                continue;
            }

            if (char.IsLetterOrDigit(character))
            {
                builder.Append(char.ToUpperInvariant(character));
            }
        }

        return builder.ToString();
    }
}

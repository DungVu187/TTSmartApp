using System.Globalization;
using System.Text;

namespace TTSmart.Api.Features.MixDesignManagement;

internal static class MixDesignMaterialCategories
{
    public const string Sand = "CAT";
    public const string Stone = "DA";
    public const string Cement = "XIMANG";
    public const string Water = "NUOC";
    public const string Additive = "PHUGIA";
    public const string Unknown = "UNKNOWN";

    public static string Normalize(int? materialTypeId, string? materialTypeName) =>
        materialTypeId switch
        {
            1 => Sand,
            2 => Stone,
            3 => Cement,
            4 => Water,
            5 => Additive,
            _ => NormalizeName(materialTypeName)
        };

    public static string DisplayName(string categoryCode) =>
        categoryCode switch
        {
            Sand => "C\u00e1t",
            Stone => "\u0110\u00e1",
            Cement => "Xi m\u0103ng",
            Water => "N\u01b0\u1edbc",
            Additive => "Ph\u1ee5 gia",
            _ => "Kh\u00e1c"
        };

    private static string NormalizeName(string? materialTypeName)
    {
        var token = NormalizeToken(materialTypeName);
        if (token.StartsWith(Sand, StringComparison.Ordinal))
        {
            return Sand;
        }

        if (token.StartsWith(Stone, StringComparison.Ordinal))
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
            token.Contains("ADDITIVE", StringComparison.Ordinal))
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
            if (character is '\u0110' or '\u0111')
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

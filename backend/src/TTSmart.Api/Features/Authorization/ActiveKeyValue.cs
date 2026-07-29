namespace TTSmart.Api.Features.Authorization;

public static class ActiveKeyValue
{
    public const int Length = 9;
    public const string None = "000000000";
    public const string Full = "111111111";

    public static bool IsValid(string? value) =>
        value is { Length: Length } && value.All(character => character is '0' or '1');

    public static bool HasAnyPermission(string? value) =>
        IsValid(value) && value!.Contains('1');

    public static bool IsFull(string? value) => value == Full;

    public static string Normalize(string? value) => IsValid(value) ? value! : None;

    public static bool Allows(string? value, ActiveKeyPermission permission) =>
        IsValid(value) && value![(int)permission] == '1';

    public static string Set(string value, ActiveKeyPermission permission, bool enabled)
    {
        if (!IsValid(value))
        {
            throw new ArgumentException("ActiveKey phải gồm đúng 9 ký tự 0 hoặc 1.", nameof(value));
        }

        var characters = value.ToCharArray();
        characters[(int)permission] = enabled ? '1' : '0';
        return new string(characters);
    }

    public static string Merge(IEnumerable<string?> values)
    {
        var merged = None.ToCharArray();
        foreach (var value in values.Where(IsValid))
        {
            for (var index = 0; index < Length; index++)
            {
                if (value![index] == '1')
                {
                    merged[index] = '1';
                }
            }
        }

        return new string(merged);
    }
}

public enum ActiveKeyPermission
{
    View = 0,
    Create = 1,
    Update = 2,
    Delete = 3,
    Import = 4,
    Export = 5,
    Print = 6,
    Other = 7,
    DSach = 8
}

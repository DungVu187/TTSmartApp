namespace TTSmart.Api.Features.Auth;

public sealed class DatabasePasswordOptions
{
    public const string SectionName = "AuthDatabase";
    public DatabasePasswordWriteMode PasswordWriteMode { get; init; } = DatabasePasswordWriteMode.Md5Utf8;
}

public enum DatabasePasswordWriteMode
{
    Md5Utf8,
    Md5Unicode
}

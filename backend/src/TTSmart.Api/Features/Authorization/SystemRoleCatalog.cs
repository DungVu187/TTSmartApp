using Microsoft.Extensions.Options;

namespace TTSmart.Api.Features.Authorization;

/// <summary>
/// Khai báo vai trò hệ thống theo từng môi trường. Mỗi DB có thể dùng RoleId khác nhau
/// (dev: ADMIN=1, CONGTY=3) và có thể phát sinh mã mới (prod đang dùng CONGTY2.0),
/// nên danh sách được đọc từ cấu hình thay vì cố định trong code.
/// </summary>
public sealed class SystemRoleOptions
{
    public const string SectionName = "SystemRoles";

    public int[] AdminRoleIds { get; set; } = [];

    public string[] AdminRoleCodes { get; set; } = [];

    public int[] CompanyRoleIds { get; set; } = [];

    public string[] CompanyRoleCodes { get; set; } = [];
}

public interface ISystemRoleCatalog
{
    int[] AdminRoleIds { get; }

    string[] AdminRoleCodes { get; }

    int[] CompanyRoleIds { get; }

    string[] CompanyRoleCodes { get; }

    /// <summary>ADMIN hợp với CONGTY — các vai trò không được tài khoản công ty tự gán hay tự xóa.</summary>
    int[] PrivilegedRoleIds { get; }

    string[] PrivilegedRoleCodes { get; }

    bool IsAdmin(int roleId, string? roleCode);

    bool IsCompany(int roleId, string? roleCode);

    bool IsPrivileged(int roleId, string? roleCode);
}

public sealed class SystemRoleCatalog(IOptions<SystemRoleOptions> options) : ISystemRoleCatalog
{
    /// <summary>Dùng cho các đường gọi chưa có DI (test, khởi tạo trực tiếp).</summary>
    public static readonly ISystemRoleCatalog Default =
        new SystemRoleCatalog(Options.Create(new SystemRoleOptions()));

    private readonly SystemRoleOptions _options = options.Value;

    public int[] AdminRoleIds => Distinct(_options.AdminRoleIds);

    public string[] AdminRoleCodes => Fallback(_options.AdminRoleCodes, SystemRoleCodes.Admin);

    public int[] CompanyRoleIds => Distinct(_options.CompanyRoleIds);

    public string[] CompanyRoleCodes => Fallback(_options.CompanyRoleCodes, SystemRoleCodes.Company);

    public int[] PrivilegedRoleIds => [.. AdminRoleIds.Concat(CompanyRoleIds).Distinct()];

    public string[] PrivilegedRoleCodes =>
        [.. AdminRoleCodes.Concat(CompanyRoleCodes).Distinct(StringComparer.OrdinalIgnoreCase)];

    public bool IsAdmin(int roleId, string? roleCode) =>
        Matches(roleId, roleCode, AdminRoleIds, AdminRoleCodes);

    public bool IsCompany(int roleId, string? roleCode) =>
        Matches(roleId, roleCode, CompanyRoleIds, CompanyRoleCodes);

    public bool IsPrivileged(int roleId, string? roleCode) =>
        IsAdmin(roleId, roleCode) || IsCompany(roleId, roleCode);

    private static bool Matches(int roleId, string? roleCode, int[] roleIds, string[] roleCodes) =>
        roleIds.Contains(roleId) ||
        (roleCode is not null && roleCodes.Contains(roleCode, StringComparer.OrdinalIgnoreCase));

    private static int[] Distinct(int[]? values) =>
        values is null ? [] : [.. values.Where(value => value > 0).Distinct()];

    private static string[] Fallback(string[]? values, string defaultCode)
    {
        var configured = (values ?? [])
            .Select(value => value?.Trim())
            .Where(value => !string.IsNullOrEmpty(value))
            .Select(value => value!)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();
        return configured.Length == 0 ? [defaultCode] : configured;
    }
}

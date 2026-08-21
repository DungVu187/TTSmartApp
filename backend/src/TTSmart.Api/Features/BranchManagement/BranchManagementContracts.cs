using System.ComponentModel.DataAnnotations;

namespace TTSmart.Api.Features.BranchManagement;

public sealed class BranchListQuery
{
    [Range(1, int.MaxValue)]
    public int PageNumber { get; init; } = 1;

    [Range(1, 100)]
    public int PageSize { get; init; } = 10;

    [StringLength(100)]
    public string? Search { get; init; }

    public int? CompanyId { get; init; }
    public int? TypeTram { get; init; }
    public byte? Status { get; init; }
}

public sealed record BranchListItemResponse(
    int Id,
    string? Name,
    string? Phone,
    int? TypeTram);

public sealed record BranchResponse(
    int Id,
    int? CompanyId,
    string? CompanyName,
    string? Code,
    string? Name,
    string? Email,
    string? Phone,
    string? Address,
    int? TypeTram,
    string? Username,
    string Password,
    string? PMQLXe,
    string? QLCamera,
    byte Status,
    bool IsActive,
    DateTime? CreatedAtUtc,
    DateTime? UpdatedAtUtc);

public sealed class CreateBranchRequest
{
    [Required(ErrorMessage = "Công ty là bắt buộc.")]
    public int? CompanyId { get; init; }

    [Required(ErrorMessage = "Mã trạm là bắt buộc.")]
    [StringLength(100, ErrorMessage = "Mã trạm không được vượt quá 100 ký tự.")]
    public string Code { get; init; } = string.Empty;

    [Required(ErrorMessage = "Tên trạm là bắt buộc.")]
    [StringLength(1000, ErrorMessage = "Tên trạm không được vượt quá 1000 ký tự.")]
    public string Name { get; init; } = string.Empty;

    [Required(ErrorMessage = "Email là bắt buộc.")]
    [EmailAddress(ErrorMessage = "Email không hợp lệ.")]
    [StringLength(1000, ErrorMessage = "Email không được vượt quá 1000 ký tự.")]
    public string Email { get; init; } = string.Empty;

    [Required(ErrorMessage = "Số điện thoại là bắt buộc.")]
    [StringLength(100, ErrorMessage = "Số điện thoại không được vượt quá 100 ký tự.")]
    public string Phone { get; init; } = string.Empty;

    [StringLength(1000, ErrorMessage = "Địa chỉ không được vượt quá 1000 ký tự.")]
    public string? Address { get; init; }

    [Required(ErrorMessage = "Tài khoản là bắt buộc.")]
    [StringLength(1000, ErrorMessage = "Tài khoản không được vượt quá 1000 ký tự.")]
    public string Username { get; init; } = string.Empty;

    [Required(ErrorMessage = "Mật khẩu là bắt buộc.")]
    [StringLength(1000, MinimumLength = 4, ErrorMessage = "Mật khẩu phải có từ 4 đến 1000 ký tự.")]
    public string Password { get; init; } = string.Empty;

    [StringLength(1000, ErrorMessage = "Phần mềm quản lý xe không được vượt quá 1000 ký tự.")]
    public string? PMQLXe { get; init; }

    [StringLength(1000, ErrorMessage = "Phần mềm quản lý camera không được vượt quá 1000 ký tự.")]
    public string? QLCamera { get; init; }

    [Required(ErrorMessage = "Loại trạm là bắt buộc.")]
    [Range(1, 2, ErrorMessage = "Loại trạm chỉ nhận giá trị 1 hoặc 2.")]
    public int? TypeTram { get; init; }
}

public sealed class UpdateBranchRequest
{
    public int? CompanyId { get; init; }

    [StringLength(100, ErrorMessage = "Mã trạm không được vượt quá 100 ký tự.")]
    public string? Code { get; init; }

    [StringLength(1000, ErrorMessage = "Tên trạm không được vượt quá 1000 ký tự.")]
    public string? Name { get; init; }

    [EmailAddress(ErrorMessage = "Email không hợp lệ.")]
    [StringLength(1000, ErrorMessage = "Email không được vượt quá 1000 ký tự.")]
    public string? Email { get; init; }

    [StringLength(100, ErrorMessage = "Số điện thoại không được vượt quá 100 ký tự.")]
    public string? Phone { get; init; }

    [StringLength(1000, ErrorMessage = "Địa chỉ không được vượt quá 1000 ký tự.")]
    public string? Address { get; init; }

    [StringLength(1000, ErrorMessage = "Tài khoản không được vượt quá 1000 ký tự.")]
    public string? Username { get; init; }

    [StringLength(1000, ErrorMessage = "Mật khẩu không được vượt quá 1000 ký tự.")]
    public string? Password { get; init; }

    [StringLength(1000, ErrorMessage = "Phần mềm quản lý xe không được vượt quá 1000 ký tự.")]
    public string? PMQLXe { get; init; }

    [StringLength(1000, ErrorMessage = "Phần mềm quản lý camera không được vượt quá 1000 ký tự.")]
    public string? QLCamera { get; init; }

    [Range(1, 2, ErrorMessage = "Loại trạm chỉ nhận giá trị 1 hoặc 2.")]
    public int? TypeTram { get; init; }
}

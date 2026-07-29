using System.ComponentModel.DataAnnotations;
using TTSmart.Api.Common.Models;

namespace TTSmart.Api.Features.CompanyManagement;

public sealed class CompanyListQuery
{
    [Range(1, int.MaxValue)]
    public int PageNumber { get; init; } = 1;

    [Range(1, 100)]
    public int PageSize { get; init; } = 20;

    [StringLength(100)]
    public string? Search { get; init; }

    public byte? Status { get; init; }
    public bool? IsLocked { get; init; }
}

public sealed record CompanyResponse(
    int Id,
    string? Code,
    string? Name,
    string? Email,
    string? Phone,
    string? Address,
    string? Fax,
    string? Representative,
    string? ContactName,
    string? ContactEmail,
    string? ContactPhone,
    DateTime? CreatedAtUtc,
    DateTime? UpdatedAtUtc,
    int? UserId,
    byte Status,
    bool IsActive,
    int CountUser,
    int Active,
    bool IsLocked,
    string? Note,
    string? Logo,
    DateOnly? ExpiredDate);

public abstract class CompanyFieldsRequest
{
    [Required]
    [StringLength(100)]
    public string Code { get; init; } = string.Empty;

    [Required]
    [StringLength(1000)]
    public string Name { get; init; } = string.Empty;

    [Required]
    [EmailAddress]
    [StringLength(1000)]
    public string Email { get; init; } = string.Empty;

    [Required]
    [StringLength(100)]
    public string Phone { get; init; } = string.Empty;

    public string? Address { get; init; }

    [StringLength(100)]
    public string? Fax { get; init; }

    [StringLength(400)]
    public string? Representative { get; init; }

    [StringLength(400)]
    public string? ContactName { get; init; }

    [EmailAddress]
    [StringLength(1000)]
    public string? ContactEmail { get; init; }

    [StringLength(100)]
    public string? ContactPhone { get; init; }

    [Range(0, int.MaxValue)]
    public int CountUser { get; init; }

    [Range(0, 1)]
    public int Active { get; init; }

    public string? Note { get; init; }
}

public sealed class CreateCompanyRequest : CompanyFieldsRequest;

public sealed class UpdateCompanyRequest : CompanyFieldsRequest;

public sealed class SetCompanyLockRequest
{
    [Required]
    public bool? IsLocked { get; init; }
}

public sealed class SetCompanyExpirationRequest
{
    public DateOnly? ExpiredDate { get; init; }
}

public sealed class UploadCompanyLogoRequest
{
    [Required]
    public IFormFile? File { get; init; }
}

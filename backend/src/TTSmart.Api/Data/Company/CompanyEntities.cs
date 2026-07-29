namespace TTSmart.Api.Data.Company;

public sealed class WebCompany
{
    public int CompanyId { get; set; }
    public string? Code { get; set; }
    public string? Name { get; set; }
    public string? Email { get; set; }
    public string? Phone { get; set; }
    public string? Address { get; set; }
    public string? Fax { get; set; }
    public string? Representative { get; set; }
    public string? ContactName { get; set; }
    public string? ContactEmail { get; set; }
    public string? ContactPhone { get; set; }
    public DateTime? CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public int? UserId { get; set; }
    public byte? Status { get; set; }
    public int CountUser { get; set; }
    public int Active { get; set; }
    public string? PMQLXe { get; set; }
    public string? QLCamera { get; set; }
    public string? Note { get; set; }
    public string? Logo { get; set; }
    public DateTime? ExpiredDate { get; set; }
    public bool IsLocked { get; set; }
}

public sealed class WebBranch
{
    public int BranchId { get; set; }
    public string? Code { get; set; }
    public string? Name { get; set; }
    public string? Avatar { get; set; }
    public string? Email { get; set; }
    public string? Phone { get; set; }
    public string? Address { get; set; }
    public string? Contents { get; set; }
    public DateTime? CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public int? UserId { get; set; }
    public byte? Status { get; set; }
    public int? Location { get; set; }
    public string? Lat { get; set; }
    public string? Long { get; set; }
    public int? CompanyId { get; set; }
    public string? Dataname { get; set; }
    public string? Username { get; set; }
    public string? Password { get; set; }
    public string? PMQLXe { get; set; }
    public string? QLCamera { get; set; }
    public int? TypeTram { get; set; }
    public bool UsePrivatePrintTemplate { get; set; }
    public string? PrintTemplateFolder { get; set; }
}

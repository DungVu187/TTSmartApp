using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.Extensions.Options;

namespace TTSmart.Api.Data.Company;

public sealed class CompanyDbContext : DbContext
{
    private readonly bool isLockedColumnAvailable;
    internal bool IsLockedColumnAvailable => isLockedColumnAvailable;

    public CompanyDbContext(DbContextOptions<CompanyDbContext> options) : base(options)
    {
        isLockedColumnAvailable = true;
    }

    public CompanyDbContext(
        DbContextOptions<CompanyDbContext> options,
        IOptions<CompanyDatabaseOptions> databaseOptions) : base(options)
    {
        isLockedColumnAvailable = databaseOptions.Value.IsLockedColumnAvailable;
    }

    public DbSet<WebCompany> Companies => Set<WebCompany>();
    public DbSet<WebBranch> Branches => Set<WebBranch>();

    protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
    {
        optionsBuilder.ReplaceService<IModelCacheKeyFactory, CompanyModelCacheKeyFactory>();
        base.OnConfiguring(optionsBuilder);
    }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        var company = modelBuilder.Entity<WebCompany>();
        company.ToTable("Company", "dbo");
        company.HasKey(item => item.CompanyId).HasName("PK_Company");
        company.Property(item => item.CompanyId).ValueGeneratedOnAdd();
        company.Property(item => item.Code).HasColumnType("nvarchar(100)").HasMaxLength(100);
        company.Property(item => item.Name).HasColumnType("nvarchar(1000)").HasMaxLength(1000);
        company.Property(item => item.Email).HasColumnType("nvarchar(1000)").HasMaxLength(1000);
        company.Property(item => item.Phone).HasColumnType("nvarchar(100)").HasMaxLength(100);
        company.Property(item => item.Address).HasColumnType("ntext");
        company.Property(item => item.Fax).HasColumnType("nvarchar(100)").HasMaxLength(100);
        company.Property(item => item.Representative).HasColumnType("nvarchar(400)").HasMaxLength(400);
        company.Property(item => item.ContactName).HasColumnType("nvarchar(400)").HasMaxLength(400);
        company.Property(item => item.ContactEmail).HasColumnType("nvarchar(1000)").HasMaxLength(1000);
        company.Property(item => item.ContactPhone).HasColumnType("nvarchar(100)").HasMaxLength(100);
        company.Property(item => item.CreatedAt).HasColumnType("datetime");
        company.Property(item => item.UpdatedAt).HasColumnType("datetime");
        company.Property(item => item.Status).HasColumnType("tinyint");
        company.Property(item => item.CountUser).HasColumnType("int").IsRequired();
        company.Property(item => item.Active).HasColumnType("int").IsRequired();
        company.Property(item => item.PMQLXe).HasColumnType("nvarchar(1000)").HasMaxLength(1000);
        company.Property(item => item.QLCamera).HasColumnType("nvarchar(1000)").HasMaxLength(1000);
        company.Property(item => item.Note).HasColumnType("ntext");
        company.Property(item => item.Logo).HasColumnType("ntext");
        company.Property(item => item.ExpiredDate).HasColumnType("datetime");
        if (isLockedColumnAvailable)
        {
            company.Property(item => item.IsLocked).HasColumnType("bit").IsRequired();
        }
        else
        {
            company.Ignore(item => item.IsLocked);
        }

        var branch = modelBuilder.Entity<WebBranch>();
        branch.ToTable("Branch", "dbo");
        branch.HasKey(item => item.BranchId).HasName("PK_Branch");
        branch.Property(item => item.BranchId).ValueGeneratedOnAdd();
        branch.Property(item => item.Code).HasColumnType("nvarchar(100)").HasMaxLength(100);
        branch.Property(item => item.Name).HasColumnType("nvarchar(1000)").HasMaxLength(1000);
        branch.Property(item => item.Avatar).HasColumnType("nvarchar(1000)").HasMaxLength(1000);
        branch.Property(item => item.Email).HasColumnType("nvarchar(1000)").HasMaxLength(1000);
        branch.Property(item => item.Phone).HasColumnType("nvarchar(100)").HasMaxLength(100);
        branch.Property(item => item.Address).HasColumnType("nvarchar(1000)").HasMaxLength(1000);
        branch.Property(item => item.Contents).HasColumnType("ntext");
        branch.Property(item => item.CreatedAt).HasColumnType("datetime");
        branch.Property(item => item.UpdatedAt).HasColumnType("datetime");
        branch.Property(item => item.Status).HasColumnType("tinyint");
        branch.Property(item => item.Lat).HasColumnType("varchar(50)").HasMaxLength(50);
        branch.Property(item => item.Long).HasColumnType("varchar(50)").HasMaxLength(50);
        branch.Property(item => item.Dataname).HasColumnType("nvarchar(1000)").HasMaxLength(1000);
        branch.Property(item => item.Username).HasColumnType("nvarchar(1000)").HasMaxLength(1000);
        branch.Property(item => item.Password).HasColumnType("nvarchar(1000)").HasMaxLength(1000);
        branch.Property(item => item.PMQLXe).HasColumnType("nvarchar(1000)").HasMaxLength(1000);
        branch.Property(item => item.QLCamera).HasColumnType("nvarchar(1000)").HasMaxLength(1000);
        branch.Property(item => item.PrintTemplateFolder).HasColumnType("nvarchar(510)").HasMaxLength(510);
        branch.Property(item => item.UsePrivatePrintTemplate).HasColumnType("bit").IsRequired();

        base.OnModelCreating(modelBuilder);
    }
}

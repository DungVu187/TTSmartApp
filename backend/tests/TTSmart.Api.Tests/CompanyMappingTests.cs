using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using TTSmart.Api.Data.Company;

namespace TTSmart.Api.Tests;

public sealed class CompanyMappingTests
{
    [Fact]
    public void BranchModel_KhopSchemaLegacy()
    {
        using var dbContext = CreateDbContext();
        var entity = dbContext.Model.FindEntityType(typeof(WebBranch));

        Assert.NotNull(entity);
        Assert.Equal("Branch", entity.GetTableName());
        Assert.Equal("dbo", entity.GetSchema());
        Assert.Equal("nvarchar(100)", entity.FindProperty(nameof(WebBranch.Code))?.GetColumnType());
        Assert.Equal(100, entity.FindProperty(nameof(WebBranch.Code))?.GetMaxLength());
        Assert.Equal("nvarchar(1000)", entity.FindProperty(nameof(WebBranch.Username))?.GetColumnType());
        Assert.Equal("nvarchar(1000)", entity.FindProperty(nameof(WebBranch.Password))?.GetColumnType());
        Assert.Equal("nvarchar(510)", entity.FindProperty(nameof(WebBranch.PrintTemplateFolder))?.GetColumnType());
        Assert.Empty(entity.GetForeignKeys());
    }

    [Fact]
    public void CompanyModel_ProductionKhongYeuCauCotIsLocked()
    {
        var services = new ServiceCollection();
        services.AddSingleton<IOptions<CompanyDatabaseOptions>>(
            Options.Create(new CompanyDatabaseOptions { IsLockedColumnAvailable = false }));
        services.AddDbContext<CompanyDbContext>(options =>
            options.UseInMemoryDatabase(Guid.NewGuid().ToString()));
        using var provider = services.BuildServiceProvider();
        using var scope = provider.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<CompanyDbContext>();
        var entity = dbContext.Model.FindEntityType(typeof(WebCompany));

        Assert.NotNull(entity);
        Assert.Null(entity.FindProperty(nameof(WebCompany.IsLocked)));
    }

    private static CompanyDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<CompanyDbContext>()
            .UseSqlServer(
                "Server=(local);Database=TTSmartMappingTests;Integrated Security=True;TrustServerCertificate=True")
            .Options;
        return new CompanyDbContext(options);
    }
}

using TTSmart.Api.Data.WebAuth;
using TTSmart.Api.Features.Auth;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata;

namespace TTSmart.Api.Tests;

public sealed class WebAuthMappingTests
{
    [Fact]
    public void Model_KhopDoDaiChuoiCuaNamBangLegacy()
    {
        using var dbContext = CreateDbContext();

        AssertProperty(dbContext, typeof(WebUser), nameof(WebUser.FullName), "nvarchar(200)", 200);
        AssertProperty(dbContext, typeof(WebUser), nameof(WebUser.UserName), "nvarchar(100)", 100);
        AssertProperty(dbContext, typeof(WebUser), nameof(WebUser.Code), "nvarchar(100)", 100);
        AssertProperty(dbContext, typeof(WebUser), nameof(WebUser.KeyLock), "nvarchar(40)", 40);
        AssertProperty(dbContext, typeof(WebUser), nameof(WebUser.RegEmail), "nvarchar(100)", 100);
        AssertProperty(dbContext, typeof(WebUser), nameof(WebUser.BranchId), "nvarchar(1000)", 1000);

        AssertProperty(dbContext, typeof(WebRole), nameof(WebRole.Code), "nvarchar(100)", 100);
        AssertProperty(dbContext, typeof(WebRole), nameof(WebRole.Name), "nvarchar(1000)", 1000);

        AssertProperty(dbContext, typeof(WebFunction), nameof(WebFunction.Code), "nvarchar(100)", 100);
        AssertProperty(dbContext, typeof(WebFunction), nameof(WebFunction.Url), "nvarchar(400)", 400);
        AssertProperty(dbContext, typeof(WebFunction), nameof(WebFunction.Note), "nvarchar(4000)", 4000);
        AssertProperty(dbContext, typeof(WebFunction), nameof(WebFunction.Icon), "nvarchar(1000)", 1000);

        AssertProperty(dbContext, typeof(WebFunctionRole), nameof(WebFunctionRole.ActiveKey), "nvarchar(40)", 40);
    }

    [Fact]
    public void AuthRoleQuery_DichDuocTrenSqlServer()
    {
        using var dbContext = CreateDbContext();

        var sql = AuthService.BuildRoleQuery(dbContext, userId: 123).ToQueryString();

        Assert.Contains("SELECT DISTINCT", sql, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("ORDER BY", sql, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void Model_ChiTaoHaiForeignKeyVatLyCoTrongSchema()
    {
        using var dbContext = CreateDbContext();
        var foreignKeys = dbContext.Model.GetEntityTypes()
            .SelectMany(entityType => entityType.GetForeignKeys())
            .Select(foreignKey => foreignKey.GetConstraintName() ?? string.Empty)
            .OrderBy(name => name)
            .ToArray();

        Assert.Equal(["FK_FunctionRole_Function", "FK_UserRole_User"], foreignKeys);
    }

    private static void AssertProperty(
        WebAuthDbContext dbContext,
        Type entityType,
        string propertyName,
        string columnType,
        int maxLength)
    {
        var property = dbContext.Model.FindEntityType(entityType)?.FindProperty(propertyName);

        Assert.NotNull(property);
        Assert.Equal(columnType, property.GetColumnType());
        Assert.Equal(maxLength, property.GetMaxLength());
    }

    private static WebAuthDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<WebAuthDbContext>()
            .UseSqlServer(
                "Server=(local);Database=TTSmartMappingTests;Integrated Security=True;TrustServerCertificate=True")
            .Options;
        return new WebAuthDbContext(options);
    }
}

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using TTSmart.Api.Data.Company;
using TTSmart.Api.Data.WebAuth;
using TTSmart.Api.Features.Authorization;
using TTSmart.Api.Features.CompanyManagement;

namespace TTSmart.Api.Tests;

public sealed class CompanyAccessEvaluatorTests
{
    [Fact]
    public async Task EnforceExpirationDuocBat_TuChoiCompanyHetHan()
    {
        var dbOptions = new DbContextOptionsBuilder<CompanyDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        await using var dbContext = new CompanyDbContext(dbOptions);
        dbContext.Companies.Add(new WebCompany
        {
            CompanyId = 1,
            Code = "CT_EXPIRED",
            Name = "Công ty hết hạn",
            Email = "expired@example.test",
            Phone = "0900000000",
            Status = WebDataStatus.Active,
            Active = 1,
            IsLocked = false,
            ExpiredDate = new DateTime(2020, 1, 1, 23, 59, 59)
        });
        await dbContext.SaveChangesAsync();
        var evaluator = new CompanyAccessEvaluator(
            dbContext,
            new TestSystemRoleEvaluator(),
            Options.Create(new CompanyAccessOptions { EnforceExpiration = true }));

        var decision = await evaluator.EvaluateAsync(
            new WebUser { UserId = 1, CompanyId = 1 },
            CancellationToken.None);

        Assert.False(decision.IsAllowed);
        Assert.Equal(CompanyAccessErrors.Expired, decision.ErrorCode);
    }

    [Fact]
    public async Task IsLockedColumnDuocBat_TuChoiCompanyBiKhoa()
    {
        var dbOptions = new DbContextOptionsBuilder<CompanyDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        await using var dbContext = new CompanyDbContext(dbOptions);
        dbContext.Companies.Add(new WebCompany
        {
            CompanyId = 1,
            Code = "CT_LOCKED",
            Name = "Công ty bị khóa",
            Email = "locked@example.test",
            Phone = "0900000000",
            Status = WebDataStatus.Active,
            Active = 1,
            IsLocked = true
        });
        await dbContext.SaveChangesAsync();
        var evaluator = new CompanyAccessEvaluator(
            dbContext,
            new TestSystemRoleEvaluator(),
            Options.Create(new CompanyAccessOptions()),
            Options.Create(new CompanyDatabaseOptions { IsLockedColumnAvailable = true }));

        var decision = await evaluator.EvaluateAsync(
            new WebUser { UserId = 1, CompanyId = 1 },
            CancellationToken.None);

        Assert.False(decision.IsAllowed);
        Assert.Equal(CompanyAccessErrors.Locked, decision.ErrorCode);
    }

    private sealed class TestSystemRoleEvaluator : ISystemRoleEvaluator
    {
        public Task<bool> IsSuperAdminAsync(int userId, CancellationToken cancellationToken) =>
            Task.FromResult(false);
    }
}

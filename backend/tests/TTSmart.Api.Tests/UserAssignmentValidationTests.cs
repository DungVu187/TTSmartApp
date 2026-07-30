using System.ComponentModel.DataAnnotations;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using TTSmart.Api.Data.Company;
using TTSmart.Api.Data.WebAuth;
using TTSmart.Api.Features.AccessManagement;
using TTSmart.Api.Features.Auth;
using TTSmart.Api.Features.Authorization;

namespace TTSmart.Api.Tests;

public sealed class UserAssignmentValidationTests
{
    [Fact]
    public async Task TaoUserTuCongTy_BatBuocTramHoatDongThuocDungCongTyVaChuanHoaDanhSach()
    {
        await using var authDbContext = CreateAuthDbContext();
        await using var companyDbContext = CreateCompanyDbContext();
        var owner = new WebUser
        {
            UserName = "company-owner",
            Password = "hash",
            CompanyId = 10,
            Status = WebDataStatus.Active
        };
        var childRole = new WebRole
        {
            Code = "QUANLY",
            Name = "Tài khoản quản lý",
            Status = WebDataStatus.Active
        };
        authDbContext.AddRange(owner, childRole);
        await authDbContext.SaveChangesAsync();
        companyDbContext.Companies.Add(new WebCompany
        {
            CompanyId = 10,
            Code = "COMPANY_10",
            Name = "Công ty 10",
            Email = "company10@example.test",
            Phone = "0900000000",
            CountUser = 9,
            Active = 1,
            Status = WebDataStatus.Active
        });
        companyDbContext.Branches.AddRange(
            CreateBranch(100, 10, WebDataStatus.Active),
            CreateBranch(101, 10, WebDataStatus.Active),
            CreateBranch(200, 20, WebDataStatus.Active),
            CreateBranch(102, 10, WebDataStatus.Inactive));
        await companyDbContext.SaveChangesAsync();
        var service = CreateService(authDbContext, companyDbContext, isSuperAdmin: false);

        await Assert.ThrowsAsync<ValidationException>(() => service.CreateAsync(
            CreateRequest("missing-branch", childRole.RoleId, null),
            owner.UserId,
            CancellationToken.None));
        await Assert.ThrowsAsync<ValidationException>(() => service.CreateAsync(
            CreateRequest("foreign-branch", childRole.RoleId, "200"),
            owner.UserId,
            CancellationToken.None));
        await Assert.ThrowsAsync<ValidationException>(() => service.CreateAsync(
            CreateRequest("inactive-branch", childRole.RoleId, "102"),
            owner.UserId,
            CancellationToken.None));
        await Assert.ThrowsAsync<ValidationException>(() => service.CreateAsync(
            CreateRequest("invalid-branch", childRole.RoleId, "100,undefined"),
            owner.UserId,
            CancellationToken.None));

        var created = await service.CreateAsync(
            CreateRequest("valid-branch", childRole.RoleId, "101, 100,101"),
            owner.UserId,
            CancellationToken.None);

        Assert.Equal(10, created.CompanyId);
        Assert.Equal("101,100", created.BranchId);
        Assert.Equal("101,100", await authDbContext.Users
            .Where(user => user.UserId == created.Id)
            .Select(user => user.BranchId)
            .SingleAsync());
    }

    [Fact]
    public async Task TaoUserBangAdmin_DuocBoQuaYeuCauCompanyVaTram()
    {
        await using var authDbContext = CreateAuthDbContext();
        await using var companyDbContext = CreateCompanyDbContext();
        var childRole = new WebRole
        {
            Code = "QUANLY",
            Name = "Tài khoản quản lý",
            Status = WebDataStatus.Active
        };
        authDbContext.Roles.Add(childRole);
        await authDbContext.SaveChangesAsync();
        var service = CreateService(authDbContext, companyDbContext, isSuperAdmin: true);

        var created = await service.CreateAsync(
            CreateRequest("admin-created", childRole.RoleId, null),
            999,
            CancellationToken.None);

        Assert.Null(created.CompanyId);
        Assert.Null(created.BranchId);
    }

    [Fact]
    public async Task SuaHoSoUserLegacy_GiuAssignmentCuNhungBatBuocHopLeKhiDoiTram()
    {
        await using var authDbContext = CreateAuthDbContext();
        await using var companyDbContext = CreateCompanyDbContext();
        var owner = new WebUser
        {
            UserName = "company-owner-update",
            Password = "hash",
            CompanyId = 10,
            Status = WebDataStatus.Active
        };
        var target = new WebUser
        {
            UserName = "legacy-manager",
            Password = "hash",
            CompanyId = 10,
            BranchId = "200",
            Status = WebDataStatus.Active
        };
        var childRole = new WebRole
        {
            Code = "QUANLY",
            Name = "Tài khoản quản lý",
            Status = WebDataStatus.Active
        };
        authDbContext.AddRange(owner, target, childRole);
        await authDbContext.SaveChangesAsync();
        authDbContext.UserRoles.Add(new WebUserRole
        {
            UserId = target.UserId,
            RoleId = childRole.RoleId,
            Status = WebDataStatus.Active
        });
        await authDbContext.SaveChangesAsync();
        companyDbContext.Branches.AddRange(
            CreateBranch(100, 10, WebDataStatus.Active),
            CreateBranch(200, 20, WebDataStatus.Active),
            CreateBranch(201, 20, WebDataStatus.Active));
        await companyDbContext.SaveChangesAsync();
        var service = CreateService(authDbContext, companyDbContext, isSuperAdmin: false);

        var profileUpdated = await service.UpdateAsync(
            target.UserId,
            new UpdateUserRequest
            {
                UserName = target.UserName,
                FullName = "Tên mới",
                BranchId = "200",
                RoleIds = [childRole.RoleId]
            },
            owner.UserId,
            CancellationToken.None);

        Assert.Equal("Tên mới", profileUpdated.FullName);
        Assert.Equal("200", profileUpdated.BranchId);
        await Assert.ThrowsAsync<ValidationException>(() => service.UpdateAsync(
            target.UserId,
            new UpdateUserRequest
            {
                UserName = target.UserName,
                BranchId = "201",
                RoleIds = [childRole.RoleId]
            },
            owner.UserId,
            CancellationToken.None));

        var assignmentUpdated = await service.UpdateAsync(
            target.UserId,
            new UpdateUserRequest
            {
                UserName = target.UserName,
                BranchId = "100",
                RoleIds = [childRole.RoleId]
            },
            owner.UserId,
            CancellationToken.None);
        Assert.Equal("100", assignmentUpdated.BranchId);
    }

    private static CreateUserRequest CreateRequest(string userName, int roleId, string? branchId) =>
        new()
        {
            UserName = userName,
            Password = "Password@123",
            BranchId = branchId,
            RoleIds = [roleId]
        };

    private static WebBranch CreateBranch(int branchId, int companyId, byte status) =>
        new()
        {
            BranchId = branchId,
            Code = $"BRANCH_{branchId}",
            Name = $"Trạm {branchId}",
            CompanyId = companyId,
            Status = status
        };

    private static UserAdministrationService CreateService(
        WebAuthDbContext authDbContext,
        CompanyDbContext companyDbContext,
        bool isSuperAdmin) =>
        new(
            authDbContext,
            companyDbContext,
            new DatabasePasswordService(Options.Create(new DatabasePasswordOptions
            {
                PasswordWriteMode = DatabasePasswordWriteMode.Md5Utf8
            })),
            new TestSystemRoleEvaluator(isSuperAdmin));

    private static WebAuthDbContext CreateAuthDbContext() =>
        new(new DbContextOptionsBuilder<WebAuthDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options);

    private static CompanyDbContext CreateCompanyDbContext() =>
        new(new DbContextOptionsBuilder<CompanyDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options);

    private sealed class TestSystemRoleEvaluator(bool isSuperAdmin) : ISystemRoleEvaluator
    {
        public Task<bool> IsSuperAdminAsync(int userId, CancellationToken cancellationToken) =>
            Task.FromResult(isSuperAdmin);
    }
}
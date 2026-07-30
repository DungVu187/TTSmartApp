using System.Text.Json;
using System.ComponentModel.DataAnnotations;
using TTSmart.Api.Common.Exceptions;
using TTSmart.Api.Data.Company;
using TTSmart.Api.Data.WebAuth;
using TTSmart.Api.Features.AccessManagement;
using TTSmart.Api.Features.Auth;
using TTSmart.Api.Features.Authorization;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace TTSmart.Api.Tests;

public sealed class AccessManagementServiceTests
{
    [Fact]
    public async Task UserCrud_GanRoleVaXoaMem_KhongTraDuLieuMatKhau()
    {
        await using var dbContext = CreateDbContext();
        dbContext.Roles.Add(new WebRole { RoleId = 3, Code = "CONGTY", Name = "Công ty", Status = WebDataStatus.Active });
        await dbContext.SaveChangesAsync();
        var passwordService = CreatePasswordService();
        var service = CreateUserService(dbContext, passwordService);

        var created = await service.CreateAsync(new CreateUserRequest
        {
            UserName = "new-user",
            FullName = "Người dùng mới",
            Password = "Password@123",
            RoleIds = [3]
        }, 900, CancellationToken.None);

        Assert.Equal("new-user", created.UserName);
        Assert.Contains(created.Roles, role => role.Id == 3);
        var json = JsonSerializer.Serialize(created);
        Assert.DoesNotContain("Password", json, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("KeyLock", json, StringComparison.OrdinalIgnoreCase);
        Assert.True(passwordService.Verify(await dbContext.Users.SingleAsync(), "Password@123"));

        await service.DeleteAsync(created.Id, 900, CancellationToken.None);
        var deleted = await service.GetByIdAsync(created.Id, 900, CancellationToken.None);
        Assert.False(deleted.IsActive);
        Assert.Equal(WebDataStatus.Inactive, deleted.Status);
        Assert.Equal(WebDataStatus.Inactive, await dbContext.Users.Select(user => user.Status).SingleAsync());
        Assert.Equal(WebDataStatus.Inactive, await dbContext.UserRoles.Select(userRole => userRole.Status).SingleAsync());
    }

    [Fact]
    public async Task RoleMatrix_Validate9BitVaCapNhatFunctionRole()
    {
        await using var dbContext = CreateDbContext();
        dbContext.Roles.Add(new WebRole { RoleId = 3, Code = "ROLE", Name = "Vai trò", Status = WebDataStatus.Active });
        dbContext.Functions.Add(new WebFunction { FunctionId = 4, Code = "QLND", Name = "Người dùng", Status = WebDataStatus.Active });
        await dbContext.SaveChangesAsync();
        var service = new RoleAdministrationService(dbContext);

        await Assert.ThrowsAsync<ValidationException>(() => service.SetFunctionsAsync(
            3,
            900,
            new SetRoleFunctionsRequest
            {
                Functions = [new RoleFunctionAssignmentRequest { FunctionId = 4, ActiveKey = "111111" }]
            },
            CancellationToken.None));

        var response = await service.SetFunctionsAsync(
            3,
            900,
            new SetRoleFunctionsRequest
            {
                Functions = [new RoleFunctionAssignmentRequest { FunctionId = 4, ActiveKey = "011111111" }]
            },
            CancellationToken.None);

        var assignment = Assert.Single(response.Functions);
        Assert.Equal("011111111", assignment.ActiveKey);
        Assert.False(assignment.Permissions.View);
        Assert.True(assignment.Permissions.Create);
    }

    [Fact]
    public async Task UserUpdateVaThayRole_DungXoaMemAssignmentCu()
    {
        await using var dbContext = CreateDbContext();
        dbContext.Roles.AddRange(
            new WebRole { RoleId = 3, Code = "ROLE_A", Name = "Vai trò A", Status = WebDataStatus.Active },
            new WebRole { RoleId = 4, Code = "ROLE_B", Name = "Vai trò B", Status = WebDataStatus.Active });
        await dbContext.SaveChangesAsync();
        var passwordService = CreatePasswordService();
        var service = CreateUserService(dbContext, passwordService);
        var created = await service.CreateAsync(new CreateUserRequest
        {
            UserName = "user-update",
            RegEmail = "user-update@example.test",
            Password = "Password@123",
            RoleIds = [3]
        }, 900, CancellationToken.None);

        var updated = await service.UpdateAsync(created.Id, new UpdateUserRequest
        {
            UserName = "user-update",
            FullName = "Tên đã cập nhật",
            Phone = "0900000000",
            RoleIds = [4]
        }, 900, CancellationToken.None);

        Assert.Equal("Tên đã cập nhật", updated.FullName);
        Assert.Equal("0900000000", updated.Phone);
        Assert.Equal("user-update@example.test", updated.RegEmail);
        Assert.True(passwordService.Verify(await dbContext.Users.SingleAsync(), "Password@123"));
        Assert.DoesNotContain(updated.Roles, role => role.Id == 3);
        Assert.Contains(updated.Roles, role => role.Id == 4);
        Assert.Contains(await dbContext.UserRoles.ToListAsync(), row =>
            row.RoleId == 3 && row.Status == WebDataStatus.Inactive);
        Assert.Contains(await dbContext.UserRoles.ToListAsync(), row =>
            row.RoleId == 4 && row.Status == WebDataStatus.Active);

        await Assert.ThrowsAsync<ConflictException>(() => service.UpdateAsync(created.Id, new UpdateUserRequest
        {
            UserName = "user-update",
            RegEmail = "changed@example.test"
        }, 900, CancellationToken.None));
    }

    [Fact]
    public async Task RoleCrud_TaoSuaKhoaVaXoaMem()
    {
        await using var dbContext = CreateDbContext();
        var service = new RoleAdministrationService(dbContext);
        var created = await service.CreateAsync(new CreateRoleRequest
        {
            Code = "TEST_ROLE",
            Name = "Vai trò kiểm thử"
        }, 900, CancellationToken.None);
        var updated = await service.UpdateAsync(created.Id, new UpdateRoleRequest
        {
            Code = "TEST_ROLE_UPDATED",
            Name = "Vai trò đã cập nhật"
        }, 900, CancellationToken.None);
        Assert.Equal("TEST_ROLE_UPDATED", updated.Code);

        var inactive = await service.SetStatusAsync(created.Id, 900, new SetRoleStatusRequest
        {
            IsActive = false
        }, CancellationToken.None);
        Assert.False(inactive.IsActive);

        var deletable = await service.CreateAsync(new CreateRoleRequest
        {
            Code = "DELETE_ROLE",
            Name = "Vai trò xóa mềm"
        }, 900, CancellationToken.None);
        await service.DeleteAsync(deletable.Id, 900, CancellationToken.None);
        Assert.Equal(WebDataStatus.Inactive, await dbContext.Roles
            .Where(role => role.RoleId == deletable.Id)
            .Select(role => role.Status)
            .SingleAsync());
    }

    [Fact]
    public async Task RoleMatrix_PayloadLoi_KhongThayDoiAssignmentHienTai()
    {
        await using var dbContext = CreateDbContext();
        dbContext.Roles.Add(new WebRole { RoleId = 3, Code = "ROLE", Name = "Vai trò", Status = WebDataStatus.Active });
        dbContext.Functions.AddRange(
            new WebFunction { FunctionId = 4, Code = "QLND", Name = "Người dùng", Status = WebDataStatus.Active },
            new WebFunction { FunctionId = 5, Code = "QLQ", Name = "Phân quyền", Status = WebDataStatus.Active });
        dbContext.FunctionRoles.Add(new WebFunctionRole
        {
            TargetId = 3,
            FunctionId = 4,
            Type = WebFunctionRoleType.Role,
            ActiveKey = "100000000",
            Status = WebDataStatus.Active
        });
        await dbContext.SaveChangesAsync();
        var service = new RoleAdministrationService(dbContext);

        await Assert.ThrowsAsync<ValidationException>(() => service.SetFunctionsAsync(
            3,
            900,
            new SetRoleFunctionsRequest
            {
                Functions =
                [
                    new RoleFunctionAssignmentRequest { FunctionId = 4, ActiveKey = "111111111" },
                    new RoleFunctionAssignmentRequest { FunctionId = 5, ActiveKey = "11111111x" }
                ]
            },
            CancellationToken.None));

        Assert.Equal("100000000", await dbContext.FunctionRoles.Select(item => item.ActiveKey).SingleAsync());
    }

    [Fact]
    public async Task FunctionCrud_LuuCayChaConVaXoaMem()
    {
        await using var dbContext = CreateDbContext();
        var service = new FunctionAdministrationService(dbContext);
        var parent = await service.CreateAsync(new CreateFunctionRequest
        {
            Code = "PARENT",
            Name = "Chức năng cha"
        }, 900, CancellationToken.None);
        var child = await service.CreateAsync(new CreateFunctionRequest
        {
            Code = "CHILD",
            Name = "Chức năng con",
            ParentFunctionId = parent.Id
        }, 900, CancellationToken.None);

        Assert.Equal(parent.Id, child.ParentFunctionId);
        await Assert.ThrowsAsync<ConflictException>(() => service.DeleteAsync(parent.Id, 900, CancellationToken.None));
        await service.DeleteAsync(child.Id, 900, CancellationToken.None);
        var deleted = await service.GetByIdAsync(child.Id, CancellationToken.None);
        Assert.False(deleted.IsActive);
    }

    [Fact]
    public async Task UserRole_BiXoaMem_DuocKhoiPhucKhongTaoBanGhiTrung()
    {
        await using var dbContext = CreateDbContext();
        var user = new WebUser
        {
            UserName = $"user_{Guid.NewGuid():N}",
            Password = "hash",
            Status = WebDataStatus.Active
        };
        var role = new WebRole
        {
            Code = $"ROLE_{Guid.NewGuid():N}"[..20],
            Name = "Vai trò khôi phục",
            Status = WebDataStatus.Active
        };
        dbContext.AddRange(user, role);
        await dbContext.SaveChangesAsync();
        dbContext.UserRoles.Add(new WebUserRole
        {
            UserId = user.UserId,
            RoleId = role.RoleId,
            Status = WebDataStatus.Inactive
        });
        await dbContext.SaveChangesAsync();
        var service = CreateUserService(dbContext, CreatePasswordService());

        await service.SetRolesAsync(
            user.UserId,
            user.UserId + 1,
            new SetUserRolesRequest { RoleIds = [role.RoleId] },
            CancellationToken.None);

        var assignments = await dbContext.UserRoles.ToListAsync();
        Assert.Single(assignments);
        Assert.Equal(WebDataStatus.Active, assignments[0].Status);
    }

    [Fact]
    public async Task DanhSachMacDinh_ChiLayBanGhiStatus1()
    {
        await using var dbContext = CreateDbContext();
        dbContext.Users.AddRange(
            new WebUser { UserName = $"active_{Guid.NewGuid():N}", Password = "hash", Status = WebDataStatus.Active },
            new WebUser { UserName = $"inactive_{Guid.NewGuid():N}", Password = "hash", Status = WebDataStatus.Inactive });
        await dbContext.SaveChangesAsync();
        var service = CreateUserService(dbContext, CreatePasswordService());

        var activePage = await service.GetPageAsync(new UserListQuery(), 900, CancellationToken.None);
        var inactivePage = await service.GetPageAsync(
            new UserListQuery { Status = WebDataStatus.Inactive },
            900,
            CancellationToken.None);

        Assert.Single(activePage.Items);
        Assert.True(activePage.Items[0].IsActive);
        Assert.Single(inactivePage.Items);
        Assert.False(inactivePage.Items[0].IsActive);
    }

    [Fact]
    public async Task DanhSachVaChiTietUser_CongTyChiThayDuLieuCungCompanyId()
    {
        await using var dbContext = CreateDbContext();
        var owner = new WebUser
        {
            UserName = $"owner_{Guid.NewGuid():N}",
            Password = "hash",
            CompanyId = 10,
            Status = WebDataStatus.Active
        };
        var sameCompany = new WebUser
        {
            UserName = $"same_{Guid.NewGuid():N}",
            Password = "hash",
            CompanyId = 10,
            Status = WebDataStatus.Active
        };
        var otherCompany = new WebUser
        {
            UserName = $"other_{Guid.NewGuid():N}",
            Password = "hash",
            CompanyId = 20,
            Status = WebDataStatus.Active
        };
        dbContext.Users.AddRange(owner, sameCompany, otherCompany);
        await dbContext.SaveChangesAsync();
        var service = new UserAdministrationService(
            dbContext,
            CreateCompanyDbContext(),
            CreatePasswordService(),
            new TestSystemRoleEvaluator(false));

        var page = await service.GetPageAsync(new UserListQuery(), owner.UserId, CancellationToken.None);

        Assert.Equal(2, page.TotalCount);
        Assert.All(page.Items, user => Assert.Equal(10, user.CompanyId));
        await Assert.ThrowsAsync<NotFoundException>(() => service.GetByIdAsync(
            otherCompany.UserId,
            owner.UserId,
            CancellationToken.None));
    }

    [Fact]
    public async Task TaoUser_CongTyBiChanKhiDuQuota_XoaMemGiaiPhongSuat_AdminDuocVuot()
    {
        await using var dbContext = CreateDbContext();
        await using var companyDbContext = CreateCompanyDbContext();
        var ownerRole = new WebRole
        {
            RoleId = 3,
            Code = SystemRoleCodes.Company,
            Name = "Chủ doanh nghiệp",
            Status = WebDataStatus.Active
        };
        var childRole = new WebRole
        {
            RoleId = 4,
            Code = "QUANLY",
            Name = "Tài khoản quản lý",
            Status = WebDataStatus.Active
        };
        var owner = new WebUser
        {
            UserName = $"owner_{Guid.NewGuid():N}",
            Password = "hash",
            CompanyId = 10,
            Status = WebDataStatus.Active
        };
        var existingChild = new WebUser
        {
            UserName = $"child_{Guid.NewGuid():N}",
            Password = "hash",
            CompanyId = 10,
            Status = WebDataStatus.Active
        };
        dbContext.AddRange(ownerRole, childRole, owner, existingChild);
        await dbContext.SaveChangesAsync();
        dbContext.UserRoles.AddRange(
            new WebUserRole { UserId = owner.UserId, RoleId = ownerRole.RoleId, Status = WebDataStatus.Active },
            new WebUserRole { UserId = existingChild.UserId, RoleId = childRole.RoleId, Status = WebDataStatus.Active });
        companyDbContext.Companies.Add(new WebCompany
        {
            CompanyId = 10,
            Code = "COMPANY_10",
            Name = "Công ty quota",
            Email = "quota@example.test",
            Phone = "0900000000",
            CountUser = 1,
            Active = 1,
            Status = WebDataStatus.Active
        });
        await dbContext.SaveChangesAsync();
        companyDbContext.Branches.Add(new WebBranch
        {
            BranchId = 100,
            Code = "BRANCH_100",
            Name = "Trạm 100",
            CompanyId = 10,
            Status = WebDataStatus.Active
        });
        await companyDbContext.SaveChangesAsync();
        var companyService = new UserAdministrationService(
            dbContext,
            companyDbContext,
            CreatePasswordService(),
            new TestSystemRoleEvaluator(false));

        await Assert.ThrowsAsync<ConflictException>(() => companyService.CreateAsync(
            new CreateUserRequest
            {
                UserName = $"blocked_{Guid.NewGuid():N}",
                Password = "Password@123",
                BranchId = "100",
                RoleIds = [childRole.RoleId]
            },
            owner.UserId,
            CancellationToken.None));

        existingChild.Status = WebDataStatus.Inactive;
        await dbContext.SaveChangesAsync();
        var companyCreated = await companyService.CreateAsync(
            new CreateUserRequest
            {
                UserName = $"allowed_{Guid.NewGuid():N}",
                Password = "Password@123",
                BranchId = "100",
                RoleIds = [childRole.RoleId]
            },
            owner.UserId,
            CancellationToken.None);
        Assert.Equal(10, companyCreated.CompanyId);

        var adminService = new UserAdministrationService(
            dbContext,
            companyDbContext,
            CreatePasswordService(),
            new TestSystemRoleEvaluator(true));
        var adminCreated = await adminService.CreateAsync(
            new CreateUserRequest
            {
                UserName = $"admin_bypass_{Guid.NewGuid():N}",
                Password = "Password@123",
                CompanyId = 10,
                RoleIds = [childRole.RoleId]
            },
            999,
            CancellationToken.None);
        Assert.Equal(10, adminCreated.CompanyId);
    }

    [Fact]
    public async Task KhoiPhucUser_CongTyPhaiConQuota_AdminDuocBoQua()
    {
        await using var dbContext = CreateDbContext();
        await using var companyDbContext = CreateCompanyDbContext();
        var ownerRole = new WebRole
        {
            RoleId = 3,
            Code = SystemRoleCodes.Company,
            Name = "Chủ doanh nghiệp",
            Status = WebDataStatus.Active
        };
        var childRole = new WebRole
        {
            RoleId = 4,
            Code = "QUANLY",
            Name = "Tài khoản quản lý",
            Status = WebDataStatus.Active
        };
        var owner = new WebUser
        {
            UserName = $"owner_{Guid.NewGuid():N}",
            Password = "hash",
            CompanyId = 10,
            Status = WebDataStatus.Active
        };
        var activeChild = new WebUser
        {
            UserName = $"active_{Guid.NewGuid():N}",
            Password = "hash",
            CompanyId = 10,
            Status = WebDataStatus.Active
        };
        var deletedChild = new WebUser
        {
            UserName = $"deleted_{Guid.NewGuid():N}",
            Password = "hash",
            CompanyId = 10,
            Status = WebDataStatus.Inactive
        };
        dbContext.AddRange(ownerRole, childRole, owner, activeChild, deletedChild);
        await dbContext.SaveChangesAsync();
        dbContext.UserRoles.AddRange(
            new WebUserRole { UserId = owner.UserId, RoleId = ownerRole.RoleId, Status = WebDataStatus.Active },
            new WebUserRole { UserId = activeChild.UserId, RoleId = childRole.RoleId, Status = WebDataStatus.Active },
            new WebUserRole { UserId = deletedChild.UserId, RoleId = childRole.RoleId, Status = WebDataStatus.Inactive });
        companyDbContext.Companies.Add(new WebCompany
        {
            CompanyId = 10,
            Code = "COMPANY_10",
            Name = "Công ty quota",
            Email = "quota@example.test",
            Phone = "0900000000",
            CountUser = 1,
            Active = 1,
            Status = WebDataStatus.Active
        });
        await dbContext.SaveChangesAsync();
        await companyDbContext.SaveChangesAsync();
        var companyService = new UserAdministrationService(
            dbContext,
            companyDbContext,
            CreatePasswordService(),
            new TestSystemRoleEvaluator(false));

        await Assert.ThrowsAsync<ConflictException>(() => companyService.SetStatusAsync(
            deletedChild.UserId,
            owner.UserId,
            new SetUserStatusRequest { IsActive = true },
            CancellationToken.None));

        var adminService = new UserAdministrationService(
            dbContext,
            companyDbContext,
            CreatePasswordService(),
            new TestSystemRoleEvaluator(true));
        var restored = await adminService.SetStatusAsync(
            deletedChild.UserId,
            999,
            new SetUserStatusRequest { IsActive = true },
            CancellationToken.None);
        Assert.True(restored.IsActive);
    }

    [Fact]
    public async Task FunctionMatrix_TraCaFunctionChuaGanVaBoQuyenBangXoaMem()
    {
        await using var dbContext = CreateDbContext();
        var role = new WebRole
        {
            Code = $"ROLE_{Guid.NewGuid():N}"[..20],
            Name = "Vai trò ma trận",
            Status = WebDataStatus.Active
        };
        var assignedFunction = new WebFunction
        {
            Code = $"ASSIGNED_{Guid.NewGuid():N}"[..20],
            Name = "Function đã gán",
            FunctionParentId = 0,
            Status = WebDataStatus.Active
        };
        var unassignedFunction = new WebFunction
        {
            Code = $"UNASSIGNED_{Guid.NewGuid():N}"[..20],
            Name = "Function chưa gán",
            FunctionParentId = 0,
            Status = WebDataStatus.Active
        };
        dbContext.AddRange(role, assignedFunction, unassignedFunction);
        await dbContext.SaveChangesAsync();
        dbContext.FunctionRoles.Add(new WebFunctionRole
        {
            TargetId = role.RoleId,
            FunctionId = assignedFunction.FunctionId,
            ActiveKey = ActiveKeyValue.Set(ActiveKeyValue.None, ActiveKeyPermission.View, true),
            Type = WebFunctionRoleType.Role,
            Status = WebDataStatus.Active
        });
        await dbContext.SaveChangesAsync();
        var service = new RoleAdministrationService(dbContext);

        var matrix = await service.GetFunctionMatrixAsync(role.RoleId, CancellationToken.None);
        Assert.Contains(matrix, item => item.FunctionId == assignedFunction.FunctionId && item.IsAssigned);
        Assert.Contains(matrix, item =>
            item.FunctionId == unassignedFunction.FunctionId &&
            !item.IsAssigned &&
            item.ActiveKey == ActiveKeyValue.None);

        await service.RemoveFunctionAsync(
            role.RoleId,
            assignedFunction.FunctionId,
            currentUserId: 1,
            CancellationToken.None);
        Assert.Equal(WebDataStatus.Inactive, await dbContext.FunctionRoles
            .Select(item => item.Status)
            .SingleAsync());
    }

    [Fact]
    public async Task RoleMatrix_KhongChoBoQuyenQuanTriCuoiCung()
    {
        await using var dbContext = CreateDbContext();
        var user = new WebUser
        {
            UserName = $"admin_{Guid.NewGuid():N}",
            Password = "hash",
            Status = WebDataStatus.Active
        };
        var role = new WebRole
        {
            Code = $"ADMIN_{Guid.NewGuid():N}"[..20],
            Name = "Vai trò quản trị cuối cùng",
            Status = WebDataStatus.Active
        };
        var roleFunction = new WebFunction
        {
            Code = ManagementFunctionCodes.Roles,
            Name = "Phân quyền",
            FunctionParentId = 0,
            Status = WebDataStatus.Active
        };
        dbContext.AddRange(user, role, roleFunction);
        await dbContext.SaveChangesAsync();
        dbContext.UserRoles.Add(new WebUserRole
        {
            UserId = user.UserId,
            RoleId = role.RoleId,
            Status = WebDataStatus.Active
        });
        dbContext.FunctionRoles.Add(new WebFunctionRole
        {
            TargetId = role.RoleId,
            FunctionId = roleFunction.FunctionId,
            ActiveKey = ActiveKeyValue.Set(ActiveKeyValue.None, ActiveKeyPermission.Update, true),
            Type = WebFunctionRoleType.Role,
            Status = WebDataStatus.Active
        });
        await dbContext.SaveChangesAsync();
        var service = new RoleAdministrationService(dbContext);

        await Assert.ThrowsAsync<ConflictException>(() => service.SetFunctionsAsync(
            role.RoleId,
            user.UserId,
            new SetRoleFunctionsRequest { Functions = [] },
            CancellationToken.None));

        Assert.Equal(WebDataStatus.Active, await dbContext.FunctionRoles
            .Select(item => item.Status)
            .SingleAsync());
    }

    [Fact]
    public async Task FunctionQuanTri_KhongChoDoiCodeNgungHoacXoa()
    {
        await using var dbContext = CreateDbContext();
        var function = new WebFunction
        {
            Code = ManagementFunctionCodes.Users,
            Name = "Quản lý người dùng",
            FunctionParentId = 0,
            Status = WebDataStatus.Active
        };
        dbContext.Functions.Add(function);
        await dbContext.SaveChangesAsync();
        var service = new FunctionAdministrationService(dbContext);

        await Assert.ThrowsAsync<ConflictException>(() => service.UpdateAsync(
            function.FunctionId,
            new UpdateFunctionRequest { Code = "NEW_CODE", Name = function.Name },
            currentUserId: 1,
            CancellationToken.None));
        await Assert.ThrowsAsync<ConflictException>(() => service.SetStatusAsync(
            function.FunctionId,
            currentUserId: 1,
            new SetFunctionStatusRequest { IsActive = false },
            CancellationToken.None));
        await Assert.ThrowsAsync<ConflictException>(() => service.DeleteAsync(
            function.FunctionId,
            currentUserId: 1,
            CancellationToken.None));
    }

    private static DatabasePasswordService CreatePasswordService() =>
        new(Options.Create(new DatabasePasswordOptions { PasswordWriteMode = DatabasePasswordWriteMode.Md5Utf8 }));

    private static UserAdministrationService CreateUserService(
        WebAuthDbContext dbContext,
        IDatabasePasswordService passwordService) =>
        new(dbContext, CreateCompanyDbContext(), passwordService, new TestSystemRoleEvaluator(true));

    private static WebAuthDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<WebAuthDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new WebAuthDbContext(options);
    }

    private static CompanyDbContext CreateCompanyDbContext()
    {
        var options = new DbContextOptionsBuilder<CompanyDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new CompanyDbContext(options);
    }

    private sealed class TestSystemRoleEvaluator(bool isSuperAdmin) : ISystemRoleEvaluator
    {
        public Task<bool> IsSuperAdminAsync(int userId, CancellationToken cancellationToken) =>
            Task.FromResult(isSuperAdmin);
    }
}

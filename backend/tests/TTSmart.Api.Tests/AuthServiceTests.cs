using System.ComponentModel.DataAnnotations;
using TTSmart.Api.Common.Exceptions;
using TTSmart.Api.Common.Time;
using TTSmart.Api.Data.WebAuth;
using TTSmart.Api.Features.Auth;
using TTSmart.Api.Features.Authorization;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace TTSmart.Api.Tests;

public sealed class AuthServiceTests
{
    [Fact]
    public async Task LoginAsync_TraUserRoleFunctionVaQuyen9Bit()
    {
        await using var dbContext = CreateDbContext();
        var passwordService = CreatePasswordService();
        var user = new WebUser
        {
            UserId = 11,
            UserName = "admin",
            Password = HashForStorage(passwordService, 11, "Password@123", "LOCK-ADMIN", "admin@example.test"),
            FullName = "Quản trị viên",
            KeyLock = "LOCK-ADMIN",
            RegEmail = "admin@example.test",
            Status = WebDataStatus.Active
        };
        dbContext.Users.Add(user);
        dbContext.Roles.Add(new WebRole { RoleId = 1, Code = "ADMIN", Name = "Quản trị", Status = WebDataStatus.Active });
        dbContext.Functions.Add(new WebFunction { FunctionId = 4, Code = "QLND", Name = "Người dùng", Status = WebDataStatus.Active });
        dbContext.UserRoles.Add(new WebUserRole { UserId = 11, RoleId = 1, Status = WebDataStatus.Active });
        dbContext.FunctionRoles.Add(new WebFunctionRole
        {
            FunctionRoleId = 20,
            TargetId = 1,
            FunctionId = 4,
            Type = WebFunctionRoleType.Role,
            ActiveKey = "111111111",
            Status = WebDataStatus.Active
        });
        await dbContext.SaveChangesAsync();

        var service = new AuthService(dbContext, passwordService, new JwtTokenService(
            Options.Create(new JwtOptions
            {
                Issuer = "test",
                Audience = "test",
                SigningKey = "12345678901234567890123456789012",
                AccessTokenMinutes = 30
            })));

        var response = await service.LoginAsync(
            new LoginRequest { UserName = " admin ", Password = "Password@123" },
            CancellationToken.None);

        Assert.Equal(11, response.User.Id);
        Assert.Contains(response.Roles, role => role.Code == "ADMIN");
        var function = Assert.Single(response.Functions);
        Assert.Equal("111111111", function.ActiveKey);
        Assert.True(function.Permissions.Full);
        Assert.True(function.Permissions.DSach);
        Assert.NotEmpty(response.AccessToken);
    }

    [Fact]
    public async Task GetCurrentUserAsync_NhieuRole_HopNhatQuyenTheoOrTungBit()
    {
        await using var dbContext = CreateDbContext();
        var passwordService = CreatePasswordService();
        dbContext.Users.Add(new WebUser
        {
            UserId = 11,
            UserName = "multi-role",
            Password = HashForStorage(passwordService, 11, "Password@123"),
            Status = WebDataStatus.Active
        });
        dbContext.Roles.AddRange(
            new WebRole { RoleId = 1, Code = "ROLE_A", Name = "Vai trò A", Status = WebDataStatus.Active },
            new WebRole { RoleId = 2, Code = "ROLE_B", Name = "Vai trò B", Status = WebDataStatus.Active });
        dbContext.Functions.Add(new WebFunction { FunctionId = 4, Code = "QLND", Name = "Người dùng", Status = WebDataStatus.Active });
        dbContext.UserRoles.AddRange(
            new WebUserRole { UserId = 11, RoleId = 1, Status = WebDataStatus.Active },
            new WebUserRole { UserId = 11, RoleId = 2, Status = WebDataStatus.Active });
        dbContext.FunctionRoles.AddRange(
            new WebFunctionRole { TargetId = 1, FunctionId = 4, Type = WebFunctionRoleType.Role, ActiveKey = "100000000", Status = WebDataStatus.Active },
            new WebFunctionRole { TargetId = 2, FunctionId = 4, Type = WebFunctionRoleType.Role, ActiveKey = "010000000", Status = WebDataStatus.Active });
        await dbContext.SaveChangesAsync();
        var service = CreateAuthService(dbContext, passwordService);

        var response = await service.GetCurrentUserAsync(11, CancellationToken.None);

        var function = Assert.Single(response.Functions);
        Assert.Equal("110000000", function.ActiveKey);
        Assert.True(function.Permissions.View);
        Assert.True(function.Permissions.Create);
        Assert.False(function.Permissions.Update);
    }

    [Fact]
    public async Task GetCurrentUserAsync_GiuFunctionChaDeMobileDungMenu()
    {
        await using var dbContext = CreateDbContext();
        var passwordService = CreatePasswordService();
        var user = new WebUser
        {
            UserId = 11,
            UserName = $"menu_{Guid.NewGuid():N}",
            Password = HashForStorage(passwordService, 11, Guid.NewGuid().ToString("N")),
            Status = WebDataStatus.Active
        };
        var role = new WebRole
        {
            Code = $"ROLE_{Guid.NewGuid():N}"[..20],
            Name = "Vai trò menu",
            Status = WebDataStatus.Active
        };
        var parent = new WebFunction
        {
            Code = $"PARENT_{Guid.NewGuid():N}"[..20],
            Name = "Menu cha",
            FunctionParentId = 0,
            Status = WebDataStatus.Active
        };
        dbContext.AddRange(user, role, parent);
        await dbContext.SaveChangesAsync();
        var child = new WebFunction
        {
            Code = $"CHILD_{Guid.NewGuid():N}"[..20],
            Name = "Menu con",
            FunctionParentId = parent.FunctionId,
            Status = WebDataStatus.Active
        };
        dbContext.Functions.Add(child);
        await dbContext.SaveChangesAsync();
        dbContext.UserRoles.Add(new WebUserRole
        {
            UserId = user.UserId,
            RoleId = role.RoleId,
            Status = WebDataStatus.Active
        });
        dbContext.FunctionRoles.AddRange(
            new WebFunctionRole
            {
                TargetId = role.RoleId,
                FunctionId = parent.FunctionId,
                Type = WebFunctionRoleType.Role,
                ActiveKey = ActiveKeyValue.None,
                Status = WebDataStatus.Active
            },
            new WebFunctionRole
            {
                TargetId = role.RoleId,
                FunctionId = child.FunctionId,
                Type = WebFunctionRoleType.Role,
                ActiveKey = ActiveKeyValue.Set(ActiveKeyValue.None, ActiveKeyPermission.View, true),
                Status = WebDataStatus.Active
            });
        await dbContext.SaveChangesAsync();
        var service = CreateAuthService(dbContext, passwordService);

        var response = await service.GetCurrentUserAsync(user.UserId, CancellationToken.None);

        Assert.Contains(response.Functions, item =>
            item.Id == parent.FunctionId && item.ActiveKey == ActiveKeyValue.None);
        Assert.Contains(response.Functions, item =>
            item.Id == child.FunctionId && item.ParentFunctionId == parent.FunctionId);
    }

    [Fact]
    public async Task LoginAsync_UserBiKhoa_TuChoNgay()
    {
        await using var dbContext = CreateDbContext();
        var passwordService = CreatePasswordService();
        dbContext.Users.Add(new WebUser
        {
            UserId = 11,
            UserName = "locked",
            Password = HashForStorage(passwordService, 11, "Password@123"),
            Status = WebDataStatus.Inactive
        });
        await dbContext.SaveChangesAsync();
        var service = CreateAuthService(dbContext, passwordService);

        await Assert.ThrowsAsync<UnauthorizedException>(() => service.LoginAsync(
            new LoginRequest { UserName = "locked", Password = "Password@123" },
            CancellationToken.None));
    }

    [Fact]
    public async Task LoginAsync_SaiMatKhau_TraLoiXacThucChung()
    {
        await using var dbContext = CreateDbContext();
        var passwordService = CreatePasswordService();
        var correctPassword = Guid.NewGuid().ToString("N");
        dbContext.Users.Add(new WebUser
        {
            UserId = 11,
            UserName = $"user_{Guid.NewGuid():N}",
            Password = HashForStorage(passwordService, 11, correctPassword),
            Status = WebDataStatus.Active
        });
        await dbContext.SaveChangesAsync();
        var service = CreateAuthService(dbContext, passwordService);

        var exception = await Assert.ThrowsAsync<UnauthorizedException>(() => service.LoginAsync(
            new LoginRequest
            {
                UserName = dbContext.Users.Single().UserName,
                Password = Guid.NewGuid().ToString("N")
            },
            CancellationToken.None));

        Assert.DoesNotContain(dbContext.Users.Single().UserName, exception.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task ChangePasswordAsync_XacMinhMatKhauCuVaGhiMd5()
    {
        await using var dbContext = CreateDbContext();
        var passwordService = CreatePasswordService();
        var user = new WebUser
        {
            UserId = 11,
            UserName = "change-password",
            Password = HashForStorage(passwordService, 11, "Old@1234"),
            Status = WebDataStatus.Active
        };
        dbContext.Users.Add(user);
        await dbContext.SaveChangesAsync();
        var service = CreateAuthService(dbContext, passwordService);

        await service.ChangePasswordAsync(11, DateTime.UtcNow, new ChangePasswordRequest
        {
            CurrentPassword = "Old@1234",
            NewPassword = "New@1234"
        }, CancellationToken.None);

        var updated = await dbContext.Users.SingleAsync();
        Assert.True(passwordService.Verify(updated, "New@1234"));
        Assert.NotNull(updated.TokenSince);
        await Assert.ThrowsAsync<ValidationException>(() => service.ChangePasswordAsync(
            11,
            DateTime.UtcNow,
            new ChangePasswordRequest { CurrentPassword = "Old@1234", NewPassword = "Another@123" },
            CancellationToken.None));
    }

    [Fact]
    public async Task LogoutAsync_GhiMocThuHoiPhienVaoTokenSince()
    {
        await using var dbContext = CreateDbContext();
        var passwordService = CreatePasswordService();
        dbContext.Users.Add(new WebUser
        {
            UserId = 11,
            UserName = "logout-user",
            Password = HashForStorage(passwordService, 11, "Password@123"),
            Status = WebDataStatus.Active
        });
        await dbContext.SaveChangesAsync();
        var service = CreateAuthService(dbContext, passwordService);

        var issuedAtUtc = DateTime.UtcNow.AddSeconds(2);
        await service.LogoutAsync(11, issuedAtUtc, CancellationToken.None);

        var user = await dbContext.Users.SingleAsync();
        Assert.NotNull(user.TokenSince);
        Assert.True(VietnamTime.ToUtc(user.TokenSince) >= issuedAtUtc);
        Assert.Equal(11, user.UserEditId);
    }

    private static AuthService CreateAuthService(WebAuthDbContext dbContext, IDatabasePasswordService passwordService) =>
        new(dbContext, passwordService, new JwtTokenService(Options.Create(new JwtOptions
        {
            Issuer = "test",
            Audience = "test",
            SigningKey = "12345678901234567890123456789012",
            AccessTokenMinutes = 30
        })));

    private static DatabasePasswordService CreatePasswordService() =>
        new(Options.Create(new DatabasePasswordOptions { PasswordWriteMode = DatabasePasswordWriteMode.Md5Utf8 }));

    private static string HashForStorage(
        DatabasePasswordService passwordService,
        int userId,
        string password,
        string? keyLock = null,
        string? regEmail = null)
    {
        var user = new WebUser
        {
            UserId = userId,
            Password = DatabasePasswordService.PendingPasswordHash,
            KeyLock = keyLock,
            RegEmail = regEmail
        };
        return passwordService.HashForStorage(user, password);
    }

    private static WebAuthDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<WebAuthDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new WebAuthDbContext(options);
    }
}

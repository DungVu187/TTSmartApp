using System.Security.Claims;
using TTSmart.Api.Data.WebAuth;
using TTSmart.Api.Features.Authorization;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;

namespace TTSmart.Api.Tests;

public sealed class AuthorizationTests
{
    [Fact]
    public async Task Handler_KiemTraDungBitVaCapNhatQuyenNgayLapTuc()
    {
        await using var dbContext = CreateDbContext();
        dbContext.Users.Add(new WebUser { UserId = 11, UserName = "user", Password = "x", Status = WebDataStatus.Active });
        dbContext.Roles.Add(new WebRole { RoleId = 3, Code = "ROLE", Name = "Vai trò", Status = WebDataStatus.Active });
        dbContext.Functions.Add(new WebFunction { FunctionId = 4, Code = "QLND", Name = "Người dùng", Status = WebDataStatus.Active });
        dbContext.UserRoles.Add(new WebUserRole { UserId = 11, RoleId = 3, Status = WebDataStatus.Active });
        var functionRole = new WebFunctionRole
        {
            FunctionRoleId = 10,
            TargetId = 3,
            FunctionId = 4,
            Type = WebFunctionRoleType.Role,
            ActiveKey = "011111111",
            Status = WebDataStatus.Active
        };
        dbContext.FunctionRoles.Add(functionRole);
        await dbContext.SaveChangesAsync();
        var handler = new FunctionAccessHandler(dbContext, new HttpContextAccessor
        {
            HttpContext = new DefaultHttpContext()
        });
        var principal = new ClaimsPrincipal(new ClaimsIdentity(
            [new Claim(ClaimTypes.NameIdentifier, "11")], "test"));

        var viewContext = CreateContext(principal, ActiveKeyPermission.View);
        await handler.HandleAsync(viewContext);
        Assert.False(viewContext.HasSucceeded);

        var createContext = CreateContext(principal, ActiveKeyPermission.Create);
        await handler.HandleAsync(createContext);
        Assert.True(createContext.HasSucceeded);

        functionRole.ActiveKey = "000000000";
        await dbContext.SaveChangesAsync();
        var changedContext = CreateContext(principal, ActiveKeyPermission.Create);
        await handler.HandleAsync(changedContext);
        Assert.False(changedContext.HasSucceeded);
    }

    [Fact]
    public async Task Handler_UserBiKhoa_TuChoQuyenDuDaCoToken()
    {
        await using var dbContext = CreateDbContext();
        dbContext.Users.Add(new WebUser { UserId = 11, UserName = "user", Password = "x", Status = WebDataStatus.Inactive });
        dbContext.Roles.Add(new WebRole { RoleId = 3, Code = "ROLE", Name = "Vai trò", Status = WebDataStatus.Active });
        dbContext.Functions.Add(new WebFunction { FunctionId = 4, Code = "QLND", Name = "Người dùng", Status = WebDataStatus.Active });
        dbContext.UserRoles.Add(new WebUserRole { UserId = 11, RoleId = 3, Status = WebDataStatus.Active });
        dbContext.FunctionRoles.Add(new WebFunctionRole
        {
            TargetId = 3,
            FunctionId = 4,
            Type = WebFunctionRoleType.Role,
            ActiveKey = ActiveKeyValue.Full,
            Status = WebDataStatus.Active
        });
        await dbContext.SaveChangesAsync();
        var handler = new FunctionAccessHandler(dbContext, new HttpContextAccessor
        {
            HttpContext = new DefaultHttpContext()
        });

        var context = CreateContext(
            new ClaimsPrincipal(new ClaimsIdentity(
                [new Claim(ClaimTypes.NameIdentifier, "11")], "test")),
            ActiveKeyPermission.View);
        await handler.HandleAsync(context);

        Assert.False(context.HasSucceeded);
    }

    private static AuthorizationHandlerContext CreateContext(
        ClaimsPrincipal principal,
        ActiveKeyPermission permission) =>
        new(
            [new FunctionAccessRequirement(permission, "QLND")],
            principal,
            null);

    private static WebAuthDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<WebAuthDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new WebAuthDbContext(options);
    }
}

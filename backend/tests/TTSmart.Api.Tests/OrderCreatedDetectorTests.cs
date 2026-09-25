using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using TTSmart.Api.Data.Notifications;
using TTSmart.Api.Data.StationOperations;
using TTSmart.Api.Data.WebAuth;
using TTSmart.Api.Features.Auth;
using TTSmart.Api.Features.Authorization;
using TTSmart.Api.Features.Notifications;

namespace TTSmart.Api.Tests;

public sealed class OrderCreatedDetectorTests
{
    [Fact]
    public async Task RecipientResolver_CompanyRoleWithBranches_OnlyReceivesAuthorizedStations()
    {
        var options = new DbContextOptionsBuilder<WebAuthDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options;
        await using var dbContext = new WebAuthDbContext(options);
        var function = new WebFunction
        {
            FunctionId = 1,
            Code = OperationalFunctionCodes.OrderReports,
            Name = "Báo cáo đơn hàng",
            Status = WebDataStatus.Active
        };
        dbContext.Functions.Add(function);
        dbContext.Roles.AddRange(
            new WebRole { RoleId = 1, Code = SystemRoleCodes.Admin, Name = "Admin", Status = WebDataStatus.Active },
            new WebRole { RoleId = 2, Code = SystemRoleCodes.Company, Name = "Company", Status = WebDataStatus.Active },
            new WebRole { RoleId = 3, Code = "ROLE", Name = "Role", Status = WebDataStatus.Active });
        dbContext.Users.AddRange(
            new WebUser { UserId = 1, UserName = "admin", Status = WebDataStatus.Active },
            new WebUser { UserId = 2, UserName = "limited-company", CompanyId = 10, BranchId = "20, 21", Status = WebDataStatus.Active },
            new WebUser { UserId = 3, UserName = "company-all", CompanyId = 10, BranchId = "invalid", Status = WebDataStatus.Active },
            new WebUser { UserId = 4, UserName = "branch-user", CompanyId = 10, BranchId = "20", Status = WebDataStatus.Active });
        dbContext.UserRoles.AddRange(
            new WebUserRole { UserId = 1, RoleId = 1, Status = WebDataStatus.Active },
            new WebUserRole { UserId = 2, RoleId = 2, Status = WebDataStatus.Active },
            new WebUserRole { UserId = 3, RoleId = 2, Status = WebDataStatus.Active },
            new WebUserRole { UserId = 4, RoleId = 3, Status = WebDataStatus.Active });
        foreach (var roleId in new[] { 1, 2, 3 })
        {
            dbContext.FunctionRoles.Add(new WebFunctionRole
            {
                TargetId = roleId,
                FunctionId = function.FunctionId,
                Type = WebFunctionRoleType.Role,
                ActiveKey = ActiveKeyValue.Set(ActiveKeyValue.None, ActiveKeyPermission.DSach, true),
                Status = WebDataStatus.Active
            });
        }
        await dbContext.SaveChangesAsync();

        var resolver = new NotificationRecipientResolver(dbContext);

        Assert.Equal([1, 2, 3, 4], await resolver.GetOrderRecipientsAsync(10, 20, CancellationToken.None));
        Assert.Equal([1, 3], await resolver.GetOrderRecipientsAsync(10, 99, CancellationToken.None));
    }

    [Fact]
    public async Task BaselineCreatesNoEvents_ThenNewOrdersCreateExactlyOneEventPerStation()
    {
        var options = new DbContextOptionsBuilder<NotificationDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options;
        await using var dbContext = new NotificationDbContext(options);
        var source = new TestOrderCreatedDataSource();
        source.Set(10, [new DetectedOrder(1, null, null), new DetectedOrder(2, null, null)]);
        source.Set(20, [new DetectedOrder(2, null, null)]);
        var detector = new OrderCreatedDetector(
            dbContext, source, new TestRecipientResolver(),
            Options.Create(new NotificationOptions { OrderIdOverlap = 10 }), TimeProvider.System);

        var firstStation = new NotificationStation(10, 1, "Station 10", "unused", 1);
        var secondStation = new NotificationStation(20, 1, "Station 20", "unused", 1);
        Assert.True((await detector.DetectAsync(firstStation, CancellationToken.None)).WasBaseline);
        Assert.Empty(await dbContext.NotificationEvents.ToArrayAsync());

        source.Set(10, [new DetectedOrder(1, null, null), new DetectedOrder(2, null, null), new DetectedOrder(3, null, null)]);
        Assert.Equal(1, (await detector.DetectAsync(firstStation, CancellationToken.None)).CreatedEventCount);
        Assert.Equal(0, (await detector.DetectAsync(firstStation, CancellationToken.None)).CreatedEventCount);

        Assert.True((await detector.DetectAsync(secondStation, CancellationToken.None)).WasBaseline);
        source.Set(20, [new DetectedOrder(2, null, null), new DetectedOrder(3, null, null)]);
        Assert.Equal(1, (await detector.DetectAsync(secondStation, CancellationToken.None)).CreatedEventCount);

        var events = await dbContext.NotificationEvents.OrderBy(item => item.StationId).ToArrayAsync();
        Assert.Equal(2, events.Length);
        Assert.Equal(["10:order.created:3", "20:order.created:3"], events.Select(item => item.DeduplicationKey).ToArray());
        Assert.All(events, item => Assert.Single(item.UserNotifications));
    }

    private sealed class TestRecipientResolver : INotificationRecipientResolver
    {
        public Task<IReadOnlyList<int>> GetOrderRecipientsAsync(int? companyId, int stationId, CancellationToken cancellationToken) =>
            Task.FromResult<IReadOnlyList<int>>([7]);
    }

    private sealed class TestOrderCreatedDataSource : IOrderCreatedDataSource
    {
        private readonly Dictionary<int, IReadOnlyList<DetectedOrder>> orders = [];

        public void Set(int stationId, IReadOnlyList<DetectedOrder> values) => orders[stationId] = values;

        public Task<IReadOnlyList<DetectedOrder>> GetOrdersAsync(
            StationDatabaseTarget target, int minimumOrderId, CancellationToken cancellationToken) =>
            Task.FromResult<IReadOnlyList<DetectedOrder>>(orders[target.BranchId]
                .Where(item => item.OrderId >= minimumOrderId).ToArray());
    }
}

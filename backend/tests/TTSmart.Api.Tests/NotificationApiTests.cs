using System.Net;
using System.Net.Http.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using TTSmart.Api.Data.Notifications;
using TTSmart.Api.Data.Company;
using TTSmart.Api.Data.WebAuth;
using TTSmart.Api.Features.Notifications;

namespace TTSmart.Api.Tests;

public sealed class NotificationApiTests(TTSmartApiFactory factory) : IClassFixture<TTSmartApiFactory>
{
    [Fact]
    public async Task Notifications_ArePrivate_Paginated_AndCanBeMarkedRead()
    {
        BranchTestIdentity first = null!;
        BranchTestIdentity second = null!;
        await factory.ResetDatabaseAsync(async (services, authDbContext) =>
        {
            var companyDbContext = services.GetRequiredService<CompanyDbContext>();
            companyDbContext.Companies.Add(BranchTestSupport.CreateCompany(1, "TEST", "Test Company"));
            await companyDbContext.SaveChangesAsync();
            first = await BranchTestSupport.SeedIdentityAsync(services, authDbContext, "USER_A", 1, "10");
            second = await BranchTestSupport.SeedIdentityAsync(services, authDbContext, "USER_B", 1, "10");
        });
        var userIds = new List<int>();
        await factory.ExecuteDatabaseAsync(async dbContext =>
        {
            userIds.AddRange(await dbContext.Users.OrderBy(item => item.UserId).Select(item => item.UserId).ToArrayAsync());
        });
        await factory.ExecuteNotificationDatabaseAsync(async dbContext =>
        {
            var firstEvent = new NotificationEvent
            {
                EventType = "order.created",
                StationId = 10,
                EntityType = "order",
                EntityId = "101",
                Title = "New order",
                Body = "First",
                DeduplicationKey = "test:1",
                OccurredAtUtc = DateTime.UnixEpoch,
                CreatedAtUtc = DateTime.UnixEpoch
            };
            firstEvent.UserNotifications.Add(new UserNotification { UserId = userIds[0], CreatedAtUtc = DateTime.UnixEpoch });
            var secondEvent = new NotificationEvent
            {
                EventType = "order.created",
                StationId = 20,
                EntityType = "order",
                EntityId = "202",
                Title = "New order",
                Body = "Second",
                DeduplicationKey = "test:2",
                OccurredAtUtc = DateTime.UnixEpoch,
                CreatedAtUtc = DateTime.UnixEpoch
            };
            secondEvent.UserNotifications.Add(new UserNotification { UserId = userIds[1], CreatedAtUtc = DateTime.UnixEpoch });
            dbContext.NotificationEvents.AddRange(firstEvent, secondEvent);
            await dbContext.SaveChangesAsync();
        });

        using var client = factory.CreateClient();
        await BranchTestSupport.LoginAsync(client, first);
        var page = await client.GetFromJsonAsync<NotificationPage>("/api/notifications?pageNumber=1&pageSize=1", BranchTestSupport.JsonOptions);
        Assert.NotNull(page);
        Assert.Single(page.Items);
        Assert.Equal(1, page.TotalCount);
        Assert.Equal("101", page.Items[0].EntityId);
        var unread = await client.GetFromJsonAsync<UnreadNotificationCountResponse>("/api/notifications/unread-count", BranchTestSupport.JsonOptions);
        Assert.Equal(1, unread!.Count);

        var foreignId = 2L;
        Assert.Equal(HttpStatusCode.NotFound, (await client.PostAsync($"/api/notifications/{foreignId}/read", null)).StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, (await client.PostAsync($"/api/notifications/{page.Items[0].Id}/read", null)).StatusCode);
        unread = await client.GetFromJsonAsync<UnreadNotificationCountResponse>("/api/notifications/unread-count", BranchTestSupport.JsonOptions);
        Assert.Equal(0, unread!.Count);
    }

    [Fact]
    public void NotificationDbContext_MapsRequiredUniqueIndexes()
    {
        var options = new DbContextOptionsBuilder<NotificationDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options;
        using var dbContext = new NotificationDbContext(options);
        var eventEntity = dbContext.Model.FindEntityType(typeof(NotificationEvent))!;
        var stateEntity = dbContext.Model.FindEntityType(typeof(NotificationSourceState))!;
        Assert.Contains(eventEntity.GetIndexes(), item => item.IsUnique && item.Properties.Single().Name == nameof(NotificationEvent.DeduplicationKey));
        Assert.Contains(stateEntity.GetIndexes(), item => item.IsUnique && item.Properties.Select(property => property.Name)
            .SequenceEqual([nameof(NotificationSourceState.DetectorType), nameof(NotificationSourceState.StationId), nameof(NotificationSourceState.SourceKey)]));
    }

    private sealed record NotificationPage(IReadOnlyList<NotificationResponse> Items, int TotalCount);
}

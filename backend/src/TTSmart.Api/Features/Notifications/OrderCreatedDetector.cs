using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using TTSmart.Api.Data.Company;
using TTSmart.Api.Data.Notifications;
using TTSmart.Api.Data.StationOperations;
using TTSmart.Api.Data.WebAuth;
using TTSmart.Api.Features.Authorization;

namespace TTSmart.Api.Features.Notifications;

public sealed record NotificationStation(int Id, int? CompanyId, string? Name, string? DatabaseName, int? TypeTram);
public sealed record DetectedOrder(int OrderId, Guid? SourceId, DateTime? OrderedAt);

public interface INotificationStationSource
{
    Task<IReadOnlyList<NotificationStation>> GetActiveMixingStationsAsync(CancellationToken cancellationToken);
}

public sealed class NotificationStationSource(
    CompanyDbContext companyDbContext,
    IOptions<NotificationOptions> options) : INotificationStationSource
{
    public async Task<IReadOnlyList<NotificationStation>> GetActiveMixingStationsAsync(CancellationToken cancellationToken)
    {
        var configuredStationIds = options.Value.StationIds.Distinct().ToArray();
        var query = companyDbContext.Branches.AsNoTracking()
            .Where(item => item.Status == WebDataStatus.Active && item.TypeTram == 1);
        if (configuredStationIds.Length > 0)
        {
            query = query.Where(item => configuredStationIds.Contains(item.BranchId));
        }

        return await query
            .OrderBy(item => item.BranchId)
            .Select(item => new NotificationStation(item.BranchId, item.CompanyId, item.Name, item.Dataname, item.TypeTram))
            .ToArrayAsync(cancellationToken);
    }
}

public interface IOrderCreatedDataSource
{
    Task<IReadOnlyList<DetectedOrder>> GetOrdersAsync(StationDatabaseTarget target, int minimumOrderId, CancellationToken cancellationToken);
}

public sealed class SqlOrderCreatedDataSource(IStationOperationsDbContextFactory dbContextFactory) : IOrderCreatedDataSource
{
    public async Task<IReadOnlyList<DetectedOrder>> GetOrdersAsync(
        StationDatabaseTarget target, int minimumOrderId, CancellationToken cancellationToken)
    {
        await using var dbContext = dbContextFactory.Create(target);
        return await dbContext.Orders.AsNoTracking()
            .Where(item => item.OrderId >= minimumOrderId)
            .OrderBy(item => item.OrderId)
            .Select(item => new DetectedOrder(item.OrderId, item.SourceId, item.OrderedAt))
            .ToArrayAsync(cancellationToken);
    }
}

public interface INotificationRecipientResolver
{
    Task<IReadOnlyList<int>> GetOrderRecipientsAsync(int? companyId, int stationId, CancellationToken cancellationToken);
}

public sealed class NotificationRecipientResolver(WebAuthDbContext authDbContext) : INotificationRecipientResolver
{
    public async Task<IReadOnlyList<int>> GetOrderRecipientsAsync(int? companyId, int stationId, CancellationToken cancellationToken)
    {
        var grants = await (
            from user in authDbContext.Users.AsNoTracking()
            join userRole in authDbContext.UserRoles.AsNoTracking() on user.UserId equals userRole.UserId
            join role in authDbContext.Roles.AsNoTracking() on userRole.RoleId equals role.RoleId
            join functionRole in authDbContext.FunctionRoles.AsNoTracking() on role.RoleId equals functionRole.TargetId
            join function in authDbContext.Functions.AsNoTracking() on functionRole.FunctionId equals function.FunctionId
            where user.Status == WebDataStatus.Active && userRole.Status == WebDataStatus.Active &&
                  role.Status == WebDataStatus.Active && functionRole.Status == WebDataStatus.Active &&
                  functionRole.Type == WebFunctionRoleType.Role && function.Status == WebDataStatus.Active &&
                  function.Code == OperationalFunctionCodes.OrderReports
            select new RecipientGrant(user.UserId, user.CompanyId, user.BranchId, role.Code, functionRole.ActiveKey))
            .ToArrayAsync(cancellationToken);

        return grants.GroupBy(item => item.UserId).Where(group =>
                group.Any(item => ActiveKeyValue.Allows(item.ActiveKey, ActiveKeyPermission.DSach)) &&
                IsInScope(group, companyId, stationId))
            .Select(group => group.Key).OrderBy(item => item).ToArray();
    }

    private static bool IsInScope(IGrouping<int, RecipientGrant> grants, int? companyId, int stationId)
    {
        if (grants.Any(item => item.RoleCode == SystemRoleCodes.Admin)) return true;
        if (!companyId.HasValue) return false;
        var user = grants.First();
        if (user.CompanyId != companyId) return false;
        var branchIds = (user.BranchIds ?? string.Empty).Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Where(value => int.TryParse(value, out _))
            .Select(int.Parse)
            .ToHashSet();
        if (grants.Any(item => item.RoleCode == SystemRoleCodes.Company) && branchIds.Count == 0) return true;
        return branchIds.Contains(stationId);
    }

    private sealed record RecipientGrant(int UserId, int? CompanyId, string? BranchIds, string RoleCode, string? ActiveKey);
}

public sealed record OrderDetectionResult(bool WasBaseline, int ObservedCount, int CreatedEventCount);

public interface IOrderCreatedDetector
{
    Task<OrderDetectionResult> DetectAsync(NotificationStation station, CancellationToken cancellationToken);
}

public sealed class OrderCreatedDetector(
    NotificationDbContext notificationDbContext,
    IOrderCreatedDataSource dataSource,
    INotificationRecipientResolver recipientResolver,
    IOptions<NotificationOptions> options,
    TimeProvider timeProvider) : IOrderCreatedDetector
{
    private const string DetectorType = "order.created";
    private const string SourceKey = "DATHANG";

    public async Task<OrderDetectionResult> DetectAsync(NotificationStation station, CancellationToken cancellationToken)
    {
        var now = timeProvider.GetUtcNow().UtcDateTime;
        var state = await notificationDbContext.NotificationSourceStates.SingleOrDefaultAsync(item =>
            item.DetectorType == DetectorType && item.StationId == station.Id && item.SourceKey == SourceKey, cancellationToken);
        var previousHighWater = state is null || !int.TryParse(state.SourceVersion, out var parsed) ? 0 : parsed;
        var minimumOrderId = state is null ? 0 : Math.Max(0, previousHighWater - options.Value.OrderIdOverlap);
        var orders = await dataSource.GetOrdersAsync(new StationDatabaseTarget(station.Id, station.DatabaseName, station.TypeTram), minimumOrderId, cancellationToken);
        var observedHighWater = orders.Count == 0 ? previousHighWater : Math.Max(previousHighWater, orders.Max(item => item.OrderId));
        if (state is null)
        {
            notificationDbContext.NotificationSourceStates.Add(new NotificationSourceState
            {
                DetectorType = DetectorType,
                StationId = station.Id,
                SourceKey = SourceKey,
                SourceVersion = observedHighWater.ToString(System.Globalization.CultureInfo.InvariantCulture),
                LastObservedAtUtc = now,
                UpdatedAtUtc = now
            });
            await notificationDbContext.SaveChangesAsync(cancellationToken);
            return new OrderDetectionResult(true, orders.Count, 0);
        }

        var candidates = orders.Where(item => item.OrderId > previousHighWater).ToArray();
        var recipients = candidates.Length == 0
            ? []
            : await recipientResolver.GetOrderRecipientsAsync(station.CompanyId, station.Id, cancellationToken);
        var created = 0;
        foreach (var order in candidates)
        {
            var eventEntity = new NotificationEvent
            {
                EventType = DetectorType,
                CompanyId = station.CompanyId,
                StationId = station.Id,
                EntityType = "order",
                EntityId = order.OrderId.ToString(System.Globalization.CultureInfo.InvariantCulture),
                Title = "Có đơn hàng mới",
                Body = $"Trạm {station.Name?.Trim() ?? station.Id.ToString()} vừa có đơn hàng mới DH-{order.OrderId}",
                // DATHANG.NGAYDATHANG is local/nullable without a reliable timezone contract, so it is not exposed as UTC.
                PayloadJson = JsonSerializer.Serialize(new { stationId = station.Id, orderId = order.OrderId }),
                DeduplicationKey = $"{station.Id}:order.created:{order.OrderId}",
                OccurredAtUtc = now,
                CreatedAtUtc = now
            };
            foreach (var recipient in recipients)
            {
                eventEntity.UserNotifications.Add(new UserNotification { UserId = recipient, CreatedAtUtc = now });
            }
            notificationDbContext.NotificationEvents.Add(eventEntity);
            try
            {
                await notificationDbContext.SaveChangesAsync(cancellationToken);
                created++;
            }
            catch (DbUpdateException)
            {
                notificationDbContext.ChangeTracker.Clear();
                var alreadyCreated = await notificationDbContext.NotificationEvents.AnyAsync(
                    item => item.DeduplicationKey == eventEntity.DeduplicationKey, cancellationToken);
                if (!alreadyCreated) throw;
            }
        }
        var currentState = await notificationDbContext.NotificationSourceStates.SingleAsync(item =>
            item.DetectorType == DetectorType && item.StationId == station.Id && item.SourceKey == SourceKey, cancellationToken);
        if (observedHighWater > previousHighWater)
        {
            currentState.SourceVersion = observedHighWater.ToString(System.Globalization.CultureInfo.InvariantCulture);
            currentState.LastObservedAtUtc = now;
            currentState.UpdatedAtUtc = now;
            await notificationDbContext.SaveChangesAsync(cancellationToken);
        }
        return new OrderDetectionResult(false, orders.Count, created);
    }
}

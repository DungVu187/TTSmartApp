using System.Data.Common;
using Microsoft.EntityFrameworkCore;
using TTSmart.Api.Common.Exceptions;
using TTSmart.Api.Data.StationOperations;

namespace TTSmart.Api.Features.OrderReporting;

public sealed record StationOrderReportRow(
    int OrderId,
    string? CustomerName,
    string? ProjectName,
    string? ConcreteGradeName,
    float? OrderedVolume,
    float? ProducedVolume,
    DateTime? OrderedAt,
    string? EmployeeName);

public sealed record StationOrderReportPage(
    IReadOnlyList<StationOrderReportRow> Items,
    int TotalCount,
    double TotalOrderedVolume,
    double TotalProducedVolume);

public sealed record OrderReportDashboardMetrics(
    int OrderCount,
    IReadOnlyList<string> SalesEmployeeKeys);

public interface IOrderReportDataSource
{
    Task<OrderReportDashboardMetrics> GetDashboardMetricsAsync(
        StationDatabaseTarget target,
        DateTime fromLocal,
        DateTime toExclusive,
        CancellationToken cancellationToken);

    Task<IReadOnlyList<string>> GetEmployeeNamesAsync(
        StationDatabaseTarget target,
        DateTime fromLocal,
        DateTime toInclusive,
        CancellationToken cancellationToken);

    Task<StationOrderReportPage> SearchAsync(
        StationDatabaseTarget target,
        DateTime fromLocal,
        DateTime to,
        string? employeeName,
        int pageOffset,
        int pageSize,
        CancellationToken cancellationToken);
}

public sealed class SqlOrderReportDataSource(
    IStationOperationsDbContextFactory dbContextFactory) : IOrderReportDataSource
{
    public Task<OrderReportDashboardMetrics> GetDashboardMetricsAsync(
        StationDatabaseTarget target,
        DateTime fromLocal,
        DateTime toExclusive,
        CancellationToken cancellationToken) =>
        ExecuteAsync(target, async dbContext =>
        {
            var rows = await (
                from order in dbContext.Orders.AsNoTracking()
                join employee in dbContext.Employees.AsNoTracking()
                    on order.EmployeeId equals (int?)employee.EmployeeId into employeeGroup
                from employee in employeeGroup.DefaultIfEmpty()
                where order.OrderedAt >= fromLocal && order.OrderedAt < toExclusive
                select new
                {
                    order.EmployeeId,
                    EmployeeName = employee == null ? null : employee.Name
                })
                .ToListAsync(cancellationToken);

            var employeeKeys = rows
                .Select(row => TrimOrNull(row.EmployeeName) ?? string.Empty)
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToArray();

            return new OrderReportDashboardMetrics(rows.Count, employeeKeys);
        });

    public Task<IReadOnlyList<string>> GetEmployeeNamesAsync(
        StationDatabaseTarget target,
        DateTime fromLocal,
        DateTime toInclusive,
        CancellationToken cancellationToken) =>
        ExecuteAsync(target, async dbContext =>
        {
            var names = await (
                from order in dbContext.Orders.AsNoTracking()
                join employee in dbContext.Employees.AsNoTracking()
                    on order.EmployeeId equals (int?)employee.EmployeeId
                where order.OrderedAt >= fromLocal &&
                    order.OrderedAt <= toInclusive &&
                    employee.Name != null &&
                    employee.Name.Trim() != string.Empty
                select employee.Name!.Trim())
                .Distinct()
                .OrderBy(name => name)
                .ToListAsync(cancellationToken);
            return (IReadOnlyList<string>)names;
        });

    public Task<StationOrderReportPage> SearchAsync(
        StationDatabaseTarget target,
        DateTime fromLocal,
        DateTime to,
        string? employeeName,
        int pageOffset,
        int pageSize,
        CancellationToken cancellationToken) =>
        ExecuteAsync(target, async dbContext =>
        {
            var filteredQuery =
                from order in dbContext.Orders.AsNoTracking()
                join employee in dbContext.Employees.AsNoTracking()
                    on order.EmployeeId equals (int?)employee.EmployeeId into employeeGroup
                from employee in employeeGroup.DefaultIfEmpty()
                where order.OrderedAt >= fromLocal && order.OrderedAt <= to
                select new { Order = order, Employee = employee };

            if (!string.IsNullOrWhiteSpace(employeeName))
            {
                filteredQuery = filteredQuery.Where(row =>
                    row.Employee != null &&
                    row.Employee.Name != null &&
                    row.Employee.Name.Trim() == employeeName);
            }

            var metrics = await filteredQuery
                .GroupBy(_ => 1)
                .Select(group => new
                {
                    TotalCount = group.Count(),
                    TotalOrderedVolume = group.Sum(row =>
                        (double?)(row.Order.OrderedVolume ?? 0)) ?? 0,
                    TotalProducedVolume = group.Sum(row =>
                        (double?)(row.Order.ProducedVolume ?? 0)) ?? 0
                })
                .SingleOrDefaultAsync(cancellationToken);

            var rows = await (
                from row in filteredQuery
                join customer in dbContext.Customers.AsNoTracking()
                    on row.Order.CustomerId equals (int?)customer.CustomerId into customerGroup
                from customer in customerGroup.DefaultIfEmpty()
                join project in dbContext.Projects.AsNoTracking()
                    on row.Order.ProjectId equals (int?)project.ProjectId into projectGroup
                from project in projectGroup.DefaultIfEmpty()
                join concreteGrade in dbContext.ConcreteGrades.AsNoTracking()
                    on row.Order.ConcreteGradeId equals (int?)concreteGrade.ConcreteGradeId into concreteGroup
                from concreteGrade in concreteGroup.DefaultIfEmpty()
                orderby row.Order.OrderedAt descending, row.Order.OrderId descending
                select new
                {
                    row.Order.OrderId,
                    CustomerName = customer == null ? null : customer.Name,
                    ProjectName = project == null ? null : project.Name,
                    ConcreteGradeName = concreteGrade == null ? null : concreteGrade.Name,
                    row.Order.OrderedVolume,
                    row.Order.ProducedVolume,
                    row.Order.OrderedAt,
                    EmployeeName = row.Employee == null ? null : row.Employee.Name
                })
                .Skip(pageOffset)
                .Take(pageSize)
                .ToListAsync(cancellationToken);

            return new StationOrderReportPage(
                rows.Select(row => new StationOrderReportRow(
                    row.OrderId,
                    row.CustomerName,
                    row.ProjectName,
                    row.ConcreteGradeName,
                    row.OrderedVolume,
                    row.ProducedVolume,
                    row.OrderedAt,
                    row.EmployeeName)).ToArray(),
                metrics?.TotalCount ?? 0,
                metrics?.TotalOrderedVolume ?? 0,
                metrics?.TotalProducedVolume ?? 0);
        });

    private async Task<TResult> ExecuteAsync<TResult>(
        StationDatabaseTarget target,
        Func<StationOperationsDbContext, Task<TResult>> operation)
    {
        try
        {
            await using var dbContext = dbContextFactory.Create(target);
            return await operation(dbContext);
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (StationDatabaseConfigurationException exception)
        {
            throw new ServiceUnavailableException(
                "Dữ liệu vận hành của trạm chưa sẵn sàng.",
                exception);
        }
        catch (DbException exception)
        {
            throw new ServiceUnavailableException(
                "Không thể kết nối dữ liệu vận hành của trạm.",
                exception);
        }
        catch (TimeoutException exception)
        {
            throw new ServiceUnavailableException(
                "Không thể kết nối dữ liệu vận hành của trạm.",
                exception);
        }
    }

    private static string? TrimOrNull(string? value)
    {
        var trimmed = value?.Trim();
        return string.IsNullOrEmpty(trimmed) ? null : trimmed;
    }
}

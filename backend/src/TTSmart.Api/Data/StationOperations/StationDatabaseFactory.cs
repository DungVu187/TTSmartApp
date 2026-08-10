using System.Text.RegularExpressions;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using TTSmart.Api.Common.Diagnostics;
using TTSmart.Api.Common.Exceptions;

namespace TTSmart.Api.Data.StationOperations;

public sealed class StationDatabaseOptions
{
    public const string SectionName = "StationDatabase";

    public int CommandTimeoutSeconds { get; init; } = 30;

    public int MaxParallelQueries { get; init; } = 8;

    public Dictionary<int, string> BranchDatabaseOverrides { get; init; } = [];
}

public sealed record StationDatabaseTarget(
    int BranchId,
    string? DatabaseName,
    int? TypeTram = null);

public static class StationDatabaseEnvironmentRules
{
    public static bool AllowBranchDatabaseOverrides(IHostEnvironment environment) =>
        environment.IsDevelopment() ||
        environment.IsEnvironment("Testing") ||
        environment.IsEnvironment("E2E");
}

public interface IStationOperationsDbContextFactory
{
    StationOperationsDbContext Create(StationDatabaseTarget target);

    string ResolveDatabaseName(StationDatabaseTarget target);
}

public sealed class StationOperationsDbContextFactory(
    IConfiguration configuration,
    IOptions<StationDatabaseOptions> options,
    IHostEnvironment environment,
    DatabaseCommandPerformanceInterceptor? commandPerformanceInterceptor = null)
    : IStationOperationsDbContextFactory
{
    private static readonly Regex DatabaseNamePattern =
        new("^[A-Za-z0-9_]{1,128}$", RegexOptions.CultureInvariant | RegexOptions.Compiled);

    public StationOperationsDbContext Create(StationDatabaseTarget target)
    {
        var databaseName = ResolveDatabaseName(target);
        var baseConnectionString = configuration.GetConnectionString("StationConnection");
        if (string.IsNullOrWhiteSpace(baseConnectionString))
        {
            throw new StationDatabaseConfigurationException(
                "Chưa cấu hình kết nối chỉ đọc cho database trạm.");
        }

        try
        {
            var connectionStringBuilder = new SqlConnectionStringBuilder(baseConnectionString)
            {
                InitialCatalog = databaseName,
                ApplicationIntent = ApplicationIntent.ReadOnly
            };
            var optionsBuilder = new DbContextOptionsBuilder<StationOperationsDbContext>()
                .UseSqlServer(
                    connectionStringBuilder.ConnectionString,
                    sqlServerOptions =>
                    {
                        sqlServerOptions.UseCompatibilityLevel(100);
                        sqlServerOptions.CommandTimeout(options.Value.CommandTimeoutSeconds);
                    });
            if (commandPerformanceInterceptor is not null)
            {
                optionsBuilder.AddInterceptors(commandPerformanceInterceptor);
            }

            return new StationOperationsDbContext(optionsBuilder.Options);
        }
        catch (StationDatabaseConfigurationException)
        {
            throw;
        }
        catch (ArgumentException exception)
        {
            throw new StationDatabaseConfigurationException(
                "Cấu hình kết nối database trạm không hợp lệ.",
                exception);
        }
    }

    public string ResolveDatabaseName(StationDatabaseTarget target)
    {
        if (options.Value.BranchDatabaseOverrides.Count > 0 &&
            !StationDatabaseEnvironmentRules.AllowBranchDatabaseOverrides(environment))
        {
            throw new StationDatabaseConfigurationException(
                "Không được cấu hình database override ngoài môi trường Development, Testing hoặc E2E.");
        }

        var hasOverride = options.Value.BranchDatabaseOverrides.TryGetValue(
            target.BranchId,
            out var overrideDatabaseName);
        var databaseName = hasOverride
            ? overrideDatabaseName
            : AddStationDatabaseSuffix(target.DatabaseName, target.TypeTram);
        if (string.IsNullOrWhiteSpace(databaseName) || !DatabaseNamePattern.IsMatch(databaseName.Trim()))
        {
            throw new StationDatabaseConfigurationException(
                "Database vận hành của trạm chưa được cấu hình hợp lệ.");
        }

        return databaseName.Trim();
    }

    private static string? AddStationDatabaseSuffix(string? databaseName, int? typeTram)
    {
        var normalized = databaseName?.Trim();
        if (string.IsNullOrWhiteSpace(normalized))
        {
            return normalized;
        }

        return typeTram switch
        {
            1 when normalized.EndsWith("_online", StringComparison.OrdinalIgnoreCase) => normalized,
            1 => normalized + "_online",
            2 when normalized.EndsWith("_tc_online", StringComparison.OrdinalIgnoreCase) => normalized,
            2 => normalized + "_tc_online",
            _ => normalized
        };
    }
}

public sealed class StationDatabaseConfigurationException(string message, Exception? innerException = null)
    : Exception(message, innerException);

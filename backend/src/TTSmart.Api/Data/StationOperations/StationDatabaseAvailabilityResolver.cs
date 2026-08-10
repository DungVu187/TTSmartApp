using System.Data.Common;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;
using TTSmart.Api.Common.Exceptions;

namespace TTSmart.Api.Data.StationOperations;

public sealed record StationDatabaseAvailabilityResult(
    IReadOnlySet<int> AvailableBranchIds,
    IReadOnlySet<int> UnavailableBranchIds);

public interface IStationDatabaseAvailabilityResolver
{
    Task<StationDatabaseAvailabilityResult> ResolveAsync(
        IReadOnlyList<StationDatabaseTarget> targets,
        CancellationToken cancellationToken);
}

public sealed class SqlStationDatabaseAvailabilityResolver(
    IConfiguration configuration,
    IStationOperationsDbContextFactory dbContextFactory,
    IOptions<StationDatabaseOptions> options) : IStationDatabaseAvailabilityResolver
{
    public async Task<StationDatabaseAvailabilityResult> ResolveAsync(
        IReadOnlyList<StationDatabaseTarget> targets,
        CancellationToken cancellationToken)
    {
        if (targets.Count == 0)
        {
            return new StationDatabaseAvailabilityResult(
                new HashSet<int>(),
                new HashSet<int>());
        }

        var databaseNamesByBranch = new Dictionary<int, string>();
        var unavailableBranchIds = new HashSet<int>();
        foreach (var target in targets)
        {
            try
            {
                databaseNamesByBranch[target.BranchId] =
                    dbContextFactory.ResolveDatabaseName(target);
            }
            catch (StationDatabaseConfigurationException)
            {
                unavailableBranchIds.Add(target.BranchId);
            }
        }

        if (databaseNamesByBranch.Count == 0)
        {
            return new StationDatabaseAvailabilityResult(
                new HashSet<int>(),
                unavailableBranchIds);
        }

        var baseConnectionString = configuration.GetConnectionString("StationConnection");
        if (string.IsNullOrWhiteSpace(baseConnectionString))
        {
            throw new ServiceUnavailableException("Station database catalog is unavailable.");
        }

        try
        {
            var connectionStringBuilder = new SqlConnectionStringBuilder(baseConnectionString)
            {
                InitialCatalog = "master",
                ApplicationIntent = ApplicationIntent.ReadOnly,
                ConnectRetryCount = 0
            };
            await using var connection = new SqlConnection(connectionStringBuilder.ConnectionString);
            await connection.OpenAsync(cancellationToken);
            await using var command = connection.CreateCommand();
            command.CommandText = "SELECT [name] FROM sys.databases WHERE [state] = 0";
            command.CommandTimeout = options.Value.CommandTimeoutSeconds;
            var availableDatabaseNames = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            while (await reader.ReadAsync(cancellationToken))
            {
                availableDatabaseNames.Add(reader.GetString(0));
            }

            var availableBranchIds = new HashSet<int>();
            foreach (var (branchId, databaseName) in databaseNamesByBranch)
            {
                if (availableDatabaseNames.Contains(databaseName))
                {
                    availableBranchIds.Add(branchId);
                }
                else
                {
                    unavailableBranchIds.Add(branchId);
                }
            }

            return new StationDatabaseAvailabilityResult(
                availableBranchIds,
                unavailableBranchIds);
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (DbException exception)
        {
            throw new ServiceUnavailableException(
                "Station database catalog is unavailable.",
                exception);
        }
        catch (TimeoutException exception)
        {
            throw new ServiceUnavailableException(
                "Station database catalog is unavailable.",
                exception);
        }
    }
}
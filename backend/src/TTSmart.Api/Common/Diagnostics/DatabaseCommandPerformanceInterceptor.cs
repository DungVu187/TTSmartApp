using System.Data.Common;
using System.Security.Cryptography;
using System.Text;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.Options;

namespace TTSmart.Api.Common.Diagnostics;

public sealed class DatabaseCommandPerformanceInterceptor(
    ILogger<DatabaseCommandPerformanceInterceptor> logger,
    IHttpContextAccessor httpContextAccessor,
    IOptionsMonitor<PerformanceLoggingOptions> options) : DbCommandInterceptor
{
    public override ValueTask<DbDataReader> ReaderExecutedAsync(
        DbCommand command,
        CommandExecutedEventData eventData,
        DbDataReader result,
        CancellationToken cancellationToken = default)
    {
        LogCompleted(command, eventData);
        return ValueTask.FromResult(result);
    }

    public override ValueTask<object?> ScalarExecutedAsync(
        DbCommand command,
        CommandExecutedEventData eventData,
        object? result,
        CancellationToken cancellationToken = default)
    {
        LogCompleted(command, eventData);
        return ValueTask.FromResult(result);
    }

    public override ValueTask<int> NonQueryExecutedAsync(
        DbCommand command,
        CommandExecutedEventData eventData,
        int result,
        CancellationToken cancellationToken = default)
    {
        LogCompleted(command, eventData);
        return ValueTask.FromResult(result);
    }

    public override void CommandFailed(
        DbCommand command,
        CommandErrorEventData eventData)
    {
        LogFailed(command, eventData);
    }

    public override Task CommandFailedAsync(
        DbCommand command,
        CommandErrorEventData eventData,
        CancellationToken cancellationToken = default)
    {
        LogFailed(command, eventData);
        return Task.CompletedTask;
    }

    private void LogCompleted(DbCommand command, CommandExecutedEventData eventData)
    {
        var settings = options.CurrentValue;
        var elapsedMilliseconds = eventData.Duration.TotalMilliseconds;
        var isSlow = elapsedMilliseconds >= settings.SlowDatabaseCommandThresholdMilliseconds;
        if (!isSlow && !settings.LogAllDatabaseCommands)
        {
            return;
        }

        LogCommand(command, eventData, elapsedMilliseconds, isSlow);
    }

    private void LogCommand(
        DbCommand command,
        CommandExecutedEventData eventData,
        double elapsedMilliseconds,
        bool isSlow)
    {
        var traceId = httpContextAccessor.HttpContext?.TraceIdentifier ?? "background";
        var commandFingerprint = CreateFingerprint(command.CommandText);
        var databaseName = command.Connection?.Database ?? "unknown";
        var contextName = eventData.Context?.GetType().Name ?? "unknown";
        if (isSlow)
        {
            logger.LogWarning(
                "Database command slow. TraceId={TraceId}, DbContext={DbContext}, Database={Database}, ExecuteMethod={ExecuteMethod}, CommandHash={CommandHash}, ElapsedMs={ElapsedMs}",
                traceId,
                contextName,
                databaseName,
                eventData.ExecuteMethod,
                commandFingerprint,
                elapsedMilliseconds);
            return;
        }

        logger.LogInformation(
            "Database command completed. TraceId={TraceId}, DbContext={DbContext}, Database={Database}, ExecuteMethod={ExecuteMethod}, CommandHash={CommandHash}, ElapsedMs={ElapsedMs}",
            traceId,
            contextName,
            databaseName,
            eventData.ExecuteMethod,
            commandFingerprint,
            elapsedMilliseconds);
    }

    private void LogFailed(DbCommand command, CommandErrorEventData eventData)
    {
        var traceId = httpContextAccessor.HttpContext?.TraceIdentifier ?? "background";
        var databaseName = command.Connection?.Database ?? "unknown";
        var contextName = eventData.Context?.GetType().Name ?? "unknown";
        var errorCode = eventData.Exception is DbException databaseException
            ? databaseException.ErrorCode
            : 0;
        logger.LogError(
            "Database command failed. TraceId={TraceId}, DbContext={DbContext}, Database={Database}, ExecuteMethod={ExecuteMethod}, CommandHash={CommandHash}, ElapsedMs={ElapsedMs}, ErrorType={ErrorType}, ErrorCode={ErrorCode}",
            traceId,
            contextName,
            databaseName,
            eventData.ExecuteMethod,
            CreateFingerprint(command.CommandText),
            eventData.Duration.TotalMilliseconds,
            eventData.Exception.GetType().Name,
            errorCode);
    }

    private static string CreateFingerprint(string commandText)
    {
        var hash = SHA256.HashData(Encoding.UTF8.GetBytes(commandText));
        return Convert.ToHexString(hash.AsSpan(0, 6));
    }
}

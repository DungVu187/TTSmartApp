using System.Data;
using TTSmart.Api.Data.WebAuth;
using TTSmart.Api.Features.Authorization;
using Microsoft.EntityFrameworkCore;

namespace TTSmart.Api.Features.AccessManagement;

internal static class AccessManagementSupport
{
    public static string? TrimOrNull(string? value)
    {
        var trimmed = value?.Trim();
        return string.IsNullOrEmpty(trimmed) ? null : trimmed;
    }

    public static DateTime? ToUtc(DateTime? value)
    {
        if (!value.HasValue)
        {
            return null;
        }

        return value.Value.Kind switch
        {
            DateTimeKind.Utc => value.Value,
            DateTimeKind.Local => value.Value.ToUniversalTime(),
            _ => DateTime.SpecifyKind(value.Value, DateTimeKind.Local).ToUniversalTime()
        };
    }

    public static int? NormalizeParent(int? parentId) => parentId is null or 0 ? null : parentId;

    public static byte ResolveStatusFilter(byte? status)
    {
        if (!status.HasValue)
        {
            return WebDataStatus.Active;
        }

        if (status.Value is not WebDataStatus.Active and not WebDataStatus.Inactive)
        {
            throw new System.ComponentModel.DataAnnotations.ValidationException(
                "Status chỉ nhận giá trị 1 hoặc 99.");
        }

        return status.Value;
    }

    public static bool RequireIsActive(bool? isActive) =>
        isActive ?? throw new System.ComponentModel.DataAnnotations.ValidationException(
            "Trạng thái hiệu lực là bắt buộc.");

    public static PermissionResponse ToPermissions(string? activeKey)
    {
        var key = ActiveKeyValue.Normalize(activeKey);
        return new PermissionResponse(
            ActiveKeyValue.Allows(key, ActiveKeyPermission.View),
            ActiveKeyValue.Allows(key, ActiveKeyPermission.Create),
            ActiveKeyValue.Allows(key, ActiveKeyPermission.Update),
            ActiveKeyValue.Allows(key, ActiveKeyPermission.Delete),
            ActiveKeyValue.Allows(key, ActiveKeyPermission.Import),
            ActiveKeyValue.Allows(key, ActiveKeyPermission.Export),
            ActiveKeyValue.Allows(key, ActiveKeyPermission.Print),
            ActiveKeyValue.Allows(key, ActiveKeyPermission.Other),
            ActiveKeyValue.Allows(key, ActiveKeyPermission.DSach),
            ActiveKeyValue.IsFull(key));
    }

    public static async Task<TResult> ExecuteInTransactionAsync<TResult>(
        WebAuthDbContext dbContext,
        Func<Task<TResult>> operation,
        CancellationToken cancellationToken,
        IsolationLevel isolationLevel = IsolationLevel.ReadCommitted)
    {
        if (!dbContext.Database.IsRelational() || dbContext.Database.CurrentTransaction is not null)
        {
            return await operation();
        }

        await using var transaction = await dbContext.Database.BeginTransactionAsync(
            isolationLevel,
            cancellationToken);
        try
        {
            var result = await operation();
            await transaction.CommitAsync(cancellationToken);
            return result;
        }
        catch
        {
            await transaction.RollbackAsync(cancellationToken);
            throw;
        }
    }

    public static async Task ExecuteInTransactionAsync(
        WebAuthDbContext dbContext,
        Func<Task> operation,
        CancellationToken cancellationToken,
        IsolationLevel isolationLevel = IsolationLevel.ReadCommitted)
    {
        await ExecuteInTransactionAsync(
            dbContext,
            async () =>
            {
                await operation();
                return true;
            },
            cancellationToken,
            isolationLevel);
    }
}

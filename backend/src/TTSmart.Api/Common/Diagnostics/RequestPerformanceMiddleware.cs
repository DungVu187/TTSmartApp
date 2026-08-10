using System.Diagnostics;
using Microsoft.Extensions.Options;

namespace TTSmart.Api.Common.Diagnostics;

public sealed class RequestPerformanceMiddleware(
    RequestDelegate next,
    ILogger<RequestPerformanceMiddleware> logger,
    IOptionsMonitor<PerformanceLoggingOptions> options)
{
    public async Task InvokeAsync(HttpContext httpContext)
    {
        if (options.CurrentValue.LogRequestStart)
        {
            logger.LogInformation(
                "HTTP started. TraceId={TraceId}, Method={Method}, Path={Path}",
                httpContext.TraceIdentifier,
                httpContext.Request.Method,
                httpContext.Request.Path);
        }

        var stopwatch = Stopwatch.StartNew();
        try
        {
            await next(httpContext);
        }
        finally
        {
            stopwatch.Stop();
            LogCompleted(httpContext, stopwatch.ElapsedMilliseconds);
        }
    }

    private void LogCompleted(HttpContext httpContext, long elapsedMilliseconds)
    {
        var settings = options.CurrentValue;
        var canceled = httpContext.RequestAborted.IsCancellationRequested;
        if (canceled || elapsedMilliseconds >= settings.SlowRequestThresholdMilliseconds)
        {
            logger.LogWarning(
                "HTTP completed slowly. TraceId={TraceId}, Method={Method}, Path={Path}, StatusCode={StatusCode}, ElapsedMs={ElapsedMs}, Canceled={Canceled}",
                httpContext.TraceIdentifier,
                httpContext.Request.Method,
                httpContext.Request.Path,
                httpContext.Response.StatusCode,
                elapsedMilliseconds,
                canceled);
            return;
        }

        if (!settings.LogRequestStart)
        {
            return;
        }

        logger.LogInformation(
            "HTTP completed. TraceId={TraceId}, Method={Method}, Path={Path}, StatusCode={StatusCode}, ElapsedMs={ElapsedMs}, Canceled={Canceled}",
            httpContext.TraceIdentifier,
            httpContext.Request.Method,
            httpContext.Request.Path,
            httpContext.Response.StatusCode,
            elapsedMilliseconds,
            canceled);
    }
}

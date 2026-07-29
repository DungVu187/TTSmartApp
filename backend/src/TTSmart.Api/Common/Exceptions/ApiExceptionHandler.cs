using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;

namespace TTSmart.Api.Common.Exceptions;

public sealed class ApiExceptionHandler(
    IProblemDetailsService problemDetailsService,
    ILogger<ApiExceptionHandler> logger) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        var (statusCode, title, detail) = exception switch
        {
            UnauthorizedException => (
                StatusCodes.Status401Unauthorized,
                "Không thể xác thực",
                exception.Message),
            ForbiddenException => (
                StatusCodes.Status403Forbidden,
                "Không có quyền",
                exception.Message),
            ValidationException => (
                StatusCodes.Status400BadRequest,
                "Dữ liệu không hợp lệ",
                exception.Message),
            NotFoundException => (
                StatusCodes.Status404NotFound,
                "Không tìm thấy dữ liệu",
                exception.Message),
            ConflictException => (
                StatusCodes.Status409Conflict,
                "Dữ liệu bị xung đột",
                exception.Message),
            _ => (
                StatusCodes.Status500InternalServerError,
                "Lỗi hệ thống",
                "Đã xảy ra lỗi ngoài dự kiến. Vui lòng thử lại sau.")
        };

        if (statusCode == StatusCodes.Status500InternalServerError)
        {
            logger.LogError(exception, "Lỗi chưa được xử lý khi gọi {Method} {Path}",
                httpContext.Request.Method,
                httpContext.Request.Path);
        }

        httpContext.Response.StatusCode = statusCode;

        return await problemDetailsService.TryWriteAsync(new ProblemDetailsContext
        {
            HttpContext = httpContext,
            Exception = exception,
            ProblemDetails = new ProblemDetails
            {
                Status = statusCode,
                Title = title,
                Detail = detail,
                Instance = httpContext.Request.Path
            }
        });
    }
}

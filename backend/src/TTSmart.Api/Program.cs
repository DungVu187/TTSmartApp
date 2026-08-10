using System.IdentityModel.Tokens.Jwt;
using System.Text;
using System.Text.Json;
using TTSmart.Api.Common.Diagnostics;
using TTSmart.Api.Common.Exceptions;
using TTSmart.Api.Common.OpenApi;
using TTSmart.Api.Common.Security;
using TTSmart.Api.Common.Time;
using TTSmart.Api.Data.Company;
using TTSmart.Api.Data.StationOperations;
using TTSmart.Api.Data.WebAuth;
using TTSmart.Api.Features.AccessManagement;
using TTSmart.Api.Features.Auth;
using TTSmart.Api.Features.Authorization;
using TTSmart.Api.Features.CompanyManagement;
using TTSmart.Api.Features.BranchManagement;
using TTSmart.Api.Features.OrderReporting;
using TTSmart.Api.Features.OrderStatistics;
using TTSmart.Api.Features.MixDesignManagement;
using TTSmart.Api.Features.WeighStationManagement;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

builder.Services
    .AddOptions<PerformanceLoggingOptions>()
    .Bind(builder.Configuration.GetSection(PerformanceLoggingOptions.SectionName))
    .Validate(
        options => options.SlowRequestThresholdMilliseconds is >= 0 and <= 600000,
        "PerformanceLogging:SlowRequestThresholdMilliseconds phải từ 0 đến 600000.")
    .Validate(
        options => options.SlowDatabaseCommandThresholdMilliseconds is >= 0 and <= 600000,
        "PerformanceLogging:SlowDatabaseCommandThresholdMilliseconds phải từ 0 đến 600000.")
    .ValidateOnStart();
builder.Services.AddSingleton<DatabaseCommandPerformanceInterceptor>();
builder.Services.AddProblemDetails(options =>
{
    options.CustomizeProblemDetails = context =>
    {
        context.ProblemDetails.Extensions["traceId"] = context.HttpContext.TraceIdentifier;
    };
});
builder.Services.AddExceptionHandler<ApiExceptionHandler>();
builder.Services.AddDbContext<WebAuthDbContext>((serviceProvider, options) =>
{
    var connectionString = serviceProvider.GetRequiredService<IConfiguration>()
        .GetConnectionString("AuthConnection")
        ?? throw new InvalidOperationException("Chưa cấu hình ConnectionStrings:AuthConnection.");
    options.UseSqlServer(connectionString, sqlServerOptions =>
    {
        sqlServerOptions.UseCompatibilityLevel(120);
    });
    options.AddInterceptors(
        serviceProvider.GetRequiredService<DatabaseCommandPerformanceInterceptor>());
});
builder.Services.AddDbContext<CompanyDbContext>((serviceProvider, options) =>
{
    var connectionString = serviceProvider.GetRequiredService<IConfiguration>()
        .GetConnectionString("AuthConnection")
        ?? throw new InvalidOperationException("Chưa cấu hình ConnectionStrings:AuthConnection.");
    options.UseSqlServer(connectionString, sqlServerOptions =>
    {
        sqlServerOptions.UseCompatibilityLevel(120);
    });
    options.AddInterceptors(
        serviceProvider.GetRequiredService<DatabaseCommandPerformanceInterceptor>());
});
builder.Services
    .AddOptions<JwtOptions>()
    .Bind(builder.Configuration.GetSection(JwtOptions.SectionName))
    .Validate(options => !string.IsNullOrWhiteSpace(options.Issuer), "Jwt:Issuer là bắt buộc.")
    .Validate(options => !string.IsNullOrWhiteSpace(options.Audience), "Jwt:Audience là bắt buộc.")
    .Validate(options => options.SigningKey.Length >= 32, "Jwt:SigningKey phải có ít nhất 32 ký tự.")
    .Validate(options => options.AccessTokenMinutes > 0, "Jwt:AccessTokenMinutes phải lớn hơn 0.")
    .ValidateOnStart();
builder.Services
    .AddOptions<DatabasePasswordOptions>()
    .Bind(builder.Configuration.GetSection(DatabasePasswordOptions.SectionName))
    .Validate(options => Enum.IsDefined(options.PasswordWriteMode), "AuthDatabase:PasswordWriteMode không hợp lệ.")
    .ValidateOnStart();
builder.Services
    .AddOptions<UserAccountStatusOptions>()
    .Bind(builder.Configuration.GetSection(UserAccountStatusOptions.SectionName));
builder.Services
    .AddOptions<CompanyAccessOptions>()
    .Bind(builder.Configuration.GetSection(CompanyAccessOptions.SectionName));
builder.Services
    .AddOptions<CompanyDatabaseOptions>()
    .Bind(builder.Configuration.GetSection(CompanyDatabaseOptions.SectionName));
builder.Services
    .AddOptions<CompanyManagementOptions>()
    .Bind(builder.Configuration.GetSection(CompanyManagementOptions.SectionName));
builder.Services
    .AddOptions<StationDatabaseOptions>()
    .Bind(builder.Configuration.GetSection(StationDatabaseOptions.SectionName))
    .Validate(options => options.CommandTimeoutSeconds is > 0 and <= 300,
        "StationDatabase:CommandTimeoutSeconds phải từ 1 đến 300.")
    .Validate(options => options.MaxParallelQueries is > 0 and <= 32,
        "StationDatabase:MaxParallelQueries phải từ 1 đến 32.")
    .Validate(options => options.BranchDatabaseOverrides.Count == 0 ||
            StationDatabaseEnvironmentRules.AllowBranchDatabaseOverrides(builder.Environment),
        "StationDatabase:BranchDatabaseOverrides chỉ được dùng trong Development, Testing hoặc E2E.")
    .ValidateOnStart();
builder.Services.AddScoped<IDatabasePasswordService, DatabasePasswordService>();
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<IUserAdministrationService, UserAdministrationService>();
builder.Services.AddScoped<IRoleAdministrationService, RoleAdministrationService>();
builder.Services.AddScoped<IFunctionAdministrationService, FunctionAdministrationService>();
builder.Services.AddScoped<ICompanyManagementService, CompanyManagementService>();
builder.Services.AddScoped<IBranchManagementService, BranchManagementService>();
builder.Services.AddScoped<IBranchAccessResolver, BranchAccessResolver>();
builder.Services.AddScoped<IStationOperationsDbContextFactory, StationOperationsDbContextFactory>();
builder.Services.AddScoped<IStationDatabaseAvailabilityResolver, SqlStationDatabaseAvailabilityResolver>();
builder.Services.AddScoped<IOrderReportDataSource, SqlOrderReportDataSource>();
builder.Services.AddScoped<IOrderReportService, OrderReportService>();
builder.Services.AddScoped<IOrderStatisticsDataSource, SqlOrderStatisticsDataSource>();
builder.Services.AddScoped<IOrderStatisticsService, OrderStatisticsService>();
builder.Services.AddScoped<IOrderStatisticsExportService, OrderStatisticsExportService>();
builder.Services.AddScoped<IMixDesignDataSource, SqlMixDesignDataSource>();
builder.Services.AddScoped<IMixDesignService, MixDesignService>();
builder.Services.AddScoped<IWeighStationDataSource, SqlWeighStationDataSource>();
builder.Services.AddScoped<IWeighStationService, WeighStationService>();
builder.Services.AddScoped<IWeighStationExportService, WeighStationExportService>();
builder.Services.AddScoped<ICompanyAccessEvaluator, CompanyAccessEvaluator>();
builder.Services.AddScoped<ISystemRoleEvaluator, SystemRoleEvaluator>();
builder.Services.AddSingleton<ICompanyLogoStorage, LocalCompanyLogoStorage>();
builder.Services.AddSingleton<IJwtTokenService, JwtTokenService>();
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<IAuthorizationHandler, FunctionAccessHandler>();
builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer();
builder.Services
    .AddOptions<JwtBearerOptions>(JwtBearerDefaults.AuthenticationScheme)
    .Configure<IOptions<JwtOptions>>((options, jwtOptionsAccessor) =>
    {
        var jwtOptions = jwtOptionsAccessor.Value;
        options.MapInboundClaims = false;
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = jwtOptions.Issuer,
            ValidateAudience = true,
            ValidAudience = jwtOptions.Audience,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtOptions.SigningKey)),
            ValidateLifetime = true,
            ClockSkew = TimeSpan.FromMinutes(1),
            NameClaimType = JwtRegisteredClaimNames.UniqueName,
            RoleClaimType = "role"
        };
        options.Events = new JwtBearerEvents
        {
            OnAuthenticationFailed = context =>
            {
                var logger = context.HttpContext.RequestServices
                    .GetRequiredService<ILoggerFactory>()
                    .CreateLogger("JwtAuthentication");
                logger.LogWarning(context.Exception, "JWT validation failed.");
                return Task.CompletedTask;
            },
            OnTokenValidated = async context =>
            {
                if (context.Principal is null || !context.Principal.TryGetUserId(out var userId))
                {
                    context.Fail("Token đăng nhập không hợp lệ.");
                    return;
                }

                var authDbContext = context.HttpContext.RequestServices.GetRequiredService<WebAuthDbContext>();
                var user = await authDbContext.Users.AsNoTracking().SingleOrDefaultAsync(
                    user => user.UserId == userId && user.Status == WebDataStatus.Active,
                    context.HttpContext.RequestAborted);
                if (user is null)
                {
                    context.HttpContext.Items[AuthenticationFailureContext.DetailItemKey] =
                        "Phiên đăng nhập không còn hợp lệ.";
                    context.Fail("Phiên đăng nhập không còn hợp lệ.");
                    return;
                }

                if (!context.Principal.TryGetIssuedAtUtc(out var issuedAtUtc))
                {
                    context.HttpContext.Items[AuthenticationFailureContext.DetailItemKey] =
                        "Token đăng nhập thiếu thời điểm phát hành hợp lệ.";
                    context.Fail("Token đăng nhập không hợp lệ.");
                    return;
                }

                var tokenSinceUtc = VietnamTime.ToUtc(user.TokenSince);
                if (tokenSinceUtc.HasValue && issuedAtUtc <= tokenSinceUtc.Value)
                {
                    context.HttpContext.Items[AuthenticationFailureContext.DetailItemKey] =
                        AuthenticationFailureContext.SessionRevokedMessage;
                    context.HttpContext.Items[AuthenticationFailureContext.CodeItemKey] =
                        AuthenticationFailureContext.SessionRevokedCode;
                    context.Fail(AuthenticationFailureContext.SessionRevokedMessage);
                    return;
                }

                var companyAccessEvaluator = context.HttpContext.RequestServices
                    .GetRequiredService<ICompanyAccessEvaluator>();
                var companyAccess = await companyAccessEvaluator.EvaluateAsync(
                    user,
                    context.HttpContext.RequestAborted);
                if (!companyAccess.IsAllowed)
                {
                    context.HttpContext.Items[AuthenticationFailureContext.DetailItemKey] = companyAccess.Message;
                    context.HttpContext.Items[AuthenticationFailureContext.CodeItemKey] = companyAccess.ErrorCode;
                    context.Fail(companyAccess.Message ?? "Công ty không được phép sử dụng dịch vụ.");
                }
            },
            OnChallenge = async context =>
            {
                context.HandleResponse();
                var detail = context.HttpContext.Items[AuthenticationFailureContext.DetailItemKey] as string
                    ?? "Yêu cầu cần có phiên đăng nhập hợp lệ.";
                var errorCode = context.HttpContext.Items[AuthenticationFailureContext.CodeItemKey] as string;
                await WriteAuthorizationProblemAsync(
                    context.HttpContext,
                    StatusCodes.Status401Unauthorized,
                    "Chưa xác thực",
                    detail,
                    errorCode);
            },
            OnForbidden = async context =>
            {
                await WriteAuthorizationProblemAsync(
                    context.HttpContext,
                    StatusCodes.Status403Forbidden,
                    "Không có quyền",
                    "Tài khoản không có quyền thực hiện thao tác này.");
            }
        };
    });
builder.Services.AddAuthorization(options =>
{
    AddPolicy(options, AccessPolicies.UsersList, ActiveKeyPermission.DSach, ManagementFunctionCodes.Users);
    AddPolicy(options, AccessPolicies.UsersRead, ActiveKeyPermission.View, ManagementFunctionCodes.Users);
    AddPolicy(options, AccessPolicies.UsersCreate, ActiveKeyPermission.Create, ManagementFunctionCodes.Users);
    AddPolicy(options, AccessPolicies.UsersUpdate, ActiveKeyPermission.Update, ManagementFunctionCodes.Users);
    AddPolicy(options, AccessPolicies.UsersDelete, ActiveKeyPermission.Delete, ManagementFunctionCodes.Users);
    AddPolicy(options, AccessPolicies.RolesList, ActiveKeyPermission.DSach, ManagementFunctionCodes.Roles);
    AddPolicy(options, AccessPolicies.RolesRead, ActiveKeyPermission.View, ManagementFunctionCodes.Roles);
    AddPolicy(options, AccessPolicies.RolesCreate, ActiveKeyPermission.Create, ManagementFunctionCodes.Roles);
    AddPolicy(options, AccessPolicies.RolesUpdate, ActiveKeyPermission.Update, ManagementFunctionCodes.Roles);
    AddPolicy(options, AccessPolicies.RolesDelete, ActiveKeyPermission.Delete, ManagementFunctionCodes.Roles);
    AddPolicy(options, AccessPolicies.FunctionsList, ActiveKeyPermission.DSach, ManagementFunctionCodes.Functions);
    AddPolicy(options, AccessPolicies.FunctionsRead, ActiveKeyPermission.View, ManagementFunctionCodes.Functions);
    AddPolicy(options, AccessPolicies.FunctionsCreate, ActiveKeyPermission.Create, ManagementFunctionCodes.Functions);
    AddPolicy(options, AccessPolicies.FunctionsUpdate, ActiveKeyPermission.Update, ManagementFunctionCodes.Functions);
    AddPolicy(options, AccessPolicies.FunctionsDelete, ActiveKeyPermission.Delete, ManagementFunctionCodes.Functions);
    AddPolicy(options, AccessPolicies.CompaniesList, ActiveKeyPermission.DSach, ManagementFunctionCodes.Companies);
    AddPolicy(options, AccessPolicies.CompaniesRead, ActiveKeyPermission.View, ManagementFunctionCodes.Companies);
    AddPolicy(options, AccessPolicies.CompaniesCreate, ActiveKeyPermission.Create, ManagementFunctionCodes.Companies);
    AddPolicy(options, AccessPolicies.CompaniesUpdate, ActiveKeyPermission.Update, ManagementFunctionCodes.Companies);
    AddPolicy(options, AccessPolicies.CompaniesDelete, ActiveKeyPermission.Delete, ManagementFunctionCodes.Companies);
    AddPolicy(options, AccessPolicies.BranchesList, ActiveKeyPermission.DSach, ManagementFunctionCodes.Branches);
    AddPolicy(options, AccessPolicies.BranchesRead, ActiveKeyPermission.View, ManagementFunctionCodes.Branches);
    AddPolicy(options, AccessPolicies.BranchesCreate, ActiveKeyPermission.Create, ManagementFunctionCodes.Branches);
    AddPolicy(options, AccessPolicies.BranchesUpdate, ActiveKeyPermission.Update, ManagementFunctionCodes.Branches);
    AddPolicy(options, AccessPolicies.BranchesDelete, ActiveKeyPermission.Delete, ManagementFunctionCodes.Branches);
    AddPolicy(options, AccessPolicies.OrderReportsList, ActiveKeyPermission.DSach, OperationalFunctionCodes.OrderReports);
    AddPolicy(
        options,
        AccessPolicies.OrderStatisticsList,
        ActiveKeyPermission.DSach,
        OperationalFunctionCodes.OrderStatistics,
        allowSuperAdminBypass: false);
    AddPolicy(
        options,
        AccessPolicies.OrderStatisticsExport,
        ActiveKeyPermission.Export,
        OperationalFunctionCodes.OrderStatistics,
        allowSuperAdminBypass: false);
    AddPolicy(
        options,
        AccessPolicies.MixDesignsList,
        ActiveKeyPermission.DSach,
        OperationalFunctionCodes.MixDesigns,
        allowSuperAdminBypass: false);
    AddPolicy(
        options,
        AccessPolicies.WeighStationsList,
        ActiveKeyPermission.DSach,
        OperationalFunctionCodes.WeighStations,
        allowSuperAdminBypass: false);
    AddPolicy(
        options,
        AccessPolicies.WeighStationsExport,
        ActiveKeyPermission.Export,
        OperationalFunctionCodes.WeighStations,
        allowSuperAdminBypass: false);
    AddPolicy(
        options,
        AccessPolicies.WeighStationsPrice,
        ActiveKeyPermission.Other,
        OperationalFunctionCodes.WeighStations,
        allowSuperAdminBypass: false);
});
builder.Services
    .AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.CamelCase;
        options.JsonSerializerOptions.DictionaryKeyPolicy = JsonNamingPolicy.CamelCase;
    });
builder.Services.AddOpenApi(options =>
{
    options.AddDocumentTransformer<BearerSecuritySchemeTransformer>();
    options.AddOperationTransformer<AuthOperationTransformer>();
});

var app = builder.Build();
app.UseMiddleware<RequestPerformanceMiddleware>();
app.UseExceptionHandler();
app.UseAuthentication();
app.UseAuthorization();
if (app.Environment.IsDevelopment() || app.Environment.IsEnvironment("Testing"))
{
    app.MapOpenApi();
}

app.MapControllers();
app.Run();

static void AddPolicy(
    AuthorizationOptions options,
    string policyName,
    ActiveKeyPermission permission,
    string functionCode,
    bool allowSuperAdminBypass = true)
{
    options.AddPolicy(policyName, policy =>
    {
        policy.RequireAuthenticatedUser();
        policy.AddRequirements(new FunctionAccessRequirement(
            permission,
            allowSuperAdminBypass,
            functionCode));
    });
}

static async Task WriteAuthorizationProblemAsync(
    HttpContext httpContext,
    int statusCode,
    string title,
    string detail,
    string? errorCode = null)
{
    if (httpContext.Response.HasStarted)
    {
        return;
    }

    httpContext.Response.StatusCode = statusCode;
    var problemDetailsService = httpContext.RequestServices.GetRequiredService<IProblemDetailsService>();
    var problemDetails = new ProblemDetails
    {
        Status = statusCode,
        Title = title,
        Detail = detail,
        Instance = httpContext.Request.Path
    };
    if (!string.IsNullOrWhiteSpace(errorCode))
    {
        problemDetails.Extensions["code"] = errorCode;
    }

    await problemDetailsService.TryWriteAsync(new ProblemDetailsContext
    {
        HttpContext = httpContext,
        ProblemDetails = problemDetails
    });
}

public partial class Program
{
}

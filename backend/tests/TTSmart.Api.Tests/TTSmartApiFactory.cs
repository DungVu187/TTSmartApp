using System.Security.Cryptography;
using TTSmart.Api.Data.Company;
using TTSmart.Api.Data.StationOperations;
using TTSmart.Api.Data.WebAuth;
using TTSmart.Api.Features.OrderReporting;
using TTSmart.Api.Features.OrderStatistics;
using TTSmart.Api.Features.MixDesignManagement;
using TTSmart.Api.Features.WeighStationManagement;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Logging;

namespace TTSmart.Api.Tests;

public class TTSmartApiFactory : WebApplicationFactory<Program>
{
    private readonly string authDatabaseName = $"ttsmart-auth-http-tests-{Guid.NewGuid():N}";
    private readonly string companyDatabaseName = $"ttsmart-company-http-tests-{Guid.NewGuid():N}";
    private readonly string signingKey = Convert.ToBase64String(RandomNumberGenerator.GetBytes(48));
    internal TestOrderReportDataSource OrderReportDataSource { get; } = new();
    internal TestOrderStatisticsDataSource OrderStatisticsDataSource { get; } = new();
    internal TestMixDesignDataSource MixDesignDataSource { get; } = new();
    internal TestWeighStationDataSource WeighStationDataSource { get; } = new();
    internal TestStationDatabaseAvailabilityResolver StationDatabaseAvailabilityResolver { get; } = new();

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.ConfigureLogging(logging =>
        {
            logging.ClearProviders();
            logging.AddConsole();
        });
        builder.ConfigureAppConfiguration((_, configuration) =>
        {
            configuration.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["ConnectionStrings:AuthConnection"] = "Server=(local);Database=unused;Trusted_Connection=True;",
                ["Jwt:Issuer"] = "TTSmart.Api.Tests",
                ["Jwt:Audience"] = "TTSmart.Api.Tests.Client",
                ["Jwt:SigningKey"] = signingKey,
                ["Jwt:AccessTokenMinutes"] = "15"
            });
        });
        builder.ConfigureServices(services =>
        {
            services.AddDataProtection().UseEphemeralDataProtectionProvider();
            services.RemoveAll<WebAuthDbContext>();
            services.RemoveAll<DbContextOptions<WebAuthDbContext>>();
            services.RemoveAll<IDbContextOptionsConfiguration<WebAuthDbContext>>();
            services.AddDbContext<WebAuthDbContext>(options =>
                options.UseInMemoryDatabase(authDatabaseName));
            services.RemoveAll<CompanyDbContext>();
            services.RemoveAll<DbContextOptions<CompanyDbContext>>();
            services.RemoveAll<IDbContextOptionsConfiguration<CompanyDbContext>>();
            services.AddDbContext<CompanyDbContext>(options =>
                options.UseInMemoryDatabase(companyDatabaseName));
            services.RemoveAll<IOrderReportDataSource>();
            services.AddSingleton<IOrderReportDataSource>(OrderReportDataSource);
            services.RemoveAll<IOrderStatisticsDataSource>();
            services.AddSingleton<IOrderStatisticsDataSource>(OrderStatisticsDataSource);
            services.RemoveAll<IMixDesignDataSource>();
            services.AddSingleton<IMixDesignDataSource>(MixDesignDataSource);
            services.RemoveAll<IWeighStationDataSource>();
            services.AddSingleton<IWeighStationDataSource>(WeighStationDataSource);
            services.RemoveAll<IStationDatabaseAvailabilityResolver>();
            services.AddSingleton<IStationDatabaseAvailabilityResolver>(StationDatabaseAvailabilityResolver);
        });
    }

    public async Task ResetDatabaseAsync(
        Func<IServiceProvider, WebAuthDbContext, Task>? seed = null)
    {
        using var scope = Services.CreateScope();
        var authDbContext = scope.ServiceProvider.GetRequiredService<WebAuthDbContext>();
        var companyDbContext = scope.ServiceProvider.GetRequiredService<CompanyDbContext>();
        await authDbContext.Database.EnsureDeletedAsync();
        await companyDbContext.Database.EnsureDeletedAsync();
        await authDbContext.Database.EnsureCreatedAsync();
        await companyDbContext.Database.EnsureCreatedAsync();
        OrderReportDataSource.Reset();
        OrderStatisticsDataSource.Reset();
        MixDesignDataSource.Reset();
        WeighStationDataSource.Reset();
        StationDatabaseAvailabilityResolver.Reset();
        if (seed is not null)
        {
            await seed(scope.ServiceProvider, authDbContext);
        }
    }

    public async Task ExecuteDatabaseAsync(Func<WebAuthDbContext, Task> operation)
    {
        using var scope = Services.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<WebAuthDbContext>();
        await operation(dbContext);
    }

    public async Task ExecuteCompanyDatabaseAsync(Func<CompanyDbContext, Task> operation)
    {
        using var scope = Services.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<CompanyDbContext>();
        await operation(dbContext);
    }

}

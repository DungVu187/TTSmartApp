using System.Security.Cryptography;
using TTSmart.Api.Data.Company;
using TTSmart.Api.Data.WebAuth;
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

public sealed class TTSmartApiFactory : WebApplicationFactory<Program>
{
    private readonly string authDatabaseName = $"ttsmart-auth-http-tests-{Guid.NewGuid():N}";
    private readonly string companyDatabaseName = $"ttsmart-company-http-tests-{Guid.NewGuid():N}";
    private readonly string signingKey = Convert.ToBase64String(RandomNumberGenerator.GetBytes(48));

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

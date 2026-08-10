using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using TTSmart.Api.Data.StationOperations;
using TTSmart.Api.Features.OrderReporting;

namespace TTSmart.Api.Tests;

internal sealed class SqlOrderReportApiFactory(
    string? stationConnection = null,
    bool mapSampleDatabase = false) : TTSmartApiFactory
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        base.ConfigureWebHost(builder);
        builder.ConfigureAppConfiguration((_, configuration) =>
        {
            var settings = new Dictionary<string, string?>();
            if (!string.IsNullOrWhiteSpace(stationConnection))
            {
                settings["ConnectionStrings:StationConnection"] = stationConnection;
            }

            if (mapSampleDatabase)
            {
                settings["StationDatabase:BranchDatabaseOverrides:10"] = "QUANLYTAITRAM_Local";
            }

            configuration.AddInMemoryCollection(settings);
        });
        builder.ConfigureServices(services =>
        {
            services.RemoveAll<IOrderReportDataSource>();
            services.AddScoped<IOrderReportDataSource, SqlOrderReportDataSource>();
            services.RemoveAll<IStationDatabaseAvailabilityResolver>();
            services.AddScoped<IStationDatabaseAvailabilityResolver, SqlStationDatabaseAvailabilityResolver>();
        });
    }
}

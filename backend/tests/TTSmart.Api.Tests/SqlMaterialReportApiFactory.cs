using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using TTSmart.Api.Features.MaterialReporting;

namespace TTSmart.Api.Tests;

internal sealed class SqlMaterialReportApiFactory(string stationConnection) : TTSmartApiFactory
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        base.ConfigureWebHost(builder);
        builder.ConfigureAppConfiguration((_, configuration) =>
        {
            configuration.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["ConnectionStrings:StationConnection"] = stationConnection,
                ["StationDatabase:BranchDatabaseOverrides:10"] = "QUANLYTAITRAM_Local"
            });
        });
        builder.ConfigureServices(services =>
        {
            services.RemoveAll<IMaterialReportDataSource>();
            services.AddScoped<IMaterialReportDataSource, SqlMaterialReportDataSource>();
        });
    }
}

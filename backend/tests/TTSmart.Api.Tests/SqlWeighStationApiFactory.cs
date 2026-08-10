using Microsoft.AspNetCore.Hosting;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using TTSmart.Api.Features.WeighStationManagement;

namespace TTSmart.Api.Tests;

internal sealed class SqlWeighStationApiFactory(string stationConnection) : TTSmartApiFactory
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        base.ConfigureWebHost(builder);
        var databaseName = new SqlConnectionStringBuilder(stationConnection).InitialCatalog;
        builder.ConfigureAppConfiguration((_, configuration) =>
        {
            configuration.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["ConnectionStrings:StationConnection"] = stationConnection,
                ["StationDatabase:BranchDatabaseOverrides:10"] = databaseName
            });
        });
        builder.ConfigureServices(services =>
        {
            services.RemoveAll<IWeighStationDataSource>();
            services.AddScoped<IWeighStationDataSource, SqlWeighStationDataSource>();
        });
    }
}

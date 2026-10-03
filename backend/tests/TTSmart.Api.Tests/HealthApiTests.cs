using System.Net;

namespace TTSmart.Api.Tests;

public sealed class HealthApiTests(TTSmartApiFactory factory) : IClassFixture<TTSmartApiFactory>
{
    [Fact]
    public async Task LiveEndpoint_AllowsAnonymousRequests()
    {
        using var client = factory.CreateClient();

        using var response = await client.GetAsync("/health/live");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }
}

using TTSmart.Api.Data.WebAuth;

namespace TTSmart.Api.Features.Auth;

public interface IDatabasePasswordService
{
    bool Verify(WebUser user, string password);
    string HashForStorage(WebUser user, string password);
}

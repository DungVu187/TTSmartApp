using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;

namespace TTSmart.Api.Data.Company;

public sealed class CompanyModelCacheKeyFactory : IModelCacheKeyFactory
{
    public object Create(DbContext context, bool designTime) =>
        context is CompanyDbContext companyDbContext
            ? (context.GetType(), companyDbContext.IsLockedColumnAvailable, designTime)
            : (context.GetType(), designTime);
}

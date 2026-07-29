using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.OpenApi;
using Microsoft.OpenApi;

namespace TTSmart.Api.Common.OpenApi;

public sealed class AuthOperationTransformer : IOpenApiOperationTransformer
{
    public Task TransformAsync(
        OpenApiOperation operation,
        OpenApiOperationTransformerContext context,
        CancellationToken cancellationToken)
    {
        var allowsAnonymous = context.Description.ActionDescriptor.EndpointMetadata
            .OfType<IAllowAnonymous>()
            .Any();
        if (allowsAnonymous)
        {
            return Task.CompletedTask;
        }

        operation.Security ??= [];
        operation.Security.Add(new OpenApiSecurityRequirement
        {
            [new OpenApiSecuritySchemeReference(
                JwtBearerDefaults.AuthenticationScheme,
                context.Document)] = []
        });

        return Task.CompletedTask;
    }
}

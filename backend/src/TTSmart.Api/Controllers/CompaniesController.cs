using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TTSmart.Api.Common.Models;
using TTSmart.Api.Common.Security;
using TTSmart.Api.Features.Authorization;
using TTSmart.Api.Features.CompanyManagement;

namespace TTSmart.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/companies")]
[Produces("application/json")]
public sealed class CompaniesController(ICompanyManagementService service) : ControllerBase
{
    [Authorize(Policy = AccessPolicies.CompaniesList)]
    [HttpGet]
    [ProducesResponseType<PagedResponse<CompanyResponse>>(StatusCodes.Status200OK)]
    public async Task<ActionResult<PagedResponse<CompanyResponse>>> GetPage(
        [FromQuery] CompanyListQuery query,
        CancellationToken cancellationToken) =>
        Ok(await service.GetPageAsync(query, User.GetRequiredUserId(), cancellationToken));

    [Authorize(Policy = AccessPolicies.CompaniesRead)]
    [HttpGet("{id:int}")]
    [ProducesResponseType<CompanyResponse>(StatusCodes.Status200OK)]
    public async Task<ActionResult<CompanyResponse>> GetById(
        int id,
        CancellationToken cancellationToken) =>
        Ok(await service.GetByIdAsync(id, User.GetRequiredUserId(), cancellationToken));

    [Authorize(Policy = AccessPolicies.CompaniesCreate)]
    [HttpPost]
    [ProducesResponseType<CompanyResponse>(StatusCodes.Status201Created)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<CompanyResponse>> Create(
        [FromBody] CreateCompanyRequest request,
        CancellationToken cancellationToken)
    {
        var response = await service.CreateAsync(request, User.GetRequiredUserId(), cancellationToken);
        return CreatedAtAction(nameof(GetById), new { id = response.Id }, response);
    }

    [Authorize(Policy = AccessPolicies.CompaniesUpdate)]
    [HttpPut("{id:int}")]
    [ProducesResponseType<CompanyResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<CompanyResponse>> Update(
        int id,
        [FromBody] UpdateCompanyRequest request,
        CancellationToken cancellationToken) =>
        Ok(await service.UpdateAsync(id, request, User.GetRequiredUserId(), cancellationToken));

    [Authorize(Policy = AccessPolicies.CompaniesUpdate)]
    [HttpPut("{id:int}/lock")]
    [ProducesResponseType<CompanyResponse>(StatusCodes.Status200OK)]
    public async Task<ActionResult<CompanyResponse>> SetLock(
        int id,
        [FromBody] SetCompanyLockRequest request,
        CancellationToken cancellationToken) =>
        Ok(await service.SetLockAsync(id, request, User.GetRequiredUserId(), cancellationToken));

    [Authorize(Policy = AccessPolicies.CompaniesUpdate)]
    [HttpPut("{id:int}/expiration")]
    [ProducesResponseType<CompanyResponse>(StatusCodes.Status200OK)]
    public async Task<ActionResult<CompanyResponse>> SetExpiration(
        int id,
        [FromBody] SetCompanyExpirationRequest request,
        CancellationToken cancellationToken) =>
        Ok(await service.SetExpirationAsync(id, request, User.GetRequiredUserId(), cancellationToken));

    [Authorize(Policy = AccessPolicies.CompaniesUpdate)]
    [HttpPost("{id:int}/logo")]
    [Consumes("multipart/form-data")]
    [ProducesResponseType<CompanyResponse>(StatusCodes.Status200OK)]
    public async Task<ActionResult<CompanyResponse>> UploadLogo(
        int id,
        [FromForm] UploadCompanyLogoRequest request,
        CancellationToken cancellationToken) =>
        Ok(await service.UploadLogoAsync(id, request, User.GetRequiredUserId(), cancellationToken));

    [Authorize(Policy = AccessPolicies.CompaniesRead)]
    [HttpGet("{id:int}/logo")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetLogo(int id, CancellationToken cancellationToken)
    {
        var logo = await service.GetLogoAsync(id, User.GetRequiredUserId(), cancellationToken);
        return File(logo.Content, logo.ContentType, logo.DownloadName, enableRangeProcessing: true);
    }

    [Authorize(Policy = AccessPolicies.CompaniesDelete)]
    [HttpDelete("{id:int}")]
    [ProducesResponseType<CompanyResponse>(StatusCodes.Status200OK)]
    public async Task<ActionResult<CompanyResponse>> Delete(int id, CancellationToken cancellationToken) =>
        Ok(await service.DeleteAsync(id, User.GetRequiredUserId(), cancellationToken));

    [Authorize(Policy = AccessPolicies.CompaniesUpdate)]
    [HttpPost("{id:int}/restore")]
    [ProducesResponseType<CompanyResponse>(StatusCodes.Status200OK)]
    public async Task<ActionResult<CompanyResponse>> Restore(int id, CancellationToken cancellationToken) =>
        Ok(await service.RestoreAsync(id, User.GetRequiredUserId(), cancellationToken));
}

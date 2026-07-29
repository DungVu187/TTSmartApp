[CmdletBinding()]
param(
    [string]$BaseUrl = 'http://localhost:5052',
    [string]$SqlServer = '.\SQLEXPRESS',
    [string]$DatabaseName = 'TTSmartMobile_Dev',
    [string]$AdminUserName,
    [switch]$BootstrapAdmin,
    [switch]$StartApi
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($DatabaseName -cne 'TTSmartMobile_Dev') {
    throw "Script chỉ được phép chạy trên database TTSmartMobile_Dev, không phải '$DatabaseName'."
}

$resolvedBaseUrl = $BaseUrl.TrimEnd('/')
$apiProcess = $null
$apiOutputPath = $null
$apiErrorPath = $null
$adminToken = $null
$testToken = $null
$testRoleId = $null
$testUserId = $null
$testQuotaBypassUserId = $null
$testDeleteUserId = $null
$testFunctionId = $null
$testFunctionRoleId = $null
$originalActiveKey = $null
$bootstrapAdminUserId = $null
$testCompanyId = $null
$testBranchId = $null
$testPrefix = 'E2E_' + (Get-Date -Format 'yyyyMMddHHmmss') + '_' + (Get-Random -Minimum 1000 -Maximum 9999)
$testPassword = $null
$newTestPassword = $null

function Write-Step {
    param([string]$Message)
    Write-Host ("[E2E] " + $Message) -ForegroundColor Cyan
}

function ConvertTo-PlainText {
    param([Security.SecureString]$SecureValue)
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureValue)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    }
}

function Get-Md5Utf8Hex {
    param([string]$Value)
    $md5 = [Security.Cryptography.MD5]::Create()
    try {
        $hashBytes = $md5.ComputeHash([Text.Encoding]::UTF8.GetBytes($Value))
        return ([BitConverter]::ToString($hashBytes)).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $md5.Dispose()
    }
}

function Get-ResponseBody {
    param([string]$RawContent)
    if ([string]::IsNullOrWhiteSpace($RawContent)) {
        return $null
    }

    try {
        return $RawContent | ConvertFrom-Json
    }
    catch {
        return $RawContent
    }
}

function Invoke-Api {
    param(
        [ValidateSet('GET', 'POST', 'PUT', 'DELETE')]
        [string]$Method,
        [string]$Path,
        [string]$Token,
        [object]$Body,
        [int[]]$ExpectedStatus = @(200)
    )

    $headers = @{ Accept = 'application/json' }
    if (-not [string]::IsNullOrWhiteSpace($Token)) {
        $headers.Authorization = 'Bearer ' + $Token
    }

    $uri = $resolvedBaseUrl + $Path
    $requestBody = $null
    if ($null -ne $Body) {
        $requestBody = $Body | ConvertTo-Json -Depth 30 -Compress
    }

    try {
        $response = Invoke-WebRequest `
            -Uri $uri `
            -Method $Method `
            -Headers $headers `
            -Body $requestBody `
            -ContentType 'application/json; charset=utf-8' `
            -UseBasicParsing
        $statusCode = [int]$response.StatusCode
        $rawContent = [string]$response.Content
    }
    catch {
        $currentError = $_
        $errorResponse = $currentError.Exception.Response
        $hasStatusCode = $null -ne $errorResponse -and
            $errorResponse.PSObject.Properties.Name -contains 'StatusCode'
        if (-not $hasStatusCode) {
            throw "Không gọi được $Method ${Path}: $($currentError.Exception.Message)"
        }

        $statusCode = [int]$errorResponse.StatusCode
        $errorDetails = $currentError.ErrorDetails
        if ($null -ne $errorDetails -and -not [string]::IsNullOrWhiteSpace([string]$errorDetails.Message)) {
            $rawContent = [string]$errorDetails.Message
        }
        elseif ($errorResponse.PSObject.Properties.Name -contains 'Content' -and $null -ne $errorResponse.Content) {
            $rawContent = [string]$errorResponse.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        }
        elseif ($errorResponse.PSObject.Methods.Name -contains 'GetResponseStream') {
            $streamReader = [IO.StreamReader]::new($errorResponse.GetResponseStream())
            try {
                $rawContent = $streamReader.ReadToEnd()
            }
            finally {
                $streamReader.Dispose()
            }
        }
        else {
            $rawContent = [string]$currentError.Exception.Message
        }
    }

    $bodyObject = Get-ResponseBody $rawContent
    if ($ExpectedStatus -notcontains $statusCode) {
        $detail = if ($bodyObject -is [string]) { $bodyObject } else { $rawContent }
        throw "API $Method $Path trả HTTP $statusCode, cần $($ExpectedStatus -join ', '). Nội dung: $detail"
    }

    return [pscustomobject]@{
        StatusCode = $statusCode
        Body = $bodyObject
        Raw = $rawContent
    }
}

function Test-ApiAvailable {
    try {
        $probe = Invoke-WebRequest -Uri ($resolvedBaseUrl + '/api/auth/me') -Method GET -UseBasicParsing -TimeoutSec 3
        return $true
    }
    catch {
        if ($null -ne $_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 401) {
            return $true
        }
        return $false
    }
}

function Invoke-SqlScalar {
    param([string]$Query)
    $output = & sqlcmd -S $SqlServer -E -d $DatabaseName -b -h -1 -W -Q $Query 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "sqlcmd thất bại: $($output -join [Environment]::NewLine)"
    }

    $value = $output |
        ForEach-Object { $_.ToString().Trim() } |
        Where-Object { $_.Length -gt 0 } |
        Select-Object -First 1
    return [string]$value
}

function Invoke-SqlNonQuery {
    param([string]$Query)
    $output = & sqlcmd -S $SqlServer -E -d $DatabaseName -b -W -Q $Query 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "sqlcmd thất bại: $($output -join [Environment]::NewLine)"
    }
}

function Invoke-CleanupApi {
    if ([string]::IsNullOrWhiteSpace($adminToken)) {
        return
    }

    foreach ($cleanupUserId in @($testUserId, $testQuotaBypassUserId, $testDeleteUserId)) {
        if (-not $cleanupUserId) {
            continue
        }

        try { Invoke-Api PUT "/api/users/$cleanupUserId/roles" $adminToken @{ roleIds = @() } @(200) | Out-Null } catch { }
        try { Invoke-Api PUT "/api/users/$cleanupUserId/status" $adminToken @{ isActive = $false } @(200) | Out-Null } catch { }
        try { Invoke-Api DELETE "/api/users/$cleanupUserId" $adminToken $null @(204) | Out-Null } catch { }
    }

    if ($testRoleId -and $testFunctionId) {
        try { Invoke-Api DELETE "/api/roles/$testRoleId/functions/$testFunctionId" $adminToken $null @(204) | Out-Null } catch { }
    }

    if ($testRoleId) {
        try { Invoke-Api DELETE "/api/roles/$testRoleId" $adminToken $null @(204) | Out-Null } catch { }
    }

    if ($testFunctionId) {
        try { Invoke-Api DELETE "/api/functions/$testFunctionId" $adminToken $null @(204) | Out-Null } catch { }
    }

    if ($testBranchId) {
        try { Invoke-Api DELETE "/api/branches/$testBranchId" $adminToken $null @(200) | Out-Null } catch { }
    }

    if ($testCompanyId) {
        try { Invoke-Api DELETE "/api/companies/$testCompanyId" $adminToken $null @(200) | Out-Null } catch { }
    }
}

function Invoke-CleanupSql {
    $safePrefix = $testPrefix.Replace("'", "''")
    $cleanupQuery = @"
UPDATE ur
SET Status = 99
FROM dbo.UserRole ur
INNER JOIN dbo.[User] u ON u.UserId = ur.UserId
WHERE LEFT(u.UserName, LEN(N'$safePrefix')) = N'$safePrefix';

UPDATE fr
SET Status = 99
FROM dbo.FunctionRole fr
WHERE fr.TargetId IN (
        SELECT RoleId FROM dbo.Role
        WHERE LEFT(Code, LEN(N'$safePrefix')) = N'$safePrefix')
   OR fr.FunctionId IN (
        SELECT FunctionId FROM dbo.[Function]
        WHERE LEFT(Code, LEN(N'$safePrefix')) = N'$safePrefix');

UPDATE dbo.[User]
SET Status = 99
WHERE LEFT(UserName, LEN(N'$safePrefix')) = N'$safePrefix';

UPDATE dbo.Role
SET Status = 99
WHERE LEFT(Code, LEN(N'$safePrefix')) = N'$safePrefix';

UPDATE dbo.[Function]
SET Status = 99
WHERE LEFT(Code, LEN(N'$safePrefix')) = N'$safePrefix';

UPDATE dbo.Branch
SET Status = 99
WHERE LEFT(Code, LEN(N'$safePrefix')) = N'$safePrefix';

UPDATE dbo.Company
SET Status = 99
WHERE LEFT(Code, LEN(N'$safePrefix')) = N'$safePrefix';
"@

    try {
        Invoke-SqlNonQuery $cleanupQuery
        Write-Step "Đã cleanup dữ liệu SQL theo prefix $testPrefix."
    }
    catch {
        Write-Warning "Không cleanup được bằng SQL: $($_.Exception.Message)"
    }
}

try {
    Write-Step "Xác minh đúng database clone $DatabaseName."
    $actualDatabase = Invoke-SqlScalar 'SELECT DB_NAME();'
    if ($actualDatabase -cne $DatabaseName) {
        throw "SQL context hiện tại là '$actualDatabase', không phải '$DatabaseName'."
    }

    if (-not (Test-ApiAvailable)) {
        if (-not $StartApi) {
            throw "API chưa chạy tại $resolvedBaseUrl. Chạy dotnet run trước hoặc thêm -StartApi."
        }

        $apiOutputPath = Join-Path $env:TEMP 'ttsmart-api-e2e.stdout.log'
        $apiErrorPath = Join-Path $env:TEMP 'ttsmart-api-e2e.stderr.log'
        $projectPath = Join-Path (Get-Location) 'src\TTSmart.Api\TTSmart.Api.csproj'
        $apiProcess = Start-Process `
            -FilePath 'dotnet' `
            -ArgumentList @('run', '--project', $projectPath, '--launch-profile', 'http') `
            -WorkingDirectory (Get-Location) `
            -WindowStyle Hidden `
            -RedirectStandardOutput $apiOutputPath `
            -RedirectStandardError $apiErrorPath `
            -PassThru

        $ready = $false
        for ($attempt = 0; $attempt -lt 60; $attempt++) {
            Start-Sleep -Seconds 1
            if (Test-ApiAvailable) {
                $ready = $true
                break
            }
            if ($apiProcess.HasExited) {
                throw "API dừng khi khởi động. Xem $apiOutputPath và $apiErrorPath."
            }
        }
        if (-not $ready) {
            throw "API không sẵn sàng sau 60 giây. Xem $apiOutputPath và $apiErrorPath."
        }
    }

    if ($BootstrapAdmin) {
        $AdminUserName = $testPrefix + '_A'
        $plainAdminPassword = $testPrefix + '!Bootstrap1'
        $frontendPasswordHash = Get-Md5Utf8Hex $plainAdminPassword
        $safeBootstrapUserName = $AdminUserName.Replace("'", "''")
        $bootstrapKeyLock = 'K'
        $bootstrapRegEmail = 'e@e'
        $bootstrapQuery = @"
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF EXISTS (SELECT 1 FROM dbo.[User] WHERE UserName = N'$safeBootstrapUserName' AND Status = 1)
    THROW 51000, 'Bootstrap username already exists.', 1;

IF NOT EXISTS (SELECT 1 FROM dbo.Role WHERE Status = 1)
    THROW 51001, 'No active role is available for bootstrap.', 1;

INSERT dbo.[User] (FullName, UserName, Password, KeyLock, RegEmail, CreatedAt, UpdatedAt, Status)
VALUES (N'E2E', N'$safeBootstrapUserName', '00000000000000000000000000000000', N'$bootstrapKeyLock', N'$bootstrapRegEmail', GETDATE(), GETDATE(), 1);

DECLARE @BootstrapUserId int = CONVERT(int, SCOPE_IDENTITY());
DECLARE @PasswordPayload varchar(500) =
    '$bootstrapKeyLock' + '$bootstrapRegEmail' + CONVERT(varchar(20), @BootstrapUserId) + '$frontendPasswordHash';

UPDATE dbo.[User]
SET Password = LOWER(CONVERT(varchar(32), HASHBYTES('MD5', @PasswordPayload), 2))
WHERE UserId = @BootstrapUserId;

INSERT dbo.UserRole (UserId, RoleId, CreatedAt, Status)
SELECT @BootstrapUserId, RoleId, GETDATE(), 1
FROM dbo.Role
WHERE Status = 1;

COMMIT TRANSACTION;
SELECT CONVERT(varchar(20), @BootstrapUserId);
"@
        $bootstrapAdminUserId = [int](Invoke-SqlScalar $bootstrapQuery)
        if ($bootstrapAdminUserId -le 0) {
            throw 'Không tạo được tài khoản bootstrap admin trên database clone.'
        }
        Write-Step "Đã tạo bootstrap admin tạm $AdminUserName và gán các Role hiệu lực."
    }
    else {
        while ([string]::IsNullOrWhiteSpace($AdminUserName) -or $AdminUserName -match '^\s*<.*>\s*$') {
            if (-not [string]::IsNullOrWhiteSpace($AdminUserName)) {
                Write-Warning 'Không dùng chuỗi placeholder <tài-khoản-quản-trị>. Hãy nhập username thật trong database clone.'
            }
            $AdminUserName = Read-Host 'Tên tài khoản quản trị thực tế dùng cho E2E'
        }
        $AdminUserName = $AdminUserName.Trim()
        $secureAdminPassword = Read-Host 'Mật khẩu tài khoản quản trị' -AsSecureString
        $plainAdminPassword = ConvertTo-PlainText $secureAdminPassword
    }
    $testPassword = $testPrefix + '!Aa1'
    $newTestPassword = $testPrefix + '!Bb2'

    Write-Step 'Đăng nhập tài khoản quản trị.'
    $login = Invoke-Api POST '/api/auth/login' $null @{ userName = $AdminUserName; password = $plainAdminPassword } @(200)
    $adminToken = [string]$login.Body.accessToken
    if ([string]::IsNullOrWhiteSpace($adminToken)) {
        throw 'Login không trả accessToken.'
    }

    Write-Step 'Kiểm tra /api/auth/me và quyền quản trị.'
    $me = Invoke-Api GET '/api/auth/me' $adminToken $null @(200)
    $adminUserId = [int]$me.Body.user.id
    $managementFunctions = @($me.Body.functions)
    $qlnd = $managementFunctions | Where-Object { $_.code -eq 'QLND' } | Select-Object -First 1
    $qlq = $managementFunctions | Where-Object { $_.code -eq 'QLQ' } | Select-Object -First 1
    $qlcn = $managementFunctions | Where-Object { $_.code -eq 'QLCN' } | Select-Object -First 1
    if ($null -eq $qlnd -or $null -eq $qlq -or $null -eq $qlcn) {
        throw 'Tài khoản E2E không có đủ ba Function quản trị QLND, QLQ, QLCN.'
    }
    Write-Step 'Kiểm tra các endpoint danh sách và cây Function.'
    Invoke-Api GET '/api/users?pageNumber=1&pageSize=5&status=1' $adminToken $null @(200) | Out-Null
    Invoke-Api GET '/api/roles?pageNumber=1&pageSize=5&status=1' $adminToken $null @(200) | Out-Null
    Invoke-Api GET '/api/functions?status=1' $adminToken $null @(200) | Out-Null
    Invoke-Api GET '/api/functions/tree?status=1' $adminToken $null @(200) | Out-Null

    Write-Step 'Tạo Company test riêng với quota hai tài khoản con.'
    $createdCompany = Invoke-Api POST '/api/companies' $adminToken @{
        code = ($testPrefix + '_COMPANY')
        name = ($testPrefix + ' Company')
        email = (($testPrefix + '@example.invalid').ToLowerInvariant())
        phone = '0000000000'
        countUser = 2
        active = 1
        note = 'Temporary E2E company for user quota'
    } @(201)
    $testCompanyId = [int]$createdCompany.Body.id

    Write-Step 'Kiểm tra CRUD Branch và translation SQL Server.'
    $testBranchCode = $testPrefix + '_BRANCH'
    $testBranchUserName = $testPrefix + '_STATION'
    $createdBranch = Invoke-Api POST '/api/branches' $adminToken @{
        companyId = $testCompanyId
        code = $testBranchCode
        name = ($testPrefix + ' Branch')
        email = 'branch-e2e@example.test'
        phone = '0900000000'
        address = 'Ha Noi'
        username = $testBranchUserName
        password = 'Branch123@#'
        typeTram = 1
    } @(201)
    $testBranchId = [int]$createdBranch.Body.id
    if ($testBranchId -le 0 -or [string]$createdBranch.Body.password -ne '••••••••') {
        throw "Response tạo Branch không đúng hoặc làm lộ mật khẩu: $($createdBranch.Raw)"
    }

    $branchList = Invoke-Api GET ("/api/branches?search=" + $testBranchCode) $adminToken $null @(200)
    $listedBranch = @($branchList.Body.items) | Where-Object { [int]$_.id -eq $testBranchId } | Select-Object -First 1
    if ($null -eq $listedBranch -or [int]$branchList.Body.pageSize -ne 10) {
        throw "Danh sách Branch không tìm thấy dữ liệu hoặc pageSize mặc định sai: $($branchList.Raw)"
    }

    $updatedBranch = Invoke-Api PUT "/api/branches/$testBranchId" $adminToken @{
        companyId = $testCompanyId
        code = ($testBranchCode + '_UPDATED')
        name = ($testPrefix + ' Branch Updated')
        email = 'branch-updated@example.test'
        phone = '0911111111'
        username = ($testBranchUserName + '_UPDATED')
        password = 'Branch456@#'
        typeTram = 2
    } @(200)
    if ([int]$updatedBranch.Body.typeTram -ne 2 -or [string]$updatedBranch.Body.password -ne '••••••••') {
        throw "Cập nhật Branch không đúng: $($updatedBranch.Raw)"
    }

    $storedBranchCount = [int](Invoke-SqlScalar "SELECT COUNT(*) FROM dbo.Branch WHERE BranchId = $testBranchId AND Status = 1 AND TypeTram = 2 AND Username = N'$($testBranchUserName)_UPDATED' AND Password = N'Branch456@#';")
    if ($storedBranchCount -ne 1) {
        throw 'Dữ liệu Branch ghi xuống SQL Server không đúng.'
    }

    Invoke-Api DELETE "/api/branches/$testBranchId" $adminToken $null @(200) | Out-Null
    $deletedBranchList = Invoke-Api GET ("/api/branches?status=99&search=" + $testBranchCode) $adminToken $null @(200)
    if (-not (@($deletedBranchList.Body.items) | Where-Object { [int]$_.id -eq $testBranchId })) {
        throw 'Không tìm thấy Branch đã xóa mềm trong bộ lọc status=99.'
    }

    Invoke-Api POST "/api/branches/$testBranchId/restore" $adminToken $null @(200) | Out-Null
    $duplicateBranch = Invoke-Api POST '/api/branches' $adminToken @{
        companyId = $testCompanyId
        code = ($testBranchCode + '_UPDATED')
        name = ($testPrefix + ' Duplicate Branch')
        email = 'branch-duplicate@example.test'
        phone = '0922222222'
        username = ($testBranchUserName + '_OTHER')
        password = 'Branch789@#'
        typeTram = 1
    } @(409)
    if ([string]$duplicateBranch.Body.detail -ne 'Mã trạm đã tồn tại.') {
        throw "Thông báo trùng mã Branch không đúng: $($duplicateBranch.Raw)"
    }

    Write-Step 'Kiểm tra Company.Code phân biệt hoa thường và bỏ khoảng trắng đầu/cuối.'
    $duplicateCompany = Invoke-Api POST '/api/companies' $adminToken @{
        code = ('  ' + ($testPrefix + '_COMPANY') + '  ')
        name = ($testPrefix + ' Duplicate Company')
        email = (($testPrefix + '_duplicate@example.invalid').ToLowerInvariant())
        phone = '0000000001'
        countUser = 1
        active = 1
        note = 'This request must be rejected by Company.Code uniqueness'
    } @(409)
    if ([string]$duplicateCompany.Body.detail -ne 'Mã công ty đã tồn tại.') {
        throw "Thông báo Company.Code trùng không đúng: $($duplicateCompany.Raw)"
    }

    $caseSensitiveCompany = Invoke-Api POST '/api/companies' $adminToken @{
        code = ($testPrefix + '_company')
        name = ($testPrefix + ' Case Sensitive Company')
        email = (($testPrefix + '_case@example.invalid').ToLowerInvariant())
        phone = '0000000002'
        countUser = 1
        active = 1
        note = 'Different letter case must be accepted'
    } @(201)
    if ([string]$caseSensitiveCompany.Body.code -cne ($testPrefix + '_company')) {
        throw "Company.Code khác hoa thường không được lưu đúng: $($caseSensitiveCompany.Raw)"
    }

    $roleCode = $testPrefix + '_ROLE'
    $functionCode = $testPrefix + '_FUNCTION'
    $userName = $testPrefix + '_USER'

    Write-Step 'Tạo và cập nhật Role test.'
    $createdRole = Invoke-Api POST '/api/roles' $adminToken @{
        code = $roleCode
        name = ($testPrefix + ' Role')
        note = 'Temporary E2E role'
        levelRole = 1
    } @(201)
    $testRoleId = [int]$createdRole.Body.id
    Invoke-Api GET "/api/roles/$testRoleId" $adminToken $null @(200) | Out-Null
    Invoke-Api PUT "/api/roles/$testRoleId" $adminToken @{
        code = $roleCode
        name = ($testPrefix + ' Role Updated')
        note = 'Temporary E2E role updated'
        levelRole = 1
    } @(200) | Out-Null
    Invoke-Api PUT "/api/roles/$testRoleId/status" $adminToken @{ isActive = $false } @(200) | Out-Null
    Invoke-Api PUT "/api/roles/$testRoleId/status" $adminToken @{ isActive = $true } @(200) | Out-Null
    $matrix = Invoke-Api GET "/api/roles/$testRoleId/function-matrix" $adminToken $null @(200)
    if (@($matrix.Body).Count -eq 0) {
        throw 'Ma trận FunctionRole không trả Function hiệu lực.'
    }

    Write-Step 'Tạo, cập nhật và đọc Function test.'
    $createdFunction = Invoke-Api POST '/api/functions' $adminToken @{
        parentFunctionId = $null
        code = $functionCode
        name = ($testPrefix + ' Function')
        url = ('/e2e/' + $testPrefix.ToLowerInvariant())
        note = 'Temporary E2E function'
        location = 999
        icon = 'e2e'
    } @(201)
    $testFunctionId = [int]$createdFunction.Body.id
    Invoke-Api GET "/api/functions/$testFunctionId" $adminToken $null @(200) | Out-Null
    Invoke-Api PUT "/api/functions/$testFunctionId" $adminToken @{
        parentFunctionId = $null
        code = $functionCode
        name = ($testPrefix + ' Function Updated')
        url = ('/e2e/' + $testPrefix.ToLowerInvariant())
        note = 'Temporary E2E function updated'
        location = 1000
        icon = 'e2e'
    } @(200) | Out-Null
    Invoke-Api PUT "/api/functions/$testFunctionId/status" $adminToken @{ isActive = $false } @(200) | Out-Null
    Invoke-Api PUT "/api/functions/$testFunctionId/status" $adminToken @{ isActive = $true } @(200) | Out-Null

    Write-Step 'Cập nhật ma trận Role với quyền QLCN Xem và QLND Xem/Tạo/D.Sách.'
    Invoke-Api PUT "/api/roles/$testRoleId/functions" $adminToken @{
        functions = @(
            @{ functionId = [int]$qlcn.id; activeKey = '100000000' },
            @{ functionId = [int]$qlnd.id; activeKey = '110000001' }
        )
    } @(200) | Out-Null
    Invoke-Api PUT "/api/roles/$testRoleId/functions/$($qlcn.id)/active-key" $adminToken @{ activeKey = '100000000' } @(200) | Out-Null

    Write-Step 'Tạo User test và kiểm tra UserRole.'
    $createdUser = Invoke-Api POST '/api/users' $adminToken @{
        userName = $userName
        fullName = ($testPrefix + ' User')
        password = $testPassword
        email = (($testPrefix + '@example.invalid').ToLowerInvariant())
        code = ($testPrefix + '_CODE')
        phone = '0000000000'
        companyId = $testCompanyId
        roleIds = @([int]$testRoleId)
    } @(201)
    $testUserId = [int]$createdUser.Body.id
    Invoke-Api GET "/api/users/$testUserId" $adminToken $null @(200) | Out-Null
    Invoke-Api PUT "/api/users/$testUserId" $adminToken @{
        userName = $userName
        fullName = ($testPrefix + ' User Updated')
        email = (($testPrefix + '@example.invalid').ToLowerInvariant())
        code = ($testPrefix + '_CODE_UPDATED')
        phone = '0000000001'
        companyId = $testCompanyId
        roleIds = @([int]$testRoleId)
    } @(200) | Out-Null
    Invoke-Api PUT "/api/users/$testUserId/roles" $adminToken @{ roleIds = @([int]$testRoleId) } @(200) | Out-Null
    Invoke-Api POST "/api/users/$testUserId/reset-password" $adminToken @{ newPassword = $testPassword } @(204) | Out-Null

    Write-Step 'Đăng nhập User test, đổi mật khẩu và kiểm tra phân biệt Xem/D.Sách.'
    $testLogin = Invoke-Api POST '/api/auth/login' $null @{ userName = $userName; password = $testPassword } @(200)
    $testToken = [string]$testLogin.Body.accessToken
    Invoke-Api POST '/api/auth/change-password' $testToken @{
        currentPassword = $testPassword
        newPassword = $newTestPassword
    } @(204) | Out-Null
    Invoke-Api POST '/api/auth/login' $null @{ userName = $userName; password = $testPassword } @(401) | Out-Null
    $testLogin = Invoke-Api POST '/api/auth/login' $null @{ userName = $userName; password = $newTestPassword } @(200)
    $testToken = [string]$testLogin.Body.accessToken
    Invoke-Api GET '/api/auth/me' $testToken $null @(200) | Out-Null

    Write-Step 'Kiểm tra logout thu hồi JWT cũ và đăng nhập lại.'
    Invoke-Api POST '/api/auth/logout' $testToken $null @(204) | Out-Null
    Invoke-Api GET '/api/auth/me' $testToken $null @(401) | Out-Null
    $testLogin = Invoke-Api POST '/api/auth/login' $null @{ userName = $userName; password = $newTestPassword } @(200)
    $testToken = [string]$testLogin.Body.accessToken
    Invoke-Api GET '/api/auth/me' $testToken $null @(200) | Out-Null

    Write-Step 'Kiểm tra tài khoản công ty chỉ thấy User cùng CompanyId.'
    $companyUsers = Invoke-Api GET '/api/users?pageNumber=1&pageSize=100' $testToken $null @(200)
    $expectedCompanyUserCount = [int](Invoke-SqlScalar "SELECT COUNT(*) FROM dbo.[User] WHERE CompanyId = $testCompanyId AND Status = 1;")
    if ([int]$companyUsers.Body.totalCount -ne $expectedCompanyUserCount) {
        throw "Data scope User sai: API trả $($companyUsers.Body.totalCount), SQL cần $expectedCompanyUserCount User của CompanyId $testCompanyId."
    }
    foreach ($companyUser in @($companyUsers.Body.items)) {
        if ([int]$companyUser.companyId -ne $testCompanyId) {
            throw "API làm lộ UserId $($companyUser.id) thuộc CompanyId $($companyUser.companyId)."
        }
    }
    $foreignUserId = [int](Invoke-SqlScalar "SELECT TOP (1) UserId FROM dbo.[User] WHERE Status = 1 AND CompanyId IS NOT NULL AND CompanyId <> $testCompanyId ORDER BY UserId;")
    if ($foreignUserId -gt 0) {
        Invoke-Api GET "/api/users/$foreignUserId" $testToken $null @(404) | Out-Null
    }

    Write-Step 'Giảm quota xuống dưới số đang dùng và kiểm tra tài khoản công ty bị chặn.'
    $reducedCompany = Invoke-Api PUT "/api/companies/$testCompanyId" $adminToken @{
        code = ($testPrefix + '_COMPANY')
        name = ($testPrefix + ' Company')
        email = (($testPrefix + '@example.invalid').ToLowerInvariant())
        phone = '0000000000'
        countUser = 1
        active = 1
        note = 'Temporary E2E company for user quota'
    } @(200)
    if ([int]$reducedCompany.Body.countUser -ne 1) {
        throw "Không lưu được quota giảm xuống 1: $($reducedCompany.Raw)"
    }

    $quotaBlockedUserName = $testPrefix + '_QUOTA_BLOCKED'
    $quotaBlocked = Invoke-Api POST '/api/users' $testToken @{
        userName = $quotaBlockedUserName
        fullName = ($testPrefix + ' Quota Blocked')
        password = $testPassword
        companyId = $testCompanyId
        roleIds = @([int]$testRoleId)
    } @(409)
    if ([string]$quotaBlocked.Body.detail -notlike '*đã sử dụng đủ 1 tài khoản*') {
        throw "Thông báo quota không đúng: $($quotaBlocked.Raw)"
    }

    $quotaBypassUserName = $testPrefix + '_QUOTA_ADMIN'
    $quotaBypassUser = Invoke-Api POST '/api/users' $adminToken @{
        userName = $quotaBypassUserName
        fullName = ($testPrefix + ' Quota Admin Bypass')
        password = $testPassword
        companyId = $testCompanyId
        roleIds = @([int]$testRoleId)
    } @(201)
    $testQuotaBypassUserId = [int]$quotaBypassUser.Body.id

    Invoke-Api GET "/api/functions/$($qlcn.id)" $testToken $null @(200) | Out-Null
    Invoke-Api GET '/api/functions?status=1' $testToken $null @(403) | Out-Null
    Invoke-Api PUT "/api/users/$testUserId/roles" $testToken @{ roleIds = @() } @(403) | Out-Null
    Invoke-Api PUT "/api/users/$testUserId/status" $testToken @{ isActive = $false } @(403) | Out-Null

    Write-Step 'Sửa ActiveKey trực tiếp trong DB và kiểm tra hiệu lực request kế tiếp.'
    $testFunctionRoleId = [int](Invoke-SqlScalar "SELECT TOP (1) FunctionRoleId FROM dbo.FunctionRole WHERE TargetId = $testRoleId AND FunctionId = $($qlcn.id) AND Type = 2 AND Status = 1 ORDER BY FunctionRoleId DESC;")
    if ($testFunctionRoleId -le 0) {
        throw 'Không tìm thấy FunctionRole test trong database clone.'
    }
    $originalActiveKey = [string](Invoke-SqlScalar "SELECT ActiveKey FROM dbo.FunctionRole WHERE FunctionRoleId = $testFunctionRoleId;")
    Invoke-SqlNonQuery "UPDATE dbo.FunctionRole SET ActiveKey = '000000000' WHERE FunctionRoleId = $testFunctionRoleId;"
    Invoke-Api GET "/api/functions/$($qlcn.id)" $testToken $null @(403) | Out-Null
    Invoke-SqlNonQuery "UPDATE dbo.FunctionRole SET ActiveKey = '100000000' WHERE FunctionRoleId = $testFunctionRoleId;"
    Invoke-Api GET "/api/functions/$($qlcn.id)" $testToken $null @(200) | Out-Null

    Write-Step 'Kiểm tra khóa User có hiệu lực với JWT cũ.'
    Invoke-Api PUT "/api/users/$testUserId/status" $adminToken @{ isActive = $false } @(200) | Out-Null
    Invoke-Api GET '/api/auth/me' $testToken $null @(401) | Out-Null

    Write-Step 'Kiểm tra validation ActiveKey và ma trận không bị ghi một phần.'
    Invoke-Api PUT "/api/roles/$testRoleId/functions/$($qlcn.id)/active-key" $adminToken @{ activeKey = '111111' } @(400) | Out-Null
    Invoke-Api PUT "/api/roles/$testRoleId/functions" $adminToken @{
        functions = @(
            @{ functionId = [int]$qlcn.id; activeKey = '100000000' }
            @{ functionId = 2147483647; activeKey = '100000000' }
        )
    } @(400) | Out-Null
    $matrixAfterFailure = Invoke-Api GET "/api/roles/$testRoleId/function-matrix" $adminToken $null @(200)
    $qlcnAfterFailure = @($matrixAfterFailure.Body) | Where-Object { $_.functionId -eq [int]$qlcn.id } | Select-Object -First 1
    if ($null -eq $qlcnAfterFailure -or $qlcnAfterFailure.activeKey -ne '100000000') {
        throw 'Ma trận Role thay đổi ngoài ý muốn sau request lỗi.'
    }

    Write-Step 'Kiểm tra xóa mềm User, Role và Function.'
    $deleteUserName = $testPrefix + '_DELETE_USER'
    $deleteUser = Invoke-Api POST '/api/users' $adminToken @{
        userName = $deleteUserName
        fullName = ($testPrefix + ' Delete User')
        password = $testPassword
        roleIds = @()
    } @(201)
    $testDeleteUserId = [int]$deleteUser.Body.id
    Invoke-Api DELETE "/api/users/$testDeleteUserId" $adminToken $null @(204) | Out-Null
    Invoke-Api DELETE "/api/roles/$testRoleId" $adminToken $null @(204) | Out-Null
    Invoke-Api DELETE "/api/functions/$testFunctionId" $adminToken $null @(204) | Out-Null

    Write-Host '[E2E] PASS - Auth/RBAC/Company/Branch SQL Server clone smoke test hoàn tất.' -ForegroundColor Green
}
catch {
    Write-Host ('[E2E] FAIL - ' + $_.Exception.Message) -ForegroundColor Red
    throw
}
finally {
    if ($testFunctionRoleId -and $originalActiveKey) {
        try {
            $safeActiveKey = $originalActiveKey.Replace("'", "''")
            Invoke-SqlNonQuery "UPDATE dbo.FunctionRole SET ActiveKey = '$safeActiveKey' WHERE FunctionRoleId = $testFunctionRoleId;"
        }
        catch {
            Write-Warning "Không khôi phục được ActiveKey FunctionRole ${testFunctionRoleId}: $($_.Exception.Message)"
        }
    }

    Invoke-CleanupApi
    Invoke-CleanupSql

    if ($apiProcess -and -not $apiProcess.HasExited) {
        Stop-Process -Id $apiProcess.Id -Force
    }
}

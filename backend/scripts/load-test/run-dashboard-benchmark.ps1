param(
    [string]$BaseUrl = "http://localhost:5052",
    [string]$Stages = "1x10s,5x20s,10x20s,20x30s",
    [int]$CompanyId = 0,
    [int]$BranchId = 0,
    [int]$Workers = 0,
    [string]$Token = "",
    [string]$Output = ""
)

$ErrorActionPreference = "Stop"
$scriptPath = Join-Path $PSScriptRoot "dashboard-benchmark.mjs"
$previous = @{}
$environmentNames = @(
    "BENCH_BASE_URL",
    "BENCH_STAGES",
    "BENCH_COMPANY_ID",
    "BENCH_BRANCH_ID",
    "BENCH_WORKERS",
    "BENCH_OUTPUT",
    "LOAD_TEST_TOKEN",
    "LOAD_TEST_USERNAME",
    "LOAD_TEST_PASSWORD"
)

foreach ($name in $environmentNames) {
    $previous[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
}

$passwordPointer = [IntPtr]::Zero
try {
    $env:BENCH_BASE_URL = $BaseUrl
    $env:BENCH_STAGES = $Stages
    if ($CompanyId -gt 0) { $env:BENCH_COMPANY_ID = $CompanyId.ToString() }
    if ($BranchId -gt 0) { $env:BENCH_BRANCH_ID = $BranchId.ToString() }
    if ($Workers -gt 0) { $env:BENCH_WORKERS = $Workers.ToString() }
    if (-not [string]::IsNullOrWhiteSpace($Output)) { $env:BENCH_OUTPUT = $Output }

    if (-not [string]::IsNullOrWhiteSpace($Token)) {
        $env:LOAD_TEST_TOKEN = $Token
    }
    elseif ([string]::IsNullOrWhiteSpace($env:LOAD_TEST_TOKEN)) {
        $env:LOAD_TEST_USERNAME = Read-Host "Tài khoản test local"
        $securePassword = Read-Host "Mật khẩu" -AsSecureString
        $passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
        $env:LOAD_TEST_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer)
    }

    & node $scriptPath
    exit $LASTEXITCODE
}
finally {
    if ($passwordPointer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer)
    }
    foreach ($name in $environmentNames) {
        [Environment]::SetEnvironmentVariable($name, $previous[$name], "Process")
    }
}

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PackageDirectory,
    [Parameter(Mandatory = $true)][string]$SiteName,
    [Parameter(Mandatory = $true)][string]$AppPoolName,
    [Parameter(Mandatory = $true)][string]$SitePath,
    [Parameter(Mandatory = $true)][string]$BackupRoot,
    [Parameter(Mandatory = $true)][string]$LocalHealthUrl,
    [Parameter(Mandatory = $true)][string]$PublicHealthUrl,
    [Parameter(Mandatory = $true)][string]$ReleaseId,
    [switch]$Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-AbsoluteExistingDirectory([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "Directory does not exist: $Path"
    }
    return (Resolve-Path -LiteralPath $Path).ProviderPath.TrimEnd('\')
}

function Assert-SeparateDirectory([string]$First, [string]$Second) {
    if ($First.Equals($Second, [StringComparison]::OrdinalIgnoreCase) -or
        $First.StartsWith($Second + '\', [StringComparison]::OrdinalIgnoreCase) -or
        $Second.StartsWith($First + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw "Deployment paths overlap: $First and $Second"
    }
}

function Test-ReservedPath([string]$RelativePath) {
    $parts = $RelativePath -split '[\\/]'
    if ($parts[0] -in @('uploads', 'App_Data', 'logs')) { return $true }
    $name = $parts[$parts.Length - 1]
    return $name -like 'appsettings*.json' -or
        $name -in @('web.config', 'app_offline.htm', '.ttsmart-deploy-manifest.txt')
}

function Get-ManagedFiles([string]$Root) {
    $prefix = $Root.TrimEnd('\') + '\'
    return @(Get-ChildItem -LiteralPath $Root -Recurse -File |
        ForEach-Object { $_.FullName.Substring($prefix.Length) } |
        Where-Object { -not (Test-ReservedPath $_) })
}

function Get-SafeSiteFile([string]$RelativePath) {
    if ([IO.Path]::IsPathRooted($RelativePath) -or
        ($RelativePath -split '[\\/]') -contains '..' -or
        (Test-ReservedPath $RelativePath)) {
        throw "Unsafe managed file path: $RelativePath"
    }
    $result = [IO.Path]::GetFullPath((Join-Path $siteDirectory $RelativePath))
    if (-not $result.StartsWith($siteDirectory + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw "Managed file escapes the IIS site: $RelativePath"
    }
    return $result
}

function Copy-CodeTree([string]$Source, [string]$Destination) {
    & robocopy $Source $Destination /E /R:2 /W:2 /NP /NFL /NDL /NJH /NJS `
        /XD uploads App_Data logs `
        /XF appsettings*.json web.config app_offline.htm | Out-Null
    $robocopyExitCode = $LASTEXITCODE
    if ($robocopyExitCode -ge 8) {
        throw "Robocopy failed with exit code ${robocopyExitCode}: $Source -> $Destination"
    }
    # Robocopy codes 0..7 are successful but the runner treats a lingering
    # nonzero LASTEXITCODE as a failed PowerShell step.
    $global:LASTEXITCODE = 0
}

function Wait-Healthy([string]$Url, [string]$ExpectedRelease) {
    $lastError = ''
    for ($attempt = 1; $attempt -le 15; $attempt++) {
        try {
            $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5
            $body = $response.Content | ConvertFrom-Json
            if ($response.StatusCode -eq 200 -and
                $body.status -eq 'healthy' -and
                $body.release -eq $ExpectedRelease) { return }
            $lastError = "HTTP $($response.StatusCode), release $($body.release)"
        }
        catch {
            $lastError = $_.Exception.Message
        }
        Start-Sleep -Seconds 2
    }
    throw "Health check failed at $Url ($lastError)"
}

if ($ReleaseId -notmatch '^[a-fA-F0-9]{7,40}$') {
    throw 'ReleaseId must be a Git commit SHA.'
}
$packageDirectory = Get-AbsoluteExistingDirectory $PackageDirectory
$siteDirectory = Get-AbsoluteExistingDirectory $SitePath
$backupDirectoryRoot = [IO.Path]::GetFullPath($BackupRoot).TrimEnd('\')
Assert-SeparateDirectory $packageDirectory $siteDirectory
Assert-SeparateDirectory $backupDirectoryRoot $siteDirectory
Assert-SeparateDirectory $backupDirectoryRoot $packageDirectory

foreach ($file in @('TTSmart.Api.dll', 'web.config', 'release-id.txt')) {
    if (-not (Test-Path -LiteralPath (Join-Path $packageDirectory $file) -PathType Leaf)) {
        throw "Published artifact is missing $file"
    }
}
if (Get-ChildItem -LiteralPath $packageDirectory -Filter 'appsettings*.json' -File) {
    throw 'The publish artifact must not contain appsettings files.'
}
$artifactRelease = (Get-Content -LiteralPath (Join-Path $packageDirectory 'release-id.txt') -Raw).Trim()
if ($artifactRelease -ne $ReleaseId) {
    throw "Artifact release does not match requested commit $ReleaseId"
}
foreach ($file in @('appsettings.json', 'web.config')) {
    if (-not (Test-Path -LiteralPath (Join-Path $siteDirectory $file) -PathType Leaf)) {
        throw "Existing IIS configuration is missing $file. Configure the site before CD."
    }
}

$localUri = [uri]$LocalHealthUrl
$publicUri = [uri]$PublicHealthUrl
if ($localUri.Scheme -ne 'http' -or $localUri.Host -notin @('127.0.0.1', 'localhost') -or
    $localUri.Port -ne 5003 -or $localUri.AbsolutePath -ne '/health/live' -or
    $publicUri.Scheme -ne 'https' -or $publicUri.Host -ne 'mobile.dangnhap.net' -or
    $publicUri.AbsolutePath -ne '/health/live') {
    throw 'Health URLs must be the local HTTP and public HTTPS /health/live endpoints.'
}

if ($SiteName -ne 'TTSmartMobileApi' -or $AppPoolName -ne 'TTSmartMobileApi' -or
    -not $siteDirectory.Equals('C:\Deploy\TTSmartMobileApi', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'This deployment script only accepts the verified TTSmartMobileApi IIS target.'
}
$modulePath = Join-Path ${env:ProgramFiles} 'IIS\Asp.Net Core Module\V2\aspnetcorev2.dll'
if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
    throw 'ASP.NET Core IIS module file is missing.'
}
$runtimes = & dotnet --list-runtimes
if ($LASTEXITCODE -ne 0 -or -not ($runtimes -match '^Microsoft\.AspNetCore\.App 10\.')) {
    throw 'ASP.NET Core 10 runtime is not installed on the IIS server.'
}

$manifestPath = Join-Path $siteDirectory '.ttsmart-deploy-manifest.txt'
$oldManifestExists = Test-Path -LiteralPath $manifestPath -PathType Leaf
$oldManagedFiles = if ($oldManifestExists) { @(Get-Content -LiteralPath $manifestPath | Where-Object { $_ }) } else { @() }
foreach ($relative in $oldManagedFiles) { $null = Get-SafeSiteFile $relative }
$newManagedFiles = @(Get-ManagedFiles $packageDirectory)
if ($newManagedFiles.Count -eq 0) { throw 'Published artifact has no deployable files.' }

Write-Host "IIS: $SiteName / $AppPoolName at $siteDirectory"
Write-Host "Artifact: $packageDirectory ($($newManagedFiles.Count) managed files)"
Write-Host "Health: $LocalHealthUrl and $PublicHealthUrl"
if (-not $Apply) {
    Write-Host 'Preflight passed. No files were changed; pass -Apply to deploy.'
    return
}

$backupPath = Join-Path $backupDirectoryRoot ((Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss') + '-' + $ReleaseId.Substring(0, 12))
if (Test-Path -LiteralPath $backupPath) { throw "Backup already exists: $backupPath" }
New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
$offlinePath = Join-Path $siteDirectory 'app_offline.htm'
if (Test-Path -LiteralPath $offlinePath) { throw 'IIS site is already offline; deployment stopped.' }

$offlinePlaced = $false
$backupReady = $false
$rollbackFailed = $false
try {
    Set-Content -LiteralPath $offlinePath -Value 'Deployment in progress.' -Encoding Ascii
    $offlinePlaced = $true
    Start-Sleep -Seconds 3

    Copy-CodeTree $siteDirectory $backupPath
    $backupReady = $true
    $backupFiles = @(Get-ManagedFiles $backupPath)

    Copy-CodeTree $packageDirectory $siteDirectory
    foreach ($relative in $oldManagedFiles) {
        if ($newManagedFiles -notcontains $relative) {
            Remove-Item -LiteralPath (Get-SafeSiteFile $relative) -ErrorAction SilentlyContinue
        }
    }
    Set-Content -LiteralPath $manifestPath -Value $newManagedFiles -Encoding UTF8

    Remove-Item -LiteralPath $offlinePath
    $offlinePlaced = $false
    Wait-Healthy $LocalHealthUrl $ReleaseId
    Wait-Healthy $PublicHealthUrl $ReleaseId
    Write-Host "Deployment succeeded. Code backup: $backupPath"
}
catch {
    $deployFailure = $_
    if ($backupReady) {
        try {
            if (-not $offlinePlaced) {
                Set-Content -LiteralPath $offlinePath -Value 'Restoring previous release.' -Encoding Ascii
                $offlinePlaced = $true
                Start-Sleep -Seconds 3
            }
            Copy-CodeTree $backupPath $siteDirectory
            foreach ($relative in $newManagedFiles) {
                if ($backupFiles -notcontains $relative) {
                    Remove-Item -LiteralPath (Get-SafeSiteFile $relative) -ErrorAction SilentlyContinue
                }
            }
            if ($oldManifestExists) {
                Set-Content -LiteralPath $manifestPath -Value $oldManagedFiles -Encoding UTF8
            }
            else {
                Remove-Item -LiteralPath $manifestPath -ErrorAction SilentlyContinue
            }
            Write-Warning "Previous code restored from $backupPath. Check the site manually."
        }
        catch {
            $rollbackFailed = $true
            Write-Warning "Automatic rollback failed: $($_.Exception.Message). Backup: $backupPath"
        }
    }
    throw $deployFailure
}
finally {
    if ($offlinePlaced -and -not $rollbackFailed -and (Test-Path -LiteralPath $offlinePath)) {
        Remove-Item -LiteralPath $offlinePath
    }
    elseif ($rollbackFailed) {
        Write-Warning "IIS remains offline for manual recovery. Backup: $backupPath"
    }
}

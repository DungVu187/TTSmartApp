[CmdletBinding()]
param(
    [string]$ServerInstance = '.\SQLEXPRESS',
    [string]$DatabaseName = 'TTSmartMobile_Dev'
)

$ErrorActionPreference = 'Stop'

if ($DatabaseName -cne 'TTSmartMobile_Dev') {
    throw 'This script is allowed only for TTSmartMobile_Dev.'
}

$sqlScript = Join-Path $PSScriptRoot 'add-company-islocked.sql'
if (-not (Test-Path -LiteralPath $sqlScript)) {
    throw "SQL script not found: $sqlScript"
}

Write-Host "[Company] Verify Company.IsLocked on $ServerInstance/$DatabaseName."
& sqlcmd -S $ServerInstance -E -d master -b -W -s '|' -v "DatabaseName=$DatabaseName" -i $sqlScript

if ($LASTEXITCODE -ne 0) {
    throw "sqlcmd failed with exit code $LASTEXITCODE."
}

Write-Host '[Company] Done.'

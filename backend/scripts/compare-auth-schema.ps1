param(
    [string]$Server = '.\SQLEXPRESS',
    [string]$SourceDatabase = 'dangnhap.net',
    [string]$DevelopmentDatabase = 'TTSmartMobile_Dev'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$discoveryScript = Join-Path $PSScriptRoot 'discover-web-auth-schema.sql'
$sourceOutput = Join-Path $repositoryRoot 'docs\dangnhap-auth-schema.txt'
$developmentOutput = Join-Path $repositoryRoot 'docs\ttsmartmobile-dev-auth-schema.txt'

function Invoke-Discovery([string]$Database, [string]$OutputPath)
{
    $temporaryOutputPath = "$OutputPath.$PID.tmp"
    if (Test-Path -LiteralPath $temporaryOutputPath)
    {
        Remove-Item -LiteralPath $temporaryOutputPath -Force
    }

    $arguments = @(
        '-S', $Server,
        '-E',
        '-d', 'master',
        '-b',
        '-W',
        '-s', '|',
        '-v', "DatabaseName=$Database",
        '-i', $discoveryScript,
        '-o', $temporaryOutputPath
    )
    try
    {
        & sqlcmd @arguments
        if ($LASTEXITCODE -ne 0)
        {
            throw "Cannot inspect database $Database."
        }

        $databaseLine = Get-Content -Encoding UTF8 $temporaryOutputPath |
            Where-Object { $_.StartsWith('DATABASE|', [StringComparison]::Ordinal) } |
            Select-Object -First 1
        if (-not $databaseLine)
        {
            throw "Discovery output for $Database does not contain the database identity."
        }

        $actualDatabase = $databaseLine.Split('|')[1]
        if (-not [string]::Equals($actualDatabase, $Database, [StringComparison]::OrdinalIgnoreCase))
        {
            throw "Discovery requested $Database but inspected $actualDatabase."
        }

        Move-Item -LiteralPath $temporaryOutputPath -Destination $OutputPath -Force
    }
    finally
    {
        if (Test-Path -LiteralPath $temporaryOutputPath)
        {
            Remove-Item -LiteralPath $temporaryOutputPath -Force
        }
    }
}

function Get-SchemaLines([string]$Path)
{
    $prefixes = @(
        'TABLES|',
        'COLUMNS|',
        'INDEXES|',
        'FOREIGN_KEYS|',
        'CHECK_CONSTRAINTS|',
        'TRIGGERS|',
        'DEPENDENCIES|'
    )

    return Get-Content -Encoding UTF8 $Path | Where-Object {
        $line = $_
        @($prefixes | Where-Object { $line.StartsWith($_, [StringComparison]::Ordinal) }).Count -gt 0
    }
}

Invoke-Discovery -Database $SourceDatabase -OutputPath $sourceOutput
Invoke-Discovery -Database $DevelopmentDatabase -OutputPath $developmentOutput

$sourceSchema = @(Get-SchemaLines -Path $sourceOutput)
$developmentSchema = @(Get-SchemaLines -Path $developmentOutput)
$differences = Compare-Object -ReferenceObject $sourceSchema -DifferenceObject $developmentSchema

if ($differences)
{
    $differences | Format-Table -AutoSize
    throw 'The five-table auth/RBAC schemas are different.'
}

Write-Output 'The five-table auth/RBAC schemas match.'
Write-Output "Source: $sourceOutput"
Write-Output "Development: $developmentOutput"

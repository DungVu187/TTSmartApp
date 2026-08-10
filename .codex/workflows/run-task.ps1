[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TaskId,

    [switch]$AllowDirty,

    [switch]$ValidateOnly
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$planPath = Join-Path $repoRoot 'PLAN.md'
$reportRoot = Join-Path $repoRoot 'docs\agent-reports'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Read-PlanTask {
    param([string]$PlanText, [string]$RequestedTaskId)

    $headingPattern = '(?ms)^###\s+' + [regex]::Escape($RequestedTaskId) + '\b(?<body>.*?)(?=^###\s+|\z)'
    $taskMatch = [regex]::Match($PlanText, $headingPattern)
    if (-not $taskMatch.Success) {
        throw "Task '$RequestedTaskId' was not found in PLAN.md."
    }

    $body = $taskMatch.Groups['body'].Value
    $statusMatch = [regex]::Match($body, '(?im)^\s*-\s*Status:\s*(?<value>[a-z_]+)\s*$')
    $areaMatch = [regex]::Match($body, '(?im)^\s*-\s*Area:\s*(?<value>[a-z_]+)\s*$')
    if (-not $statusMatch.Success) {
        throw "Task '$RequestedTaskId' is missing Status."
    }
    if (-not $areaMatch.Success) {
        throw "Task '$RequestedTaskId' is missing Area."
    }

    $area = $areaMatch.Groups['value'].Value.ToLowerInvariant()
    if ($area -notin @('backend', 'mobile', 'both', 'docs')) {
        throw "Task '$RequestedTaskId' has an invalid Area: '$area'."
    }

    [pscustomobject]@{
        Id = $RequestedTaskId
        Body = $body.Trim()
        Status = $statusMatch.Groups['value'].Value.ToLowerInvariant()
        Area = $area
    }
}

function Update-PlanTaskStatus {
    param(
        [string]$PlanFile,
        [string]$RequestedTaskId,
        [string]$NewStatus
    )

    $currentText = [System.IO.File]::ReadAllText($PlanFile, [System.Text.Encoding]::UTF8)
    $headingPattern = '(?ms)^###\s+' + [regex]::Escape($RequestedTaskId) + '\b(?<body>.*?)(?=^###\s+|\z)'
    $taskMatch = [regex]::Match($currentText, $headingPattern)
    if (-not $taskMatch.Success) {
        throw "Cannot update task '$RequestedTaskId' because it is no longer in PLAN.md."
    }

    $replacement = '${1}' + $NewStatus + '${2}'
    $updatedBody = [regex]::Replace(
        $taskMatch.Groups['body'].Value,
        '(?im)^(\s*-\s*Status:\s*)[a-z_]+(\s*)$',
        $replacement
    )
    $updatedText = $currentText.Remove($taskMatch.Index, $taskMatch.Length).Insert($taskMatch.Index, $taskMatch.Value.Replace($taskMatch.Groups['body'].Value, $updatedBody))
    [System.IO.File]::WriteAllText($PlanFile, $updatedText, $utf8NoBom)
}

function Get-GitStatusLines {
    @(git -C $repoRoot status --short)
}

function Get-GitChangedFiles {
    @(git -C $repoRoot status --short | ForEach-Object {
        if ($_.Length -gt 3) { $_.Substring(3).Trim() } else { $_.Trim() }
    })
}

function Invoke-CheckCommand {
    param(
        [string]$Name,
        [string]$WorkingDirectory,
        [string]$Executable,
        [string[]]$Arguments
    )

    Write-Host "Running $Name..."
    Push-Location $WorkingDirectory
    try {
        $output = @(& $Executable @Arguments 2>&1 | ForEach-Object { $_.ToString() })
        $exitCode = $LASTEXITCODE
    }
    finally {
        Pop-Location
    }

    [pscustomobject]@{
        Name = $Name
        Command = "$Executable $($Arguments -join ' ')"
        ExitCode = $exitCode
        OutputTail = (($output | Select-Object -Last 5) -join [Environment]::NewLine)
    }
}

function Assert-CommandAvailable {
    param([string]$CommandName)

    if (-not (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
        throw "Command '$CommandName' was not found in PATH."
    }
}

function Invoke-AutomatedChecks {
    param([string]$Area)

    $results = @()
    if ($Area -in @('backend', 'both')) {
        Assert-CommandAvailable 'dotnet'
        $results += Invoke-CheckCommand 'backend restore' (Join-Path $repoRoot 'backend') 'dotnet' @('restore', '.\TTSmart.sln')
        if ($results[-1].ExitCode -ne 0) { throw 'Backend restore failed.' }
        $results += Invoke-CheckCommand 'backend test' (Join-Path $repoRoot 'backend') 'dotnet' @('test', '.\TTSmart.sln', '-c', 'Release', '--no-restore')
        if ($results[-1].ExitCode -ne 0) { throw 'Backend test failed.' }
        $results += Invoke-CheckCommand 'backend build' (Join-Path $repoRoot 'backend') 'dotnet' @('build', '.\TTSmart.sln', '-c', 'Release', '--no-restore')
        if ($results[-1].ExitCode -ne 0) { throw 'Backend build failed.' }
    }

    if ($Area -in @('mobile', 'both')) {
        Assert-CommandAvailable 'dart'
        Assert-CommandAvailable 'flutter'
        $results += Invoke-CheckCommand 'mobile format check' (Join-Path $repoRoot 'mobile') 'dart' @('format', '--set-exit-if-changed', 'lib', 'test')
        if ($results[-1].ExitCode -ne 0) { throw 'Mobile format check failed.' }
        $results += Invoke-CheckCommand 'mobile analyze' (Join-Path $repoRoot 'mobile') 'flutter' @('analyze')
        if ($results[-1].ExitCode -ne 0) { throw 'Flutter analyze failed.' }
        $results += Invoke-CheckCommand 'mobile test' (Join-Path $repoRoot 'mobile') 'flutter' @('test')
        if ($results[-1].ExitCode -ne 0) { throw 'Flutter test failed.' }
        $results += Invoke-CheckCommand 'mobile debug build' (Join-Path $repoRoot 'mobile') 'flutter' @('build', 'apk', '--debug')
        if ($results[-1].ExitCode -ne 0) { throw 'Flutter debug build failed.' }
    }

    return $results
}

function Read-OptionalText {
    param([string]$Path)

    if (Test-Path -LiteralPath $Path) {
        return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8).Trim()
    }
    return '(The agent did not produce a final output.)'
}

if (-not (Test-Path -LiteralPath $planPath)) {
    throw "PLAN.md was not found at '$repoRoot'."
}

$planText = [System.IO.File]::ReadAllText($planPath, [System.Text.Encoding]::UTF8)
$task = Read-PlanTask $planText $TaskId
$allowedStatuses = @('ready', 'needs_changes')

if ($ValidateOnly) {
    Write-Host "Task: $($task.Id)"
    Write-Host "Status: $($task.Status)"
    Write-Host "Area: $($task.Area)"
    Write-Host "Working tree files: $((Get-GitStatusLines).Count)"
    if ($task.Status -notin $allowedStatuses) {
        Write-Host 'Task is not ready; set Status to ready or needs_changes.'
    }
    exit 0
}

if ($task.Status -notin $allowedStatuses) {
    throw "Task '$TaskId' has status '$($task.Status)'. Only ready or needs_changes tasks can run."
}

$initialGitStatus = Get-GitStatusLines
if ($initialGitStatus.Count -gt 0 -and -not $AllowDirty) {
    throw 'Working tree has changes. Review or checkpoint them first, or explicitly rerun with -AllowDirty. The workflow never resets or commits.'
}

$codexCommand = if ($env:OS -eq 'Windows_NT') { 'codex.cmd' } else { 'codex' }
Assert-CommandAvailable $codexCommand

$safeTaskId = $TaskId -replace '[^A-Za-z0-9._-]', '_'
$runId = Get-Date -Format 'yyyyMMdd-HHmmss'
$runDirectory = Join-Path $reportRoot "$safeTaskId\$runId"
New-Item -ItemType Directory -Force -Path $runDirectory | Out-Null
$agentOutputPath = Join-Path $runDirectory 'agent-output.md'
$reviewOutputPath = Join-Path $runDirectory 'review-output.md'
$reportPath = Join-Path $runDirectory 'REPORT.md'

$agentExitCode = $null
$reviewExitCode = $null
$checkResults = @()
$reviewVerdict = 'NOT_RUN'
$failureMessage = $null
$finalStatus = 'in_progress'
$startedAt = Get-Date

try {
    Update-PlanTaskStatus $planPath $TaskId 'in_progress'

    $implementationPrompt = @"
You are the implementation agent for task $TaskId in the TTSmartApp repository.

Read the root AGENTS.md, the nearest scoped AGENTS.md, PLAN.md, and relevant skills before editing.

Task to implement:
$($task.Body)

Session rules:
- Edit only the task scope; do not expand the business requirement.
- Do not edit PLAN.md or AGENTS.md to hide errors or status unless the task explicitly requests a durable rule update.
- Do not commit, push, reset, overwrite checkout, delete data, deploy, or run database migration/restore/seed.
- Never write to dangnhap.net; never use it as a write target.
- If the business rule, API contract, data scope, or database object is unclear, stop and report BLOCKED instead of guessing.
- Run focused checks while working; the workflow runs the standard checks after the agent exits.
- Never put secrets, tokens, passwords, connection strings, or production data in code, logs, or reports.

End with a concise handoff covering changed files, checks run, assumptions, unverifed areas, and integration risks.
"@

    $agentArguments = @('--ask-for-approval', 'on-request', '--sandbox', 'workspace-write', 'exec', '--cd', $repoRoot, '--output-last-message', $agentOutputPath, $implementationPrompt)
    & $codexCommand @agentArguments
    $agentExitCode = $LASTEXITCODE
    if ($agentExitCode -ne 0) {
        throw "Codex implementer exited with code $agentExitCode."
    }

    $checkResults = @(Invoke-AutomatedChecks $task.Area)

    $reviewPrompt = @"
You are the independent reviewer for task $TaskId in the TTSmartApp repository.

Review only; do not edit files. Read the root AGENTS.md, the nearest scoped AGENTS.md, PLAN.md, the current diff, and the agent output if needed.

Minimum checks:
- The implementation stays within task scope and does not modify unrelated files.
- Acceptance criteria, API contract, serialization, and backend-mobile compatibility.
- Authentication, authorization, company/station data scope, and backend validation.
- No direct SQL access from mobile, no secrets, and no dangnhap.net write target.
- Build/test/analyze results are present and appropriate.
- No placeholder, TODO replacing real logic, or workaround hiding a defect.

Do not run dangerous commands. The first output line must be exactly one of:
VERDICT: PASS
VERDICT: NEEDS_CHANGES
VERDICT: BLOCKED

After the verdict, list findings by severity with affected files, evidence, and suggested action.
"@
    $reviewArguments = @('--ask-for-approval', 'on-request', '--sandbox', 'read-only', 'exec', '--cd', $repoRoot, '--output-last-message', $reviewOutputPath, $reviewPrompt)
    & $codexCommand @reviewArguments
    $reviewExitCode = $LASTEXITCODE
    if ($reviewExitCode -ne 0) {
        throw "Codex reviewer exited with code $reviewExitCode."
    }

    $reviewText = Read-OptionalText $reviewOutputPath
    $verdictMatch = [regex]::Match($reviewText, '(?im)^VERDICT:\s*(PASS|NEEDS_CHANGES|BLOCKED)\s*$')
    if ($verdictMatch.Success) {
        $reviewVerdict = $verdictMatch.Groups[1].Value.ToUpperInvariant()
    }
    else {
        $reviewVerdict = 'NEEDS_CHANGES'
        throw 'Reviewer did not return a valid verdict.'
    }

    if ($reviewVerdict -ne 'PASS') {
        throw "Reviewer returned $reviewVerdict."
    }

    $finalStatus = 'auto_verified'
}
catch {
    $failureMessage = $_.Exception.Message
    $finalStatus = 'needs_changes'
}
finally {
    try {
        Update-PlanTaskStatus $planPath $TaskId $finalStatus
    }
    catch {
        $failureMessage = if ($failureMessage) { "$failureMessage Plan status update failed: $($_.Exception.Message)" } else { "Plan status update failed: $($_.Exception.Message)" }
        $finalStatus = 'needs_changes'
    }

    $agentText = Read-OptionalText $agentOutputPath
    $reviewText = Read-OptionalText $reviewOutputPath
    $changedFiles = Get-GitChangedFiles
    $checkText = if ($checkResults.Count -eq 0) {
        'No automated check results were produced.'
    }
    else {
        ($checkResults | ForEach-Object { "- $($_.Name): exit $($_.ExitCode); Command: $($_.Command)" }) -join [Environment]::NewLine
    }

    $report = @"
# Task Run Report

- Task: $TaskId
- Area: $($task.Area)
- Started: $($startedAt.ToString('o'))
- Finished: $((Get-Date).ToString('o'))
- Final status: $finalStatus
- Agent exit code: $agentExitCode
- Reviewer verdict: $reviewVerdict
- Reviewer exit code: $reviewExitCode
- Initial working tree dirty: $($initialGitStatus.Count -gt 0)

## Changed Files

$(if ($changedFiles.Count -eq 0) { '- No changed files detected.' } else { $changedFiles | ForEach-Object { "- $_" } | Out-String })

## Automated Checks

$checkText

## Implementer Output

$agentText

## Reviewer Output

$reviewText

## Failure or Stop Reason

$(if ($failureMessage) { $failureMessage } else { 'None.' })

## Next Step

$(if ($finalStatus -eq 'auto_verified') { 'Run real-world validation. After it passes, update PLAN.md to waiting_user_validation and then accepted.' } else { 'Read the findings/output, clarify the requirement, or fix the task before rerunning.' })
"@
    [System.IO.File]::WriteAllText($reportPath, $report, $utf8NoBom)
}

Write-Host "Report: $reportPath"
if ($failureMessage) {
    Write-Error $failureMessage
    exit 1
}

Write-Host "Task $TaskId passed automated checks and technical review. Waiting for real-world validation."

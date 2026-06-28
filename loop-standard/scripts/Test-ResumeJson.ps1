[CmdletBinding()]
param(
    [switch]$KeepTemp
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Add-Problem {
    param([Parameter(Mandatory = $true)][string]$Message)
    $script:Problems.Add($Message)
}

function Invoke-AiLoop {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $PreviousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $Output = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $AiLoopScript @Arguments 2>&1)
    $ExitCode = $LASTEXITCODE
    $ErrorActionPreference = $PreviousErrorActionPreference
    return [pscustomobject]@{
        ExitCode = $ExitCode
        Text = ($Output | Out-String)
    }
}

function Save-Json {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Path
    )
    $Object | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $Path -Encoding utf8
}

function Read-JsonResult {
    param(
        [Parameter(Mandatory = $true)]$Result,
        [Parameter(Mandatory = $true)][string]$Label
    )
    try {
        return ($Result.Text | ConvertFrom-Json)
    } catch {
        Add-Problem "$Label did not produce parseable JSON: $($_.Exception.Message) :: $($Result.Text)"
        return $null
    }
}

$KitRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = Split-Path -Parent $KitRoot
$AiLoopScript = Join-Path $PSScriptRoot "ai-loop.ps1"
. (Join-Path $PSScriptRoot "test-temp-root.ps1")
$TempRoot = New-LoopTestTempRoot -RepoRoot $RepoRoot -Name "resume-json"
$ProjectRoot = Join-Path $TempRoot "project"
$Problems = New-Object System.Collections.Generic.List[string]

if ((Test-Path -LiteralPath $TempRoot) -and -not $KeepTemp) {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $ProjectRoot | Out-Null

Push-Location $ProjectRoot
try {
    git init | Out-Null
    Set-Content -LiteralPath "README.md" -Encoding utf8 -Value "# Resume JSON fixture"
    Set-Content -LiteralPath "verify.ps1" -Encoding utf8 -Value "Write-Output 'resume json: OK'`nexit 0"
    git add README.md verify.ps1 | Out-Null
    git commit -m "Initial fixture" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Add-Problem "fixture git commit failed."
    }
} finally {
    Pop-Location
}

$Init = Invoke-AiLoop -Arguments @("-Command", "init", "-ProjectRoot", $ProjectRoot)
if ($Init.ExitCode -ne 0) { Add-Problem "init failed: $($Init.Text)" }
$Start = Invoke-AiLoop -Arguments @(
    "-Command", "start",
    "-ProjectRoot", $ProjectRoot,
    "-PhaseId", "phase-001",
    "-TaskKind", "fullstack",
    "-Title", "Resume JSON",
    "-Objective", "Exercise resume JSON.",
    "-VerifyCommand", "powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\verify.ps1"
)
if ($Start.ExitCode -ne 0) { Add-Problem "start failed: $($Start.Text)" }

$TextResume = Invoke-AiLoop -Arguments @("-Command", "resume", "-ProjectRoot", $ProjectRoot)
if ($TextResume.ExitCode -ne 0 -or $TextResume.Text -notmatch "# AI Loop Resume Summary" -or $TextResume.Text -notmatch "Recovery decision: RESUMABLE") {
    Add-Problem "default text resume should remain human-readable and resumable: $($TextResume.Text)"
}

$JsonResume = Invoke-AiLoop -Arguments @("-Command", "resume", "-ProjectRoot", $ProjectRoot, "-Json")
if ($JsonResume.ExitCode -ne 0) {
    Add-Problem "resume -Json should pass for started phase: $($JsonResume.Text)"
}
$ResumeObject = Read-JsonResult -Result $JsonResume -Label "started resume json"
if ($null -ne $ResumeObject) {
    if ([string]$ResumeObject.schema_version -ne "1.0") { Add-Problem "resume JSON schema_version should be 1.0." }
    if ([string]$ResumeObject.current_phase.phase_id -ne "phase-001") { Add-Problem "resume JSON current phase should be phase-001." }
    if ([string]$ResumeObject.recovery_decision -ne "RESUMABLE") { Add-Problem "resume JSON should be RESUMABLE." }
    if ([bool]$ResumeObject.blocked) { Add-Problem "resume JSON should not be blocked for started phase." }
    if ([string]$ResumeObject.transitions.consistency -ne "OK") { Add-Problem "resume JSON transition consistency should be OK." }
    if ([string]$ResumeObject.next_safe_command -notmatch "-Command collect") { Add-Problem "resume JSON next_safe_command should point to collect." }
    if ($JsonResume.Text -match "===== .ai-loop/") { Add-Problem "resume -Json should not append governance file dumps." }
}

$StatusPath = Join-Path $ProjectRoot ".ai-loop\status.json"
$Status = Get-Content -LiteralPath $StatusPath -Raw | ConvertFrom-Json
$Status.current_phase.status = "audit_ready"
$Status.phases[0].status = "audit_ready"
Save-Json -Object $Status -Path $StatusPath

$TamperedJson = Invoke-AiLoop -Arguments @("-Command", "resume", "-ProjectRoot", $ProjectRoot, "-Json")
if ($TamperedJson.ExitCode -eq 0) {
    Add-Problem "resume -Json should return nonzero for transition/status mismatch."
}
$TamperedObject = Read-JsonResult -Result $TamperedJson -Label "tampered resume json"
if ($null -ne $TamperedObject) {
    if ([string]$TamperedObject.recovery_decision -ne "BLOCKED") { Add-Problem "tampered resume JSON should be BLOCKED." }
    if (-not [bool]$TamperedObject.blocked) { Add-Problem "tampered resume JSON should have blocked=true." }
    if ([string]$TamperedObject.transitions.consistency -notmatch "MISMATCH") { Add-Problem "tampered resume JSON should report transition mismatch." }
    if (@($TamperedObject.transitions.problems).Count -eq 0) { Add-Problem "tampered resume JSON should include transition problems." }
}

$MissingRoot = Join-Path $TempRoot "missing-status"
New-Item -ItemType Directory -Force -Path $MissingRoot | Out-Null
$MissingJson = Invoke-AiLoop -Arguments @("-Command", "resume", "-ProjectRoot", $MissingRoot, "-Json")
if ($MissingJson.ExitCode -eq 0) {
    Add-Problem "resume -Json should return nonzero when status.json is missing."
}
$MissingObject = Read-JsonResult -Result $MissingJson -Label "missing status resume json"
if ($null -ne $MissingObject) {
    if ([string]$MissingObject.recovery_decision -ne "BLOCKED" -or [string]$MissingObject.reason -notmatch "missing .ai-loop/status.json") {
        Add-Problem "missing status resume JSON should explain missing status file."
    }
}

if ($Problems.Count -gt 0) {
    Write-Output "Resume JSON test: FAILED"
    foreach ($Problem in $Problems) {
        Write-Output "- $Problem"
    }
    Write-Output "Fixture root: $TempRoot"
    exit 2
}

Write-Output "Resume JSON test: OK"
Write-Output "Fixture root: $TempRoot"
Write-Output "Cases checked: text compatibility, started JSON, blocked mismatch JSON, missing status JSON"

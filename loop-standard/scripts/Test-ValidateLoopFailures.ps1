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

function Assert-UnderRoot {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Path
    )
    $ResolvedRoot = [System.IO.Path]::GetFullPath($Root)
    $ResolvedPath = [System.IO.Path]::GetFullPath($Path)
    if (-not $ResolvedPath.StartsWith($ResolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to operate outside test root: $ResolvedPath"
    }
}

function Save-Json {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Path
    )
    $Object | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $Path -Encoding utf8
}

function New-CaseRoot {
    param([Parameter(Mandatory = $true)][string]$Name)
    $CaseRoot = Join-Path $TempRoot $Name
    Assert-UnderRoot -Root $RepoRoot -Path $CaseRoot
    New-Item -ItemType Directory -Force -Path $CaseRoot | Out-Null
    Copy-Item -LiteralPath $SourceLoopDir -Destination (Join-Path $CaseRoot ".ai-loop") -Recurse -Force
    return $CaseRoot
}

function Invoke-ValidateLoop {
    param([Parameter(Mandatory = $true)][string]$ProjectRoot)
    $Output = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ValidateLoopScript -ProjectRoot $ProjectRoot 2>&1)
    return [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Text = ($Output | Out-String)
    }
}

function Expect-ValidationPass {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$ProjectRoot
    )
    $Result = Invoke-ValidateLoop -ProjectRoot $ProjectRoot
    if ($Result.ExitCode -ne 0) {
        Add-Problem "$Name expected validate-loop to pass, got exit $($Result.ExitCode): $($Result.Text)"
    }
}

function Expect-ValidationFailure {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [Parameter(Mandatory = $true)][string]$ExpectedText
    )
    $Result = Invoke-ValidateLoop -ProjectRoot $ProjectRoot
    if ($Result.ExitCode -eq 0) {
        Add-Problem "$Name expected validate-loop to fail, but it passed."
        return
    }
    if ($Result.Text -notmatch [regex]::Escape($ExpectedText)) {
        Add-Problem "$Name failed for the wrong reason. Expected '$ExpectedText'. Output: $($Result.Text)"
    }
}

$KitRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = Split-Path -Parent $KitRoot
$SourceLoopDir = Join-Path $RepoRoot ".ai-loop"
$ValidateLoopScript = Join-Path $PSScriptRoot "validate-loop.ps1"
. (Join-Path $PSScriptRoot "test-temp-root.ps1")
$TempRoot = New-LoopTestTempRoot -RepoRoot $RepoRoot -Name "validate-loop-failures"
$Problems = New-Object System.Collections.Generic.List[string]

if (-not (Test-Path -LiteralPath $SourceLoopDir -PathType Container)) {
    throw "Source .ai-loop directory missing: $SourceLoopDir"
}
if (-not (Test-Path -LiteralPath $ValidateLoopScript -PathType Leaf)) {
    throw "validate-loop.ps1 missing: $ValidateLoopScript"
}

Assert-UnderRoot -Root $RepoRoot -Path $TempRoot
if ((Test-Path -LiteralPath $TempRoot) -and -not $KeepTemp) {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $TempRoot | Out-Null

$ValidRoot = New-CaseRoot -Name "valid-copy"
Expect-ValidationPass -Name "valid-copy" -ProjectRoot $ValidRoot

$DuplicateRoot = New-CaseRoot -Name "duplicate-phase-id"
$DuplicateStatusPath = Join-Path $DuplicateRoot ".ai-loop\status.json"
$DuplicateStatus = Get-Content -LiteralPath $DuplicateStatusPath -Raw | ConvertFrom-Json
$DuplicateStatus.phases = @($DuplicateStatus.phases) + $DuplicateStatus.phases[0]
Save-Json -Object $DuplicateStatus -Path $DuplicateStatusPath
Expect-ValidationFailure -Name "duplicate-phase-id" -ProjectRoot $DuplicateRoot -ExpectedText "duplicate phase_id"

$BrokenCurrentRoot = New-CaseRoot -Name "broken-current-phase"
$BrokenCurrentStatusPath = Join-Path $BrokenCurrentRoot ".ai-loop\status.json"
$BrokenCurrentStatus = Get-Content -LiteralPath $BrokenCurrentStatusPath -Raw | ConvertFrom-Json
$BrokenCurrentStatus.current_phase.phase_id = "phase-does-not-exist"
Save-Json -Object $BrokenCurrentStatus -Path $BrokenCurrentStatusPath
Expect-ValidationFailure -Name "broken-current-phase" -ProjectRoot $BrokenCurrentRoot -ExpectedText "current_phase does not match exactly one status.json phases entry"

$IllegalStatusRoot = New-CaseRoot -Name "illegal-phase-status"
$IllegalStatusPath = Join-Path $IllegalStatusRoot ".ai-loop\status.json"
$IllegalStatus = Get-Content -LiteralPath $IllegalStatusPath -Raw | ConvertFrom-Json
$IllegalStatus.phases[0].status = "phase_done"
Save-Json -Object $IllegalStatus -Path $IllegalStatusPath
Expect-ValidationFailure -Name "illegal-phase-status" -ProjectRoot $IllegalStatusRoot -ExpectedText "illegal status"

$MissingAuditRoot = New-CaseRoot -Name "missing-accepted-audit"
$MissingAuditPath = Join-Path $MissingAuditRoot ".ai-loop\audits\phase-001-audit.md"
Remove-Item -LiteralPath $MissingAuditPath -Force
Expect-ValidationFailure -Name "missing-accepted-audit" -ProjectRoot $MissingAuditRoot -ExpectedText "missing audit result"

$StaleArtifactRoot = New-CaseRoot -Name "stale-artifact-manifest"
$StaleVerifyLog = Join-Path $StaleArtifactRoot ".ai-loop\runs\phase-001\verify.log"
Add-Content -LiteralPath $StaleVerifyLog -Encoding utf8 -Value "`nstale mutation for validate-loop fixture"
Expect-ValidationFailure -Name "stale-artifact-manifest" -ProjectRoot $StaleArtifactRoot -ExpectedText "accepted gate failed"

$MissingRecoveryRoot = New-CaseRoot -Name "missing-recovery-file"
$MissingRecoveryPath = Join-Path $MissingRecoveryRoot ".ai-loop\memory\handoff-summary.md"
Remove-Item -LiteralPath $MissingRecoveryPath -Force
Expect-ValidationFailure -Name "missing-recovery-file" -ProjectRoot $MissingRecoveryRoot -ExpectedText "handoff-summary.md missing"

if ($Problems.Count -gt 0) {
    Write-Output "Validate-loop failure fixtures: FAILED"
    foreach ($Problem in $Problems) {
        Write-Output "- $Problem"
    }
    exit 2
}

Write-Output "Validate-loop failure fixtures: OK"
Write-Output "Fixture root: $TempRoot"
Write-Output "Cases checked: 7"

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

function Invoke-AiLoop {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $PreviousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $Output = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $AiLoopScript @Arguments 2>&1)
    $ErrorActionPreference = $PreviousErrorActionPreference
    return [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Text = ($Output | Out-String)
    }
}

function Expect-Ok {
    param(
        [Parameter(Mandatory = $true)]$Result,
        [Parameter(Mandatory = $true)][string]$Label
    )
    if ($Result.ExitCode -ne 0) {
        Add-Problem "$Label failed with exit $($Result.ExitCode): $($Result.Text)"
    }
}

$KitRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = Split-Path -Parent $KitRoot
$AiLoopScript = Join-Path $PSScriptRoot "ai-loop.ps1"
. (Join-Path $PSScriptRoot "test-temp-root.ps1")
$TempRoot = New-LoopTestTempRoot -RepoRoot $RepoRoot -Name "audit-findings"
$Problems = New-Object System.Collections.Generic.List[string]

Assert-UnderRoot -Root $RepoRoot -Path $TempRoot
if ((Test-Path -LiteralPath $TempRoot) -and -not $KeepTemp) {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $TempRoot | Out-Null

$ProjectRoot = Join-Path $TempRoot "project"
New-Item -ItemType Directory -Force -Path $ProjectRoot | Out-Null
"fixture=audit-findings" | Set-Content -LiteralPath (Join-Path $ProjectRoot "README.md") -Encoding utf8
"Write-Output 'audit finding extraction fixture: OK'; exit 0" |
    Set-Content -LiteralPath (Join-Path $ProjectRoot "verify.ps1") -Encoding utf8
& git -C $ProjectRoot init | Out-Null
& git -C $ProjectRoot -c user.email="loop@example.invalid" -c user.name="Loop Test" add README.md verify.ps1
& git -C $ProjectRoot -c user.email="loop@example.invalid" -c user.name="Loop Test" commit -m "Initial commit" | Out-Null
if ($LASTEXITCODE -ne 0) {
    Add-Problem "fixture git commit failed."
}

Expect-Ok -Result (Invoke-AiLoop -Arguments @("-Command", "init", "-ProjectRoot", $ProjectRoot)) -Label "init"
Expect-Ok -Result (Invoke-AiLoop -Arguments @(
    "-Command", "start",
    "-ProjectRoot", $ProjectRoot,
    "-PhaseId", "phase-001",
    "-TaskKind", "fullstack",
    "-Title", "Audit finding extraction source",
    "-Objective", "Create a REWORK source phase with structured audit findings.",
    "-VerifyCommand", "powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\verify.ps1"
)) -Label "start"

$RunDir = Join-Path $ProjectRoot ".ai-loop\runs\phase-001"
"# Worker Report`n`nSource phase for structured audit finding extraction." |
    Set-Content -LiteralPath (Join-Path $RunDir "report.md") -Encoding utf8
"fixture=audit-findings`nchanged=true" |
    Set-Content -LiteralPath (Join-Path $ProjectRoot "README.md") -Encoding utf8
Expect-Ok -Result (Invoke-AiLoop -Arguments @("-Command", "collect", "-ProjectRoot", $ProjectRoot, "-PhaseId", "phase-001", "-Force")) -Label "collect"
Expect-Ok -Result (Invoke-AiLoop -Arguments @("-Command", "audit-pack", "-ProjectRoot", $ProjectRoot, "-PhaseId", "phase-001")) -Label "audit-pack"

$AuditPath = Join-Path $ProjectRoot ".ai-loop\audits\phase-001-audit.md"
@(
    "# Codex Audit"
    ""
    "Decision: REWORK"
    ""
    "Finding: README change is too broad."
    "Severity: high"
    "Required fix: Limit the follow-up to README.md."
    "Evidence: .ai-loop/runs/phase-001/diff.patch, .ai-loop/runs/phase-001/verify.log"
    "Files: README.md"
    ""
    "Finding: Worker report needs a narrower verification note."
    "Required fix: Update only the phase report with the exact verification command."
    "Evidence: .ai-loop/runs/phase-001/report.md"
    "Files: .ai-loop/runs/phase-001/report.md"
) | Set-Content -LiteralPath $AuditPath -Encoding utf8

Expect-Ok -Result (Invoke-AiLoop -Arguments @(
    "-Command", "decide",
    "-ProjectRoot", $ProjectRoot,
    "-PhaseId", "phase-001",
    "-Decision", "REWORK",
    "-Reason", "Structured findings require bounded follow-up."
)) -Label "decide rework"

$FindingsPath = Join-Path $ProjectRoot ".ai-loop\audits\phase-001-findings.json"
if (-not (Test-Path -LiteralPath $FindingsPath -PathType Leaf)) {
    Add-Problem "findings JSON was not created."
} else {
    $FindingsDoc = Get-Content -LiteralPath $FindingsPath -Raw | ConvertFrom-Json
    if ([string]$FindingsDoc.decision -ne "REWORK") {
        Add-Problem "findings JSON decision should be REWORK, got $($FindingsDoc.decision)"
    }
    if ([int]$FindingsDoc.finding_count -ne 2 -or @($FindingsDoc.findings).Count -ne 2) {
        Add-Problem "expected two structured findings, got finding_count=$($FindingsDoc.finding_count)"
    }
    $First = @($FindingsDoc.findings)[0]
    if ([string]$First.finding_id -ne "F-001" -or [string]$First.severity -ne "high") {
        Add-Problem "first finding should be F-001/high."
    }
    if (@($First.files) -notcontains "README.md") {
        Add-Problem "first finding should include README.md file scope."
    }
}

$Meta = Get-Content -LiteralPath (Join-Path $RunDir "phase_meta.json") -Raw | ConvertFrom-Json
if ([string]$Meta.audit_findings -ne ".ai-loop/audits/phase-001-findings.json") {
    Add-Problem "phase metadata missing audit_findings path."
}
$Status = Get-Content -LiteralPath (Join-Path $ProjectRoot ".ai-loop\status.json") -Raw | ConvertFrom-Json
if ([string]$Status.last_decision.findings -ne ".ai-loop/audits/phase-001-findings.json") {
    Add-Problem "status last_decision missing findings path."
}

Expect-Ok -Result (Invoke-AiLoop -Arguments @(
    "-Command", "scaffold-rework",
    "-ProjectRoot", $ProjectRoot,
    "-PhaseId", "phase-001",
    "-ReworkPhaseId", "phase-002"
)) -Label "scaffold rework"

$ReworkSourcePath = Join-Path $ProjectRoot ".ai-loop\runs\phase-002\rework_source.json"
$PromptPath = Join-Path $ProjectRoot ".ai-loop\runs\phase-002\prompt.md"
if (Test-Path -LiteralPath $ReworkSourcePath -PathType Leaf) {
    $ReworkSource = Get-Content -LiteralPath $ReworkSourcePath -Raw | ConvertFrom-Json
    if ([int]$ReworkSource.structured_findings_count -ne 2) {
        Add-Problem "rework_source should preserve two structured findings."
    }
    if ([string]$ReworkSource.source_findings -ne ".ai-loop/audits/phase-001-findings.json") {
        Add-Problem "rework_source missing source_findings path."
    }
} else {
    Add-Problem "rework_source.json missing."
}
if (Test-Path -LiteralPath $PromptPath -PathType Leaf) {
    $PromptText = Get-Content -LiteralPath $PromptPath -Raw
    foreach ($Needle in @(
        "Structured audit finding F-001",
        "Required fix for F-001: Limit the follow-up to README.md.",
        "Finding F-001 file: README.md",
        ".ai-loop/audits/phase-001-findings.json"
    )) {
        if ($PromptText -notmatch [regex]::Escape($Needle)) {
            Add-Problem "rework prompt missing structured scope text: $Needle"
        }
    }
} else {
    Add-Problem "rework prompt missing."
}

Expect-Ok -Result (Invoke-AiLoop -Arguments @("-Command", "validate-loop", "-ProjectRoot", $ProjectRoot)) -Label "validate-loop with findings"

Remove-Item -LiteralPath $FindingsPath -Force
$MissingFindings = Invoke-AiLoop -Arguments @("-Command", "validate-loop", "-ProjectRoot", $ProjectRoot)
if ($MissingFindings.ExitCode -eq 0) {
    Add-Problem "validate-loop should fail when terminal REWORK phase findings JSON is missing."
} elseif ($MissingFindings.Text -notmatch "missing audit findings JSON") {
    Add-Problem "missing findings failed for unexpected reason: $($MissingFindings.Text)"
}

if ($Problems.Count -gt 0) {
    Write-Output "Audit finding extraction test: FAILED"
    foreach ($Problem in $Problems) {
        Write-Output "- $Problem"
    }
    exit 2
}

Write-Output "Audit finding extraction test: OK"
Write-Output "Fixture root: $TempRoot"
Write-Output "Cases checked: extraction, durable decision state, structured rework scaffold, missing findings validation"

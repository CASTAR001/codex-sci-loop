[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][string]$PhaseId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-JsonFile {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string]$Path
    )
    $Value | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $Path -Encoding utf8
}

function Set-JsonProperty {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        $Value
    )
    if ($null -ne $Object.PSObject.Properties[$Name]) {
        $Object.$Name = $Value
    } else {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    }
}

$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$LoopDir = Join-Path $ProjectRoot ".ai-loop"
$RunDir = Join-Path $LoopDir (Join-Path "runs" $PhaseId)
$AuditDir = Join-Path $LoopDir "audits"
$StatusPath = Join-Path $LoopDir "status.json"
$MetaPath = Join-Path $RunDir "phase_meta.json"

if (-not (Test-Path -LiteralPath $MetaPath)) {
    throw "Missing phase metadata: $MetaPath"
}
New-Item -ItemType Directory -Force -Path $AuditDir | Out-Null

$Required = @(
    "base_commit.txt",
    "status_before.txt",
    "phase_meta.json",
    "phase_requirements.json",
    "prompt.md",
    "report.md",
    "status_after.txt",
    "diff.patch",
    "verify.log",
    "changed_files.txt",
    "changed_business_files.txt",
    "changed_evidence_files.txt"
)

$Problems = New-Object System.Collections.Generic.List[string]
foreach ($Name in $Required) {
    $Path = Join-Path $RunDir $Name
    if (-not (Test-Path -LiteralPath $Path)) {
        $Problems.Add("missing: $Name")
        continue
    }
    $Text = Get-Content -LiteralPath $Path -Raw
    if ($Text -match "(?m)^\s*MISSING:") {
        $Problems.Add("$Name contains MISSING placeholder")
    }
}

$GateScript = Join-Path $PSScriptRoot "validate-phase-gates.ps1"
$GateOutput = @()
$GateExitCode = 0
if (Test-Path -LiteralPath $GateScript) {
    $GateOutput = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $GateScript -ProjectRoot $ProjectRoot -PhaseId $PhaseId -TargetStatus audit_ready 2>&1)
    $GateExitCode = $LASTEXITCODE
    if ($GateExitCode -ne 0) {
        $Problems.Add("phase gate validation failed")
    }
} else {
    $Problems.Add("missing validate-phase-gates.ps1")
}

$ChangedFilesPath = Join-Path $RunDir "changed_files.txt"
$ChangedBusinessFilesPath = Join-Path $RunDir "changed_business_files.txt"
$ChangedEvidenceFilesPath = Join-Path $RunDir "changed_evidence_files.txt"
$ChangedFiles = @()
if (Test-Path -LiteralPath $ChangedFilesPath) {
    $ChangedFiles = @(Get-Content -LiteralPath $ChangedFilesPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}
$ChangedBusinessFiles = @()
if (Test-Path -LiteralPath $ChangedBusinessFilesPath) {
    $ChangedBusinessFiles = @(Get-Content -LiteralPath $ChangedBusinessFilesPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}
$ChangedEvidenceFiles = @()
if (Test-Path -LiteralPath $ChangedEvidenceFilesPath) {
    $ChangedEvidenceFiles = @(Get-Content -LiteralPath $ChangedEvidenceFilesPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}
$ChangedFilesText = if ($ChangedFiles.Count -gt 0) {
    ($ChangedFiles | ForEach-Object { "- $_" }) -join [Environment]::NewLine
} else {
    "- MISSING: no changed files recorded."
}
$ChangedBusinessFilesText = if ($ChangedBusinessFiles.Count -gt 0) {
    ($ChangedBusinessFiles | ForEach-Object { "- $_" }) -join [Environment]::NewLine
} else {
    "- None recorded."
}
$ChangedEvidenceFilesText = if ($ChangedEvidenceFiles.Count -gt 0) {
    ($ChangedEvidenceFiles | ForEach-Object { "- $_" }) -join [Environment]::NewLine
} else {
    "- None recorded."
}

$ProblemText = if ($Problems.Count -eq 0) { "None" } else { ($Problems | ForEach-Object { "- $_" }) -join [Environment]::NewLine }
$GateText = if ($GateOutput.Count -gt 0) { ($GateOutput | Out-String).TrimEnd() } else { "No gate output captured." }
$AuditInputPath = Join-Path $AuditDir "$PhaseId-audit-input.md"
$AuditResultPath = Join-Path $AuditDir "$PhaseId-audit.md"
$AuditInput = @"
# Codex Audit Input: $PhaseId

## Project Root

    $ProjectRoot

## Required Evidence Files

- status: $StatusPath
- base commit: $(Join-Path $RunDir "base_commit.txt")
- status before: $(Join-Path $RunDir "status_before.txt")
- phase metadata: $(Join-Path $RunDir "phase_meta.json")
- phase requirements: $(Join-Path $RunDir "phase_requirements.json")
- prompt: $(Join-Path $RunDir "prompt.md")
- Worker report: $(Join-Path $RunDir "report.md")
- status after: $(Join-Path $RunDir "status_after.txt")
- diff: $(Join-Path $RunDir "diff.patch")
- verify log: $(Join-Path $RunDir "verify.log")
- changed files: $(Join-Path $RunDir "changed_files.txt")
- changed business files: $(Join-Path $RunDir "changed_business_files.txt")
- changed evidence files: $(Join-Path $RunDir "changed_evidence_files.txt")
- evidence ledger: $(Join-Path $LoopDir "evidence\evidence-ledger.md")
- artifact index: $(Join-Path $LoopDir "evidence\artifact-index.md")
- command log: $(Join-Path $LoopDir "evidence\command-log.md")
- test log: $(Join-Path $LoopDir "evidence\test-log.md")
- provenance map: $(Join-Path $LoopDir "evidence\provenance-map.md")
- skill trigger matrix: $(Join-Path $LoopDir "skills\skill-trigger-matrix.md")
- skill usage ledger: $(Join-Path $LoopDir "skills\skill-usage-ledger.md")
- skill artifact map: $(Join-Path $LoopDir "skills\skill-artifact-map.md")

## Changed Or Relevant Source Files

$ChangedFilesText

## Changed Business Files

$ChangedBusinessFilesText

## Changed Evidence Files

$ChangedEvidenceFilesText

## Missing Or Invalid Evidence

$ProblemText

## Phase Gate Validation

```text
$GateText
```

## Audit Instructions

Codex must inspect the Worker report, diff, verify log, status files, phase
metadata, phase requirements, evidence ledger, skill usage ledger, and relevant
source files. Codex must not accept based only on the Worker report.

If evidence is missing, contains `MISSING:`, verification failed, required skill
artifacts are missing, or source inspection cannot be completed, Codex must
decide `BLOCKED` or `REWORK`.

Write the audit result to:

    $AuditResultPath

The audit result must contain exactly one decision line:

    Decision: ACCEPTED

or:

    Decision: REWORK

or:

    Decision: BLOCKED
"@
$AuditInput | Set-Content -LiteralPath $AuditInputPath -Encoding utf8

$Meta = Get-Content -LiteralPath $MetaPath -Raw | ConvertFrom-Json
Set-JsonProperty -Object $Meta -Name "status" -Value $(if ($Problems.Count -eq 0) { "audit_ready" } else { "blocked_missing_evidence" })
Set-JsonProperty -Object $Meta -Name "audit_input" -Value ".ai-loop/audits/$PhaseId-audit-input.md"
Set-JsonProperty -Object $Meta -Name "audit_result" -Value ".ai-loop/audits/$PhaseId-audit.md"
Set-JsonProperty -Object $Meta -Name "audit_prepared_at" -Value (Get-Date).ToUniversalTime().ToString("o")
Write-JsonFile -Value $Meta -Path $MetaPath

if (Test-Path -LiteralPath $StatusPath) {
    $Status = Get-Content -LiteralPath $StatusPath -Raw | ConvertFrom-Json
    $PhaseStatus = if ($Problems.Count -eq 0) { "audit_ready" } else { "blocked_missing_evidence" }
    if ($null -ne $Status.current_phase -and $Status.current_phase.phase_id -eq $PhaseId) {
        Set-JsonProperty -Object $Status.current_phase -Name "status" -Value $PhaseStatus
        Set-JsonProperty -Object $Status.current_phase -Name "audit_input" -Value ".ai-loop/audits/$PhaseId-audit-input.md"
        Set-JsonProperty -Object $Status.current_phase -Name "audit_result" -Value ".ai-loop/audits/$PhaseId-audit.md"
        Set-JsonProperty -Object $Status.current_phase -Name "audit_prepared_at" -Value $Meta.audit_prepared_at
    }
    for ($Index = 0; $Index -lt @($Status.phases).Count; $Index++) {
        if ($Status.phases[$Index].phase_id -eq $PhaseId) {
            Set-JsonProperty -Object $Status.phases[$Index] -Name "status" -Value $PhaseStatus
            Set-JsonProperty -Object $Status.phases[$Index] -Name "audit_input" -Value ".ai-loop/audits/$PhaseId-audit-input.md"
            Set-JsonProperty -Object $Status.phases[$Index] -Name "audit_result" -Value ".ai-loop/audits/$PhaseId-audit.md"
            Set-JsonProperty -Object $Status.phases[$Index] -Name "audit_prepared_at" -Value $Meta.audit_prepared_at
        }
    }
    Write-JsonFile -Value $Status -Path $StatusPath
}

Write-Output "Prepared audit input: $AuditInputPath"
if ($Problems.Count -gt 0) {
    Write-Output "Missing or invalid evidence found; Codex must decide BLOCKED or REWORK."
    exit 2
}

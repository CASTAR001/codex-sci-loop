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

function ConvertTo-NormalizedArtifactPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return ($Path -replace "\\", "/").Trim()
}

function ConvertTo-AbsoluteProjectPath {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$RelativePath
    )
    return Join-Path $Root (($RelativePath -replace "/", "\").Trim())
}

function Get-ShortHash {
    param([AllowNull()][string]$Hash)
    if ([string]::IsNullOrWhiteSpace($Hash)) { return "n/a" }
    if ($Hash.Length -le 12) { return $Hash }
    return $Hash.Substring(0, 12)
}

function Get-ArtifactIntegritySummary {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [Parameter(Mandatory = $true)][string]$Phase,
        [Parameter(Mandatory = $true)][string[]]$RelativePaths,
        [Parameter(Mandatory = $true)][string]$ManifestPath
    )
    $Problems = New-Object System.Collections.Generic.List[string]
    $Rows = New-Object System.Collections.Generic.List[string]
    $Rows.Add("| Path | Manifest Status | SHA256 | Size | Check |")
    $Rows.Add("| --- | --- | --- | --- | --- |")
    $Manifest = $null
    if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
        $Problems.Add("missing artifact manifest: .ai-loop/evidence/artifact-manifest.json")
        foreach ($RelativePath in $RelativePaths) {
            $Rows.Add("| $RelativePath | missing manifest | n/a | n/a | FAIL |")
        }
        return [pscustomobject]@{ text = ($Rows -join [Environment]::NewLine); problems = @($Problems) }
    }
    try {
        $Manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
    } catch {
        $Problems.Add("invalid artifact manifest JSON: $($_.Exception.Message)")
        foreach ($RelativePath in $RelativePaths) {
            $Rows.Add("| $RelativePath | invalid manifest | n/a | n/a | FAIL |")
        }
        return [pscustomobject]@{ text = ($Rows -join [Environment]::NewLine); problems = @($Problems) }
    }
    foreach ($RelativePath in $RelativePaths) {
        $NormalizedPath = ConvertTo-NormalizedArtifactPath -Path $RelativePath
        $Record = @($Manifest.artifacts | Where-Object {
            $_.phase -eq $Phase -and (ConvertTo-NormalizedArtifactPath -Path ([string]$_.path)) -eq $NormalizedPath
        } | Select-Object -Last 1)
        $AbsolutePath = ConvertTo-AbsoluteProjectPath -Root $ProjectRoot -RelativePath $RelativePath
        if ($Record.Count -eq 0) {
            $Rows.Add("| $RelativePath | missing row | n/a | n/a | FAIL |")
            $Problems.Add("artifact manifest missing required evidence row: $RelativePath")
            continue
        }
        $Entry = $Record[0]
        if (-not (Test-Path -LiteralPath $AbsolutePath -PathType Leaf)) {
            $Rows.Add("| $RelativePath | $($Entry.status) | $(Get-ShortHash -Hash $Entry.sha256) | $($Entry.size_bytes) | FAIL missing file |")
            $Problems.Add("artifact manifest records missing file: $RelativePath")
            continue
        }
        $CurrentHash = (Get-FileHash -LiteralPath $AbsolutePath -Algorithm SHA256).Hash
        $CurrentSize = (Get-Item -LiteralPath $AbsolutePath).Length
        $Check = "OK"
        if ($Entry.status -ne "recorded") { $Check = "FAIL status=$($Entry.status)" }
        elseif ($CurrentHash -ne $Entry.sha256) { $Check = "FAIL hash mismatch" }
        elseif ([int64]$CurrentSize -ne [int64]$Entry.size_bytes) { $Check = "FAIL size mismatch" }
        if ($Check -ne "OK") {
            $Problems.Add("artifact integrity failed for ${RelativePath}: $Check")
        }
        $Rows.Add("| $RelativePath | $($Entry.status) | $(Get-ShortHash -Hash $Entry.sha256) | $($Entry.size_bytes) | $Check |")
    }
    return [pscustomobject]@{ text = ($Rows -join [Environment]::NewLine); problems = @($Problems) }
}

$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$LoopDir = Join-Path $ProjectRoot ".ai-loop"
$RunDir = Join-Path $LoopDir (Join-Path "runs" $PhaseId)
$AuditDir = Join-Path $LoopDir "audits"
$StatusPath = Join-Path $LoopDir "status.json"
$MetaPath = Join-Path $RunDir "phase_meta.json"
$ArtifactManifestPath = Join-Path $LoopDir "evidence\artifact-manifest.json"

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

$RequiredArtifactPaths = @(
    ".ai-loop/runs/$PhaseId/prompt.md",
    ".ai-loop/runs/$PhaseId/report.md",
    ".ai-loop/runs/$PhaseId/status_after.txt",
    ".ai-loop/runs/$PhaseId/diff.patch",
    ".ai-loop/runs/$PhaseId/verify.log",
    ".ai-loop/runs/$PhaseId/changed_files.txt",
    ".ai-loop/runs/$PhaseId/changed_business_files.txt",
    ".ai-loop/runs/$PhaseId/changed_evidence_files.txt",
    ".ai-loop/runs/$PhaseId/phase_requirements.json"
)
$WorkerEvidenceText = "None declared."
$RequirementsPath = Join-Path $RunDir "phase_requirements.json"
if (Test-Path -LiteralPath $RequirementsPath -PathType Leaf) {
    try {
        $Requirements = Get-Content -LiteralPath $RequirementsPath -Raw | ConvertFrom-Json
        if ($null -ne $Requirements.PSObject.Properties["evidence_required"]) {
            $RequiredArtifactPaths = @($Requirements.evidence_required) + @(".ai-loop/runs/$PhaseId/phase_requirements.json")
        }
        if ($null -ne $Requirements.PSObject.Properties["required_worker_evidence"] -and @($Requirements.required_worker_evidence).Count -gt 0) {
            $WorkerEvidenceText = (@($Requirements.required_worker_evidence) | ForEach-Object {
                "- $($_.path) [$($_.kind)] required=$($_.required); produced_by=$($_.produced_by)"
            }) -join [Environment]::NewLine
        }
    } catch {
        $Problems.Add("phase_requirements.json cannot be parsed for artifact integrity summary: $($_.Exception.Message)")
    }
}

$ArtifactSummary = Get-ArtifactIntegritySummary -ProjectRoot $ProjectRoot -Phase $PhaseId -RelativePaths $RequiredArtifactPaths -ManifestPath $ArtifactManifestPath
foreach ($ArtifactProblem in @($ArtifactSummary.problems)) {
    $Problems.Add($ArtifactProblem)
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
- artifact manifest: $(Join-Path $LoopDir "evidence\artifact-manifest.json")
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

## Artifact Integrity Summary

$($ArtifactSummary.text)

## External Worker Evidence Requirements

$WorkerEvidenceText

## Missing Or Invalid Evidence

$ProblemText

## Phase Gate Validation

``````text
$GateText
``````

## Audit Instructions

Codex must inspect the Worker report, diff, verify log, status files, phase
metadata, phase requirements, evidence ledger, skill usage ledger, and relevant
source files. Codex must not accept based only on the Worker report.

If evidence is missing, contains `MISSING:`, verification failed, required skill
artifacts are missing, artifact integrity is missing or mismatched, or source
inspection cannot be completed, Codex must decide `BLOCKED` or `REWORK`.

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
$PreviousStatusForTransition = [string]$Meta.status
$PhaseStatus = if ($Problems.Count -eq 0) { "audit_ready" } else { "blocked_missing_evidence" }
Set-JsonProperty -Object $Meta -Name "status" -Value $PhaseStatus
Set-JsonProperty -Object $Meta -Name "audit_input" -Value ".ai-loop/audits/$PhaseId-audit-input.md"
Set-JsonProperty -Object $Meta -Name "audit_result" -Value ".ai-loop/audits/$PhaseId-audit.md"
Set-JsonProperty -Object $Meta -Name "audit_prepared_at" -Value (Get-Date).ToUniversalTime().ToString("o")
Set-JsonProperty -Object $Meta -Name "transition_log" -Value ".ai-loop/events/state-transitions.ndjson"
Write-JsonFile -Value $Meta -Path $MetaPath

if (Test-Path -LiteralPath $StatusPath) {
    $Status = Get-Content -LiteralPath $StatusPath -Raw | ConvertFrom-Json
    if ($null -ne $Status.current_phase -and $Status.current_phase.phase_id -eq $PhaseId) {
        Set-JsonProperty -Object $Status.current_phase -Name "status" -Value $PhaseStatus
        Set-JsonProperty -Object $Status.current_phase -Name "audit_input" -Value ".ai-loop/audits/$PhaseId-audit-input.md"
        Set-JsonProperty -Object $Status.current_phase -Name "audit_result" -Value ".ai-loop/audits/$PhaseId-audit.md"
        Set-JsonProperty -Object $Status.current_phase -Name "audit_prepared_at" -Value $Meta.audit_prepared_at
        Set-JsonProperty -Object $Status.current_phase -Name "transition_log" -Value ".ai-loop/events/state-transitions.ndjson"
    }
    for ($Index = 0; $Index -lt @($Status.phases).Count; $Index++) {
        if ($Status.phases[$Index].phase_id -eq $PhaseId) {
            Set-JsonProperty -Object $Status.phases[$Index] -Name "status" -Value $PhaseStatus
            Set-JsonProperty -Object $Status.phases[$Index] -Name "audit_input" -Value ".ai-loop/audits/$PhaseId-audit-input.md"
            Set-JsonProperty -Object $Status.phases[$Index] -Name "audit_result" -Value ".ai-loop/audits/$PhaseId-audit.md"
            Set-JsonProperty -Object $Status.phases[$Index] -Name "audit_prepared_at" -Value $Meta.audit_prepared_at
            Set-JsonProperty -Object $Status.phases[$Index] -Name "transition_log" -Value ".ai-loop/events/state-transitions.ndjson"
        }
    }
    Write-JsonFile -Value $Status -Path $StatusPath
}
& (Join-Path $PSScriptRoot "record-state-transition.ps1") `
    -ProjectRoot $ProjectRoot `
    -PhaseId $PhaseId `
    -FromStatus $PreviousStatusForTransition `
    -ToStatus $PhaseStatus `
    -Actor "prepare-audit-pack.ps1" `
    -Action "audit-pack" `
    -Reason "Prepared audit input." `
    -Paths @(".ai-loop/status.json", ".ai-loop/runs/$PhaseId/phase_meta.json", ".ai-loop/audits/$PhaseId-audit-input.md", ".ai-loop/events/state-transitions.ndjson")

Write-Output "Prepared audit input: $AuditInputPath"
if ($Problems.Count -gt 0) {
    Write-Output "Missing or invalid evidence found; Codex must decide BLOCKED or REWORK."
    exit 2
}

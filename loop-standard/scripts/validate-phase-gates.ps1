[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][string]$PhaseId,
    [ValidateSet("started", "evidence_collected", "audit_ready", "accepted")]
    [string]$TargetStatus = "audit_ready",
    [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Add-Problem {
    param([Parameter(Mandatory = $true)][string]$Message)
    $script:Problems.Add($Message)
}

function Test-NonEmptyFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return "missing"
    }
    $Item = Get-Item -LiteralPath $Path
    if ($Item.Length -eq 0) {
        return "empty"
    }
    $Text = Get-Content -LiteralPath $Path -Raw
    if ($Text -match "(?m)^\s*MISSING:") {
        return "contains MISSING placeholder"
    }
    return ""
}

function ConvertTo-AbsoluteProjectPath {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$RelativePath
    )
    $Normalized = $RelativePath -replace "/", "\"
    return Join-Path $Root $Normalized
}

function Test-LedgerMentions {
    param(
        [Parameter(Mandatory = $true)][string]$LedgerPath,
        [Parameter(Mandatory = $true)][string]$Phase,
        [Parameter(Mandatory = $true)][string]$Needle
    )
    if (-not (Test-Path -LiteralPath $LedgerPath -PathType Leaf)) {
        return $false
    }
    $Hits = @(Select-String -LiteralPath $LedgerPath -SimpleMatch -Pattern $Needle)
    foreach ($Hit in $Hits) {
        if ($Hit.Line -like "*| $Phase |*" -or $Hit.Line -like "*|$Phase|*") {
            return $true
        }
    }
    return $false
}

function Get-VerifyExitCode {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    $Text = Get-Content -LiteralPath $Path -Raw
    if ($Text -match "(?m)^exit_code:\s*(-?\d+)\s*$") {
        return [int]$Matches[1]
    }
    return $null
}

function ConvertTo-NormalizedArtifactPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return ($Path -replace "\\", "/").Trim()
}

function Read-ArtifactManifest {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Add-Problem "missing artifact manifest: .ai-loop/evidence/artifact-manifest.json; rerun collect evidence"
        return $null
    }
    try {
        $Manifest = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
        if ($null -eq $Manifest.PSObject.Properties["artifacts"]) {
            Add-Problem "artifact manifest missing artifacts array"
            return $null
        }
        return $Manifest
    } catch {
        Add-Problem "invalid artifact manifest JSON: $($_.Exception.Message)"
        return $null
    }
}

function Find-ArtifactRecord {
    param(
        [AllowNull()]$Manifest,
        [Parameter(Mandatory = $true)][string]$Phase,
        [Parameter(Mandatory = $true)][string]$RelativePath
    )
    if ($null -eq $Manifest) { return $null }
    $Normalized = ConvertTo-NormalizedArtifactPath -Path $RelativePath
    $Matches = @($Manifest.artifacts | Where-Object {
        $_.phase -eq $Phase -and (ConvertTo-NormalizedArtifactPath -Path ([string]$_.path)) -eq $Normalized
    })
    if ($Matches.Count -eq 0) { return $null }
    return $Matches[-1]
}

function Test-ArtifactManifestRecord {
    param(
        [AllowNull()]$Manifest,
        [Parameter(Mandatory = $true)][string]$Phase,
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [switch]$Required
    )
    $Record = Find-ArtifactRecord -Manifest $Manifest -Phase $Phase -RelativePath $RelativePath
    if ($null -eq $Record) {
        if ($Required) {
            Add-Problem "artifact manifest missing required evidence row: $RelativePath"
        }
        return
    }
    $AbsolutePath = ConvertTo-AbsoluteProjectPath -Root $ProjectRoot -RelativePath $RelativePath
    if (-not (Test-Path -LiteralPath $AbsolutePath -PathType Leaf)) {
        Add-Problem "artifact manifest records missing file: $RelativePath"
        return
    }
    if ($Record.status -ne "recorded") {
        Add-Problem "artifact manifest marks required evidence invalid: $RelativePath status=$($Record.status)"
    }
    $CurrentHash = (Get-FileHash -LiteralPath $AbsolutePath -Algorithm SHA256).Hash
    if ([string]::IsNullOrWhiteSpace([string]$Record.sha256)) {
        Add-Problem "artifact manifest missing sha256 for $RelativePath"
    } elseif ($CurrentHash -ne $Record.sha256) {
        Add-Problem "artifact hash mismatch for $RelativePath"
    }
    $CurrentSize = (Get-Item -LiteralPath $AbsolutePath).Length
    if ($null -ne $Record.PSObject.Properties["size_bytes"] -and [int64]$Record.size_bytes -ne [int64]$CurrentSize) {
        Add-Problem "artifact size mismatch for $RelativePath"
    }
}

$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$Problems = New-Object System.Collections.Generic.List[string]
$LoopDir = Join-Path $ProjectRoot ".ai-loop"
$StatusPath = Join-Path $LoopDir "status.json"
$RunDir = Join-Path $LoopDir (Join-Path "runs" $PhaseId)
$MetaPath = Join-Path $RunDir "phase_meta.json"
$RequirementsPath = Join-Path $RunDir "phase_requirements.json"
$EvidenceLedger = Join-Path $LoopDir "evidence\evidence-ledger.md"
$ArtifactManifestPath = Join-Path $LoopDir "evidence\artifact-manifest.json"
$SkillUsageLedger = Join-Path $LoopDir "skills\skill-usage-ledger.md"
$SkillSourceMap = Join-Path $LoopDir "skills\skill-source-map.md"
$ArtifactManifest = Read-ArtifactManifest -Path $ArtifactManifestPath

if (-not (Test-Path -LiteralPath $StatusPath -PathType Leaf)) {
    Add-Problem "missing .ai-loop/status.json"
}
if (-not (Test-Path -LiteralPath $MetaPath -PathType Leaf)) {
    Add-Problem "missing phase metadata: .ai-loop/runs/$PhaseId/phase_meta.json"
}

$Meta = $null
if (Test-Path -LiteralPath $MetaPath -PathType Leaf) {
    try {
        $Meta = Get-Content -LiteralPath $MetaPath -Raw | ConvertFrom-Json
    } catch {
        Add-Problem "invalid phase metadata JSON: $($_.Exception.Message)"
    }
}

if ($null -ne $Meta) {
    $CurrentStatus = $Meta.status
    if ($TargetStatus -eq "audit_ready" -and $CurrentStatus -notin @("evidence_collected", "audit_ready", "blocked_missing_evidence")) {
        Add-Problem "illegal transition to audit_ready from status '$CurrentStatus'"
    }
    if ($TargetStatus -eq "accepted" -and $CurrentStatus -notin @("audit_ready", "accepted")) {
        Add-Problem "illegal transition to accepted from status '$CurrentStatus'"
    }
}

$Requirements = $null
if (Test-Path -LiteralPath $RequirementsPath -PathType Leaf) {
    try {
        $Requirements = Get-Content -LiteralPath $RequirementsPath -Raw | ConvertFrom-Json
    } catch {
        Add-Problem "invalid phase requirements JSON: $($_.Exception.Message)"
    }
} else {
    Add-Problem "missing phase requirements: .ai-loop/runs/$PhaseId/phase_requirements.json"
}

$RequiredEvidence = @(
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
if ($null -ne $Requirements -and $null -ne $Requirements.evidence_required) {
    $RequiredEvidence = @($Requirements.evidence_required) + @(".ai-loop/runs/$PhaseId/phase_requirements.json")
}

foreach ($RelativePath in $RequiredEvidence) {
    $AbsolutePath = ConvertTo-AbsoluteProjectPath -Root $ProjectRoot -RelativePath $RelativePath
    $Result = Test-NonEmptyFile -Path $AbsolutePath
    if (-not [string]::IsNullOrWhiteSpace($Result)) {
        Add-Problem "$RelativePath $Result"
        continue
    }
    if ($RelativePath -notlike "*phase_requirements.json" -and -not (Test-LedgerMentions -LedgerPath $EvidenceLedger -Phase $PhaseId -Needle $RelativePath)) {
        Add-Problem "evidence ledger missing row for $RelativePath"
    }
    Test-ArtifactManifestRecord -Manifest $ArtifactManifest -Phase $PhaseId -RelativePath $RelativePath -Required
}

$VerifyLog = Join-Path $RunDir "verify.log"
$VerifyExitCode = Get-VerifyExitCode -Path $VerifyLog
if ($null -eq $VerifyExitCode) {
    Add-Problem "verify.log missing parseable exit_code"
} elseif ($VerifyExitCode -ne 0) {
    Add-Problem "verification failed with exit_code $VerifyExitCode"
}

if ($null -ne $Requirements) {
    foreach ($Requirement in @($Requirements.required_skill_artifacts)) {
        if ($null -eq $Requirement) { continue }
        $Skill = [string]$Requirement.skill
        if ([string]::IsNullOrWhiteSpace($Skill)) { continue }
        if (-not (Test-LedgerMentions -LedgerPath $SkillUsageLedger -Phase $PhaseId -Needle $Skill)) {
            Add-Problem "skill usage ledger missing required skill row: $Skill"
        }
        $ProjectSkillPath = Join-Path $ProjectRoot ".agents\skills\$Skill\SKILL.md"
        $ProjectSkillResult = Test-NonEmptyFile -Path $ProjectSkillPath
        if (-not [string]::IsNullOrWhiteSpace($ProjectSkillResult)) {
            Add-Problem "required skill is not available in .agents/skills: $Skill ($ProjectSkillResult)"
        }
        if (-not (Test-LedgerMentions -LedgerPath $SkillSourceMap -Phase $Skill -Needle $Skill)) {
            Add-Problem "skill source map missing required skill row: $Skill"
        } elseif (-not (Select-String -LiteralPath $SkillSourceMap -SimpleMatch -Pattern "| $Skill " | Where-Object { $_.Line -match "\|\s*available\s*\|" })) {
            Add-Problem "skill source map does not mark required skill available: $Skill"
        }
        foreach ($Artifact in @($Requirement.artifacts)) {
            if ([string]::IsNullOrWhiteSpace($Artifact)) {
                Add-Problem "required skill $Skill has blank artifact path"
                continue
            }
            $ArtifactPath = ConvertTo-AbsoluteProjectPath -Root $ProjectRoot -RelativePath ([string]$Artifact)
            $ArtifactResult = Test-NonEmptyFile -Path $ArtifactPath
            if (-not [string]::IsNullOrWhiteSpace($ArtifactResult)) {
                Add-Problem "required skill artifact for $Skill missing or invalid: $Artifact ($ArtifactResult)"
            }
            Test-ArtifactManifestRecord -Manifest $ArtifactManifest -Phase $PhaseId -RelativePath ([string]$Artifact)
        }
    }
}

if (-not $Quiet) {
    if ($Problems.Count -eq 0) {
        Write-Output "Phase gate validation: OK"
        Write-Output "Project root: $ProjectRoot"
        Write-Output "Phase: $PhaseId"
        Write-Output "Target status: $TargetStatus"
    } else {
        Write-Output "Phase gate validation: FAILED"
        Write-Output "Project root: $ProjectRoot"
        Write-Output "Phase: $PhaseId"
        Write-Output "Target status: $TargetStatus"
        foreach ($Problem in $Problems) {
            Write-Output "- $Problem"
        }
    }
}

if ($Problems.Count -gt 0) {
    exit 2
}

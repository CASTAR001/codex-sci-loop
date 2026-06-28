[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][string]$SourcePhaseId,
    [Parameter(Mandatory = $true)][string]$ReworkPhaseId,
    [string]$Title = "",
    [string]$Objective = "",
    [string]$VerifyCommand = "",
    [string[]]$Scope = @(),
    [ValidateSet("", "generic", "fullstack", "physics-research", "research-writing", "data-analysis")]
    [string]$TaskKind = "",
    [ValidateSet("", "none", "research-core", "physics-sim", "manuscript", "full-research")]
    [string]$SkillProfile = "",
    [ValidateSet("research-task-tree", "invariant-contract", "bounded-experiment-loop", "deterministic-verification", "independent-crosscheck", "result-provenance-audit", "manuscript-consistency-audit", "skill-compliance-audit")]
    [string[]]$RequiredSkills = @(),
    [string[]]$ClaimIds = @(),
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-JsonFile {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string]$Path
    )
    $Value | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $Path -Encoding utf8
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

function Add-EventLogEntry {
    param(
        [Parameter(Mandatory = $true)][string]$LoopDir,
        [Parameter(Mandatory = $true)]$Event
    )
    $EventDir = Join-Path $LoopDir "events"
    New-Item -ItemType Directory -Force -Path $EventDir | Out-Null
    $EventLog = Join-Path $EventDir "event-log.ndjson"
    ($Event | ConvertTo-Json -Depth 20 -Compress) | Add-Content -LiteralPath $EventLog -Encoding utf8
}

function Get-NonEmptyLines {
    param([Parameter(Mandatory = $true)][string]$Text)
    return @($Text -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$LoopDir = Join-Path $ProjectRoot ".ai-loop"
$StatusPath = Join-Path $LoopDir "status.json"
$SourceRunDir = Join-Path $LoopDir (Join-Path "runs" $SourcePhaseId)
$SourceMetaPath = Join-Path $SourceRunDir "phase_meta.json"
$SourceAuditPath = Join-Path $LoopDir (Join-Path "audits" "$SourcePhaseId-audit.md")
$SourceFindingsPath = Join-Path $LoopDir (Join-Path "audits" "$SourcePhaseId-findings.json")
$SourceDecisionPath = Join-Path $SourceRunDir "rework.txt"

foreach ($RequiredPath in @($StatusPath, $SourceMetaPath, $SourceAuditPath)) {
    if (-not (Test-Path -LiteralPath $RequiredPath -PathType Leaf)) {
        throw "Missing required REWORK source file: $RequiredPath"
    }
}

$SourceMeta = Get-Content -LiteralPath $SourceMetaPath -Raw | ConvertFrom-Json
if ([string]$SourceMeta.status -ne "rework") {
    throw "Cannot scaffold rework from $SourcePhaseId because status is '$($SourceMeta.status)', not 'rework'."
}
if ([string]$SourceMeta.decision -ne "REWORK") {
    throw "Cannot scaffold rework from $SourcePhaseId because phase metadata decision is not REWORK."
}
if (-not (Test-Path -LiteralPath $SourceDecisionPath -PathType Leaf)) {
    throw "Missing required REWORK source file: $SourceDecisionPath"
}

$AuditText = Get-Content -LiteralPath $SourceAuditPath -Raw
if ($AuditText -notmatch "(?m)^\s*Decision:\s*REWORK\s*$") {
    throw "Cannot scaffold rework because audit result does not contain 'Decision: REWORK'."
}
$DecisionText = Get-Content -LiteralPath $SourceDecisionPath -Raw
if ($DecisionText -notmatch "(?m)^\s*decision:\s*REWORK\s*$") {
    throw "Cannot scaffold rework because rework.txt does not contain decision: REWORK."
}

$AuditLines = @(Get-NonEmptyLines -Text $AuditText | Where-Object {
    $_ -notmatch "^\s*#+" -and $_ -notmatch "^\s*Decision:\s*REWORK\s*$"
} | Select-Object -First 12)
$DecisionLines = @(Get-NonEmptyLines -Text $DecisionText | Where-Object {
    $_ -match "^(reason|next_safe_action):"
})
$StructuredFindings = @()
if (Test-Path -LiteralPath $SourceFindingsPath -PathType Leaf) {
    try {
        $FindingsDoc = Get-Content -LiteralPath $SourceFindingsPath -Raw | ConvertFrom-Json
        if ([string]$FindingsDoc.phase_id -eq $SourcePhaseId) {
            $StructuredFindings = @($FindingsDoc.findings)
        }
    } catch {
        throw "Invalid audit findings JSON: $SourceFindingsPath :: $($_.Exception.Message)"
    }
}
$DerivedScope = New-Object System.Collections.Generic.List[string]
$DerivedScope.Add("REWORK follow-up for source phase `$SourcePhaseId`.")
$DerivedScope.Add("Use `.ai-loop/audits/$SourcePhaseId-audit.md` and `.ai-loop/runs/$SourcePhaseId/rework.txt` as fixed scope inputs.")
if (Test-Path -LiteralPath $SourceFindingsPath -PathType Leaf) {
    $DerivedScope.Add("Use `.ai-loop/audits/$SourcePhaseId-findings.json` as the structured audit findings source.")
}
$DerivedScope.Add("Do not broaden beyond the audit findings unless the Supervisor starts a separate phase.")
foreach ($Line in $DecisionLines) {
    $DerivedScope.Add("Source decision: $Line")
}
if ($StructuredFindings.Count -gt 0) {
    foreach ($Finding in $StructuredFindings) {
        $FindingId = [string]$Finding.finding_id
        $Summary = [string]$Finding.summary
        if (-not [string]::IsNullOrWhiteSpace($Summary)) {
            $DerivedScope.Add("Structured audit finding ${FindingId}: $Summary")
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$Finding.severity)) {
            $DerivedScope.Add("Finding ${FindingId} severity: $($Finding.severity)")
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$Finding.required_fix)) {
            $DerivedScope.Add("Required fix for ${FindingId}: $($Finding.required_fix)")
        }
        foreach ($File in @($Finding.files)) {
            if (-not [string]::IsNullOrWhiteSpace([string]$File)) {
                $DerivedScope.Add("Finding ${FindingId} file: $File")
            }
        }
        foreach ($Evidence in @($Finding.evidence)) {
            if (-not [string]::IsNullOrWhiteSpace([string]$Evidence)) {
                $DerivedScope.Add("Finding ${FindingId} evidence: $Evidence")
            }
        }
    }
} else {
    foreach ($Line in $AuditLines) {
        $DerivedScope.Add("Audit finding: $Line")
    }
}
foreach ($Line in $Scope) {
    if (-not [string]::IsNullOrWhiteSpace($Line)) {
        $DerivedScope.Add($Line)
    }
}

$ResolvedTitle = if ([string]::IsNullOrWhiteSpace($Title)) { "Rework for $SourcePhaseId" } else { $Title }
$ResolvedObjective = if ([string]::IsNullOrWhiteSpace($Objective)) {
    "Address only the REWORK findings from $SourcePhaseId and produce fresh evidence for audit."
} else {
    $Objective
}
$ResolvedVerifyCommand = if ([string]::IsNullOrWhiteSpace($VerifyCommand)) { [string]$SourceMeta.verify_command } else { $VerifyCommand }
$ResolvedTaskKind = if ([string]::IsNullOrWhiteSpace($TaskKind)) { [string]$SourceMeta.task_kind } else { $TaskKind }
if ([string]::IsNullOrWhiteSpace($ResolvedTaskKind)) { $ResolvedTaskKind = "generic" }
$ResolvedSkillProfile = if ([string]::IsNullOrWhiteSpace($SkillProfile)) { [string]$SourceMeta.skill_profile } else { $SkillProfile }
if ([string]::IsNullOrWhiteSpace($ResolvedSkillProfile)) { $ResolvedSkillProfile = "none" }
$ResolvedRequiredSkills = if (@($RequiredSkills).Count -gt 0) { @($RequiredSkills) } else { @($SourceMeta.required_skills) }
$ResolvedClaimIds = if (@($ClaimIds).Count -gt 0) { @($ClaimIds) } else { @("REWORK-$SourcePhaseId") }

$StartParams = @{
    ProjectRoot = $ProjectRoot
    PhaseId = $ReworkPhaseId
    Title = $ResolvedTitle
    Objective = $ResolvedObjective
    Scope = @($DerivedScope)
    VerifyCommand = $ResolvedVerifyCommand
    TaskKind = $ResolvedTaskKind
    SkillProfile = $ResolvedSkillProfile
    ClaimIds = @($ResolvedClaimIds)
}
if (@($ResolvedRequiredSkills).Count -gt 0) { $StartParams.RequiredSkills = @($ResolvedRequiredSkills) }
if ($Force) { $StartParams.Force = $true }

& (Join-Path $PSScriptRoot "start-phase.ps1") @StartParams
if ($LASTEXITCODE -ne 0 -or -not $?) {
    exit 1
}

$ReworkRunDir = Join-Path $LoopDir (Join-Path "runs" $ReworkPhaseId)
$ReworkMetaPath = Join-Path $ReworkRunDir "phase_meta.json"
$ReworkSource = [ordered]@{
    source_phase_id = $SourcePhaseId
    source_status = "rework"
    source_audit = ".ai-loop/audits/$SourcePhaseId-audit.md"
    source_findings = if (Test-Path -LiteralPath $SourceFindingsPath -PathType Leaf) { ".ai-loop/audits/$SourcePhaseId-findings.json" } else { "" }
    source_decision_file = ".ai-loop/runs/$SourcePhaseId/rework.txt"
    scaffolded_phase_id = $ReworkPhaseId
    scaffolded_at = (Get-Date).ToUniversalTime().ToString("o")
    structured_findings_count = $StructuredFindings.Count
    structured_findings = @($StructuredFindings)
    scope = @($DerivedScope)
}
Write-JsonFile -Value ([pscustomobject]$ReworkSource) -Path (Join-Path $ReworkRunDir "rework_source.json")

$ReworkMeta = Get-Content -LiteralPath $ReworkMetaPath -Raw | ConvertFrom-Json
Set-JsonProperty -Object $ReworkMeta -Name "rework_source" -Value ".ai-loop/runs/$ReworkPhaseId/rework_source.json"
Set-JsonProperty -Object $ReworkMeta -Name "source_phase_id" -Value $SourcePhaseId
Write-JsonFile -Value $ReworkMeta -Path $ReworkMetaPath

$Status = Get-Content -LiteralPath $StatusPath -Raw | ConvertFrom-Json
if ($null -ne $Status.current_phase -and [string]$Status.current_phase.phase_id -eq $ReworkPhaseId) {
    Set-JsonProperty -Object $Status.current_phase -Name "rework_source" -Value ".ai-loop/runs/$ReworkPhaseId/rework_source.json"
    Set-JsonProperty -Object $Status.current_phase -Name "source_phase_id" -Value $SourcePhaseId
}
for ($Index = 0; $Index -lt @($Status.phases).Count; $Index++) {
    if ([string]$Status.phases[$Index].phase_id -eq $ReworkPhaseId) {
        Set-JsonProperty -Object $Status.phases[$Index] -Name "rework_source" -Value ".ai-loop/runs/$ReworkPhaseId/rework_source.json"
        Set-JsonProperty -Object $Status.phases[$Index] -Name "source_phase_id" -Value $SourcePhaseId
    }
}
Write-JsonFile -Value $Status -Path $StatusPath

Add-EventLogEntry -LoopDir $LoopDir -Event ([ordered]@{
    ts = $ReworkSource.scaffolded_at
    type = "rework_scaffold"
    actor = "Codex Supervisor"
    summary = "Scaffolded $ReworkPhaseId from REWORK decision on $SourcePhaseId"
    phase = $ReworkPhaseId
    source_phase = $SourcePhaseId
    result = "started"
    evidence = @(".ai-loop/audits/$SourcePhaseId-audit.md", ".ai-loop/runs/$SourcePhaseId/rework.txt", ".ai-loop/runs/$ReworkPhaseId/rework_source.json")
    paths = @(".ai-loop/status.json", ".ai-loop/runs/$ReworkPhaseId/phase_meta.json", ".ai-loop/runs/$ReworkPhaseId/prompt.md", ".ai-loop/events/event-log.ndjson")
})

Write-Output "Scaffolded rework phase $ReworkPhaseId from $SourcePhaseId"
Write-Output "Rework source: $(Join-Path $ReworkRunDir "rework_source.json")"

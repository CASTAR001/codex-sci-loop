[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][string]$PhaseId,
    [Parameter(Mandatory = $true)]
    [ValidateSet("REWORK", "BLOCKED")]
    [string]$Decision,
    [string]$AuditPath = "",
    [string]$Reason = "",
    [string]$NextSafeAction = "",
    [switch]$Force
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

$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$LoopDir = Join-Path $ProjectRoot ".ai-loop"
$RunDir = Join-Path $LoopDir (Join-Path "runs" $PhaseId)
$AuditDir = Join-Path $LoopDir "audits"
$AuditResultPath = Join-Path $AuditDir "$PhaseId-audit.md"
$MetaPath = Join-Path $RunDir "phase_meta.json"
$StatusPath = Join-Path $LoopDir "status.json"

if (-not (Test-Path -LiteralPath $MetaPath -PathType Leaf)) {
    throw "Missing phase metadata: $MetaPath"
}
New-Item -ItemType Directory -Force -Path $AuditDir | Out-Null

if (-not [string]::IsNullOrWhiteSpace($AuditPath)) {
    Copy-Item -LiteralPath (Resolve-Path -LiteralPath $AuditPath).Path -Destination $AuditResultPath -Force
}
if (-not (Test-Path -LiteralPath $AuditResultPath -PathType Leaf)) {
    throw "Missing audit result: $AuditResultPath"
}

$AuditText = Get-Content -LiteralPath $AuditResultPath -Raw
if ($AuditText -notmatch "(?m)^\s*Decision:\s*$Decision\s*$") {
    throw "Cannot record $Decision because audit result does not contain 'Decision: $Decision'."
}

$FindingsPath = Join-Path $AuditDir "$PhaseId-findings.json"
$ExtractorPath = Join-Path $PSScriptRoot "extract-audit-findings.ps1"
if (Test-Path -LiteralPath $ExtractorPath -PathType Leaf) {
    & $ExtractorPath -ProjectRoot $ProjectRoot -PhaseId $PhaseId -AuditPath $AuditResultPath -OutputPath $FindingsPath | Out-Null
} else {
    throw "Missing audit finding extractor: $ExtractorPath"
}

$Meta = Get-Content -LiteralPath $MetaPath -Raw | ConvertFrom-Json
$PreviousStatusForTransition = [string]$Meta.status
if ($Meta.status -notin @("evidence_collected", "audit_ready", "rework", "blocked", "blocked_missing_evidence") -and -not $Force) {
    throw "Cannot record $Decision from status '$($Meta.status)'. Expected evidence_collected, audit_ready, rework, blocked, or blocked_missing_evidence."
}

$DecisionLower = $Decision.ToLowerInvariant()
$DecidedAt = (Get-Date).ToUniversalTime().ToString("o")
$DecisionFileName = if ($Decision -eq "REWORK") { "rework.txt" } else { "blocked.txt" }
$DecisionFilePath = Join-Path $RunDir $DecisionFileName

$DefaultAction = if ($Decision -eq "REWORK") {
    "Start a bounded rework phase using the audit findings as scope."
} else {
    "Resolve the blocker before starting or accepting another phase."
}
$Action = if ([string]::IsNullOrWhiteSpace($NextSafeAction)) { $DefaultAction } else { $NextSafeAction }

@(
    "decision: $Decision"
    "decided_at: $DecidedAt"
    "audit: .ai-loop/audits/$PhaseId-audit.md"
    "reason: $Reason"
    "next_safe_action: $Action"
) | Set-Content -LiteralPath $DecisionFilePath -Encoding utf8

Set-JsonProperty -Object $Meta -Name "status" -Value $DecisionLower
Set-JsonProperty -Object $Meta -Name "decided_at" -Value $DecidedAt
Set-JsonProperty -Object $Meta -Name "decision" -Value $Decision
Set-JsonProperty -Object $Meta -Name "decision_reason" -Value $Reason
Set-JsonProperty -Object $Meta -Name "next_safe_action" -Value $Action
Set-JsonProperty -Object $Meta -Name "audit_result" -Value ".ai-loop/audits/$PhaseId-audit.md"
Set-JsonProperty -Object $Meta -Name "audit_findings" -Value ".ai-loop/audits/$PhaseId-findings.json"
Set-JsonProperty -Object $Meta -Name "transition_log" -Value ".ai-loop/events/state-transitions.ndjson"
Write-JsonFile -Value $Meta -Path $MetaPath

if (Test-Path -LiteralPath $StatusPath -PathType Leaf) {
    $Status = Get-Content -LiteralPath $StatusPath -Raw | ConvertFrom-Json
    $Status.last_decision = [ordered]@{
        phase_id = $PhaseId
        decision = $Decision
        audit = ".ai-loop/audits/$PhaseId-audit.md"
        findings = ".ai-loop/audits/$PhaseId-findings.json"
        decided_at = $DecidedAt
        reason = $Reason
        next_safe_action = $Action
    }
    if ($null -ne $Status.current_phase -and $Status.current_phase.phase_id -eq $PhaseId) {
        Set-JsonProperty -Object $Status.current_phase -Name "status" -Value $DecisionLower
        Set-JsonProperty -Object $Status.current_phase -Name "decided_at" -Value $DecidedAt
        Set-JsonProperty -Object $Status.current_phase -Name "decision" -Value $Decision
        Set-JsonProperty -Object $Status.current_phase -Name "decision_reason" -Value $Reason
        Set-JsonProperty -Object $Status.current_phase -Name "next_safe_action" -Value $Action
        Set-JsonProperty -Object $Status.current_phase -Name "audit_result" -Value ".ai-loop/audits/$PhaseId-audit.md"
        Set-JsonProperty -Object $Status.current_phase -Name "audit_findings" -Value ".ai-loop/audits/$PhaseId-findings.json"
        Set-JsonProperty -Object $Status.current_phase -Name "transition_log" -Value ".ai-loop/events/state-transitions.ndjson"
    }
    for ($Index = 0; $Index -lt @($Status.phases).Count; $Index++) {
        if ($Status.phases[$Index].phase_id -eq $PhaseId) {
            Set-JsonProperty -Object $Status.phases[$Index] -Name "status" -Value $DecisionLower
            Set-JsonProperty -Object $Status.phases[$Index] -Name "decided_at" -Value $DecidedAt
            Set-JsonProperty -Object $Status.phases[$Index] -Name "decision" -Value $Decision
            Set-JsonProperty -Object $Status.phases[$Index] -Name "decision_reason" -Value $Reason
            Set-JsonProperty -Object $Status.phases[$Index] -Name "next_safe_action" -Value $Action
            Set-JsonProperty -Object $Status.phases[$Index] -Name "audit_result" -Value ".ai-loop/audits/$PhaseId-audit.md"
            Set-JsonProperty -Object $Status.phases[$Index] -Name "audit_findings" -Value ".ai-loop/audits/$PhaseId-findings.json"
            Set-JsonProperty -Object $Status.phases[$Index] -Name "transition_log" -Value ".ai-loop/events/state-transitions.ndjson"
        }
    }
    Write-JsonFile -Value $Status -Path $StatusPath
}

Add-EventLogEntry -LoopDir $LoopDir -Event ([ordered]@{
    ts = $DecidedAt
    type = "phase_decision"
    actor = "Codex Supervisor"
    summary = "Recorded $Decision for $PhaseId"
    phase = $PhaseId
    result = $Decision
    reason = $Reason
    next_safe_action = $Action
    evidence = @(".ai-loop/audits/$PhaseId-audit.md", ".ai-loop/audits/$PhaseId-findings.json", ".ai-loop/runs/$PhaseId/$DecisionFileName")
    paths = @(".ai-loop/status.json", ".ai-loop/runs/$PhaseId/phase_meta.json", ".ai-loop/events/event-log.ndjson")
})
& (Join-Path $PSScriptRoot "record-state-transition.ps1") `
    -ProjectRoot $ProjectRoot `
    -PhaseId $PhaseId `
    -FromStatus $PreviousStatusForTransition `
    -ToStatus $DecisionLower `
    -Actor "decide-phase.ps1" `
    -Action "decide" `
    -Reason $Reason `
    -Paths @(".ai-loop/status.json", ".ai-loop/runs/$PhaseId/phase_meta.json", ".ai-loop/audits/$PhaseId-findings.json", ".ai-loop/runs/$PhaseId/$DecisionFileName", ".ai-loop/events/state-transitions.ndjson")

Write-Output "Recorded $Decision for phase $PhaseId"

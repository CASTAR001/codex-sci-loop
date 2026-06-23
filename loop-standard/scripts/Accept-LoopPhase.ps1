[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PhaseId,
    [Parameter(Mandatory = $true)][ValidateSet("ACCEPTED", "REWORK", "BLOCKED")][string]$Decision,
    [string]$TargetRoot = (Get-Location).Path,
    [string]$AuditPath = ""
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

$TargetRoot = (Resolve-Path -LiteralPath $TargetRoot).Path
$LoopDir = Join-Path $TargetRoot ".ai-loop"
$StatusPath = Join-Path $LoopDir "status.json"
$PhaseDir = Join-Path $LoopDir (Join-Path "evidence" $PhaseId)
$AuditDir = Join-Path $LoopDir (Join-Path "audits" $PhaseId)
$FinalAuditPath = Join-Path $AuditDir "audit.md"

if (-not (Test-Path -LiteralPath $StatusPath)) {
    throw "Missing .ai-loop/status.json. Run Initialize-AiLoop.ps1 first."
}
New-Item -ItemType Directory -Force -Path $AuditDir | Out-Null

if (-not [string]::IsNullOrWhiteSpace($AuditPath)) {
    $ResolvedAudit = (Resolve-Path -LiteralPath $AuditPath).Path
    Copy-Item -LiteralPath $ResolvedAudit -Destination $FinalAuditPath -Force
}

if (-not (Test-Path -LiteralPath $FinalAuditPath)) {
    throw "Missing audit file: $FinalAuditPath"
}

$AuditText = Get-Content -LiteralPath $FinalAuditPath -Raw
if ($AuditText -notmatch "Decision:\s*$Decision\b") {
    throw "Audit file does not contain matching line 'Decision: $Decision'."
}

$Required = @("prompt.md", "report.md", "diff.patch", "verify.log", "status.txt")
$EvidenceProblems = New-Object System.Collections.Generic.List[string]
foreach ($Name in $Required) {
    $Path = Join-Path $PhaseDir $Name
    if (-not (Test-Path -LiteralPath $Path)) {
        $EvidenceProblems.Add($Name)
        continue
    }
    $Text = Get-Content -LiteralPath $Path -Raw
    if ($Text -match "(?m)^\s*MISSING:") {
        $EvidenceProblems.Add("$Name contains MISSING placeholder")
    }
}

if ($Decision -eq "ACCEPTED" -and $EvidenceProblems.Count -gt 0) {
    $Joined = ($EvidenceProblems -join "; ")
    throw "Cannot ACCEPT with missing evidence: $Joined"
}

$Status = Get-Content -LiteralPath $StatusPath -Raw | ConvertFrom-Json
$DecisionRecord = [ordered]@{
    phase_id = $PhaseId
    decision = $Decision
    audit = ".ai-loop/audits/$PhaseId/audit.md"
    decided_at = (Get-Date).ToUniversalTime().ToString("o")
}

$Status.last_decision = $DecisionRecord
if ($null -ne $Status.current_phase -and $Status.current_phase.phase_id -eq $PhaseId) {
    $Status.current_phase.phase_status = $Decision.ToLowerInvariant()
    $Status.current_phase.audit = ".ai-loop/audits/$PhaseId/audit.md"
    $Status.current_phase.decided_at = $DecisionRecord.decided_at
}
Write-JsonFile -Value $Status -Path $StatusPath

Write-Output "Recorded phase decision: $Decision for $PhaseId"

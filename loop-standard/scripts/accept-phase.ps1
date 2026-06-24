[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][string]$PhaseId,
    [string]$AuditPath = "",
    [switch]$Commit,
    [string]$CommitMessage = "",
    [switch]$Force,
    [string]$OverrideReason = ""
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
$ProjectGitArgs = @("-c", "safe.directory=$($ProjectRoot.Replace('\', '/'))", "-c", "core.excludesFile=", "-c", "core.autocrlf=false", "-C", $ProjectRoot)
$LoopDir = Join-Path $ProjectRoot ".ai-loop"
$RunDir = Join-Path $LoopDir (Join-Path "runs" $PhaseId)
$AuditDir = Join-Path $LoopDir "audits"
$AuditResultPath = Join-Path $AuditDir "$PhaseId-audit.md"
$MetaPath = Join-Path $RunDir "phase_meta.json"
$StatusPath = Join-Path $LoopDir "status.json"

if (-not (Test-Path -LiteralPath $MetaPath)) {
    throw "Missing phase metadata: $MetaPath"
}
New-Item -ItemType Directory -Force -Path $AuditDir | Out-Null

if (-not [string]::IsNullOrWhiteSpace($AuditPath)) {
    Copy-Item -LiteralPath (Resolve-Path -LiteralPath $AuditPath).Path -Destination $AuditResultPath -Force
}
if (-not (Test-Path -LiteralPath $AuditResultPath)) {
    throw "Missing audit result: $AuditResultPath"
}

$AuditText = Get-Content -LiteralPath $AuditResultPath -Raw
if ($AuditText -notmatch "(?m)^\s*Decision:\s*ACCEPTED\s*$") {
    throw "Cannot accept phase because audit result does not contain 'Decision: ACCEPTED'."
}

$GateScript = Join-Path $PSScriptRoot "validate-phase-gates.ps1"
$GateOutput = @()
$GateExitCode = 0
if (Test-Path -LiteralPath $GateScript) {
    $GateOutput = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $GateScript -ProjectRoot $ProjectRoot -PhaseId $PhaseId -TargetStatus accepted 2>&1)
    $GateExitCode = $LASTEXITCODE
} else {
    $GateOutput = @("Phase gate validation: FAILED", "- missing validate-phase-gates.ps1")
    $GateExitCode = 2
}
if ($GateExitCode -ne 0 -and -not $Force) {
    throw "Cannot accept phase because phase gate validation failed.`n$($GateOutput | Out-String)"
}
if ($Force -and [string]::IsNullOrWhiteSpace($OverrideReason)) {
    throw "Cannot use -Force without -OverrideReason."
}
if ($Force) {
    Add-EventLogEntry -LoopDir $LoopDir -Event ([ordered]@{
        ts = (Get-Date).ToUniversalTime().ToString("o")
        type = "override"
        actor = "Codex Supervisor"
        summary = "Force accepted phase gate result for $PhaseId"
        phase = $PhaseId
        result = if ($GateExitCode -eq 0) { "gate_ok_force_recorded" } else { "gate_failed_force_override" }
        override_reason = $OverrideReason
        evidence = @(".ai-loop/audits/$PhaseId-audit.md", ".ai-loop/runs/$PhaseId/phase_meta.json")
        paths = @(".ai-loop/events/event-log.ndjson")
        gate_output = @($GateOutput)
    })
}

$Meta = Get-Content -LiteralPath $MetaPath -Raw | ConvertFrom-Json
if ($Meta.status -notin @("audit_ready", "accepted") -and -not $Force) {
    throw "Cannot accept phase from status '$($Meta.status)'. Expected audit_ready."
}

$Required = @("prompt.md", "report.md", "status_after.txt", "diff.patch", "verify.log", "changed_files.txt", "changed_business_files.txt", "changed_evidence_files.txt")
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
if ($Problems.Count -gt 0 -and -not $Force) {
    throw "Cannot accept with missing evidence: $($Problems -join '; ')"
}

if ($Commit) {
    $Git = Get-Command git -ErrorAction SilentlyContinue
    if ($null -eq $Git) {
        throw "Cannot commit because git executable was not found."
    }
    $Message = if ([string]::IsNullOrWhiteSpace($CommitMessage)) { "Accept $PhaseId" } else { $CommitMessage }
    & git @ProjectGitArgs add -- . | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "git add failed." }
    & git @ProjectGitArgs commit -m $Message | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "git commit failed." }
}

$AcceptedAt = (Get-Date).ToUniversalTime().ToString("o")
"accepted_at: $AcceptedAt`naudit: .ai-loop/audits/$PhaseId-audit.md" |
    Set-Content -LiteralPath (Join-Path $RunDir "accepted.txt") -Encoding utf8

Set-JsonProperty -Object $Meta -Name "status" -Value "accepted"
Set-JsonProperty -Object $Meta -Name "accepted_at" -Value $AcceptedAt
Set-JsonProperty -Object $Meta -Name "audit_result" -Value ".ai-loop/audits/$PhaseId-audit.md"
Write-JsonFile -Value $Meta -Path $MetaPath

if (Test-Path -LiteralPath $StatusPath) {
    $Status = Get-Content -LiteralPath $StatusPath -Raw | ConvertFrom-Json
    $Status.last_decision = [ordered]@{
        phase_id = $PhaseId
        decision = "ACCEPTED"
        audit = ".ai-loop/audits/$PhaseId-audit.md"
        decided_at = $AcceptedAt
    }
    if ($null -ne $Status.current_phase -and $Status.current_phase.phase_id -eq $PhaseId) {
        Set-JsonProperty -Object $Status.current_phase -Name "status" -Value "accepted"
        Set-JsonProperty -Object $Status.current_phase -Name "accepted_at" -Value $AcceptedAt
    }
    for ($Index = 0; $Index -lt @($Status.phases).Count; $Index++) {
        if ($Status.phases[$Index].phase_id -eq $PhaseId) {
            Set-JsonProperty -Object $Status.phases[$Index] -Name "status" -Value "accepted"
            Set-JsonProperty -Object $Status.phases[$Index] -Name "accepted_at" -Value $AcceptedAt
            Set-JsonProperty -Object $Status.phases[$Index] -Name "audit_result" -Value ".ai-loop/audits/$PhaseId-audit.md"
        }
    }
    Write-JsonFile -Value $Status -Path $StatusPath
}

Write-Output "Accepted phase $PhaseId"

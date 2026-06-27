[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
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
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return "missing" }
    if ((Get-Item -LiteralPath $Path).Length -eq 0) { return "empty" }
    return "ok"
}

function Read-JsonOrProblem {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Add-Problem "missing JSON file: $Path"
        return $null
    }
    try {
        return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    } catch {
        Add-Problem "invalid JSON file: $Path - $($_.Exception.Message)"
        return $null
    }
}

function Test-RequiredFile {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$RelativePath
    )
    $Path = Join-Path $Root ($RelativePath -replace "/", "\")
    $Result = Test-NonEmptyFile -Path $Path
    if ($Result -ne "ok") {
        Add-Problem "$RelativePath $Result"
    }
}

$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$Problems = New-Object System.Collections.Generic.List[string]
$LoopDir = Join-Path $ProjectRoot ".ai-loop"
$StatusPath = Join-Path $LoopDir "status.json"
$ConfigPath = Join-Path $LoopDir "loop.config.json"
$ValidStatuses = @("started", "evidence_collected", "audit_ready", "accepted", "rework", "blocked", "blocked_missing_evidence")
$TerminalStatuses = @("accepted", "rework", "blocked")

if (-not (Test-Path -LiteralPath $LoopDir -PathType Container)) {
    Add-Problem "missing .ai-loop directory"
}

foreach ($Directory in @("runs", "audits", "evidence", "memory", "gates", "roles", "skills", "events", "prompts", "templates", "workers")) {
    $DirectoryPath = Join-Path $LoopDir $Directory
    if (-not (Test-Path -LiteralPath $DirectoryPath -PathType Container)) {
        Add-Problem "missing .ai-loop/$Directory directory"
    }
}

foreach ($RelativePath in @(
    ".ai-loop/README.md",
    ".ai-loop/memory/activeContext.md",
    ".ai-loop/memory/constraint-ledger.md",
    ".ai-loop/memory/progress.md",
    ".ai-loop/memory/handoff-summary.md",
    ".ai-loop/gates/pre-action-check.md",
    ".ai-loop/gates/phase-gates.md",
    ".ai-loop/gates/stop-rules.md",
    ".ai-loop/evidence/artifact-manifest.json",
    ".ai-loop/evidence/evidence-ledger.md",
    ".ai-loop/skills/skill-trigger-matrix.md",
    ".ai-loop/skills/skill-source-map.md",
    ".ai-loop/events/event-log.ndjson"
)) {
    Test-RequiredFile -Root $ProjectRoot -RelativePath $RelativePath
}

$Status = Read-JsonOrProblem -Path $StatusPath
$Config = Read-JsonOrProblem -Path $ConfigPath
$Manifest = Read-JsonOrProblem -Path (Join-Path $LoopDir "evidence\artifact-manifest.json")

if ($null -ne $Config) {
    foreach ($Decision in @("ACCEPTED", "REWORK", "BLOCKED")) {
        if ($Config.decisions -notcontains $Decision) {
            Add-Problem "loop.config.json missing decision: $Decision"
        }
    }
    foreach ($Ledger in @(".ai-loop/evidence/artifact-manifest.json", ".ai-loop/evidence/evidence-ledger.md", ".ai-loop/skills/skill-usage-ledger.md")) {
        if (($Config.evidence_ledgers -notcontains $Ledger) -and ($Config.skill_ledgers -notcontains $Ledger)) {
            Add-Problem "loop.config.json missing ledger reference: $Ledger"
        }
    }
}

if ($null -ne $Manifest -and $null -eq $Manifest.PSObject.Properties["artifacts"]) {
    Add-Problem "artifact-manifest.json missing artifacts array"
}

if ($null -ne $Status) {
    if ([string]::IsNullOrWhiteSpace([string]$Status.project_name)) {
        Add-Problem "status.json missing project_name"
    }
    if ($null -eq $Status.PSObject.Properties["phases"]) {
        Add-Problem "status.json missing phases array"
    }
    $Phases = @($Status.phases)
    $PhaseGroups = $Phases | Group-Object -Property phase_id
    foreach ($Group in $PhaseGroups) {
        if ([string]::IsNullOrWhiteSpace([string]$Group.Name)) {
            Add-Problem "status.json contains phase with blank phase_id"
        } elseif ($Group.Count -gt 1) {
            Add-Problem "status.json contains duplicate phase_id: $($Group.Name)"
        }
    }

    if ($null -ne $Status.current_phase) {
        $CurrentPhaseId = [string]$Status.current_phase.phase_id
        $CurrentStatus = [string]$Status.current_phase.status
        if ([string]::IsNullOrWhiteSpace($CurrentPhaseId)) {
            Add-Problem "current_phase missing phase_id"
        }
        if ($ValidStatuses -notcontains $CurrentStatus) {
            Add-Problem "current_phase has illegal status: $CurrentStatus"
        }
        $CurrentMatches = @($Phases | Where-Object { $_.phase_id -eq $CurrentPhaseId })
        if ($CurrentMatches.Count -ne 1) {
            Add-Problem "current_phase does not match exactly one status.json phases entry: $CurrentPhaseId"
        } elseif ([string]$CurrentMatches[0].status -ne $CurrentStatus) {
            Add-Problem "current_phase status differs from phases entry for $CurrentPhaseId"
        }
    }

    foreach ($Phase in $Phases) {
        $PhaseId = [string]$Phase.phase_id
        $PhaseStatus = [string]$Phase.status
        if ([string]::IsNullOrWhiteSpace($PhaseId)) { continue }
        if ($ValidStatuses -notcontains $PhaseStatus) {
            Add-Problem "phase $PhaseId has illegal status: $PhaseStatus"
            continue
        }
        $RunDir = Join-Path $LoopDir "runs\$PhaseId"
        $MetaPath = Join-Path $RunDir "phase_meta.json"
        if (-not (Test-Path -LiteralPath $RunDir -PathType Container)) {
            Add-Problem "phase $PhaseId missing run directory"
            continue
        }
        $Meta = Read-JsonOrProblem -Path $MetaPath
        if ($null -ne $Meta) {
            if ([string]$Meta.phase_id -ne $PhaseId) {
                Add-Problem "phase $PhaseId metadata phase_id mismatch"
            }
            if ([string]$Meta.status -ne $PhaseStatus) {
                Add-Problem "phase $PhaseId metadata status differs from status.json"
            }
        }
        foreach ($RequiredRunFile in @("base_commit.txt", "status_before.txt", "phase_meta.json", "phase_requirements.json", "prompt.md")) {
            $Result = Test-NonEmptyFile -Path (Join-Path $RunDir $RequiredRunFile)
            if ($Result -ne "ok") {
                Add-Problem "phase $PhaseId missing start evidence: $RequiredRunFile $Result"
            }
        }
        if ($PhaseStatus -in @("evidence_collected", "audit_ready", "accepted")) {
            foreach ($EvidenceFile in @("report.md", "status_after.txt", "diff.patch", "verify.log", "changed_files.txt", "changed_business_files.txt", "changed_evidence_files.txt")) {
                $Result = Test-NonEmptyFile -Path (Join-Path $RunDir $EvidenceFile)
                if ($Result -ne "ok") {
                    Add-Problem "phase $PhaseId missing collected evidence: $EvidenceFile $Result"
                }
            }
        }
        if ($PhaseStatus -eq "audit_ready" -or $PhaseStatus -eq "accepted") {
            $AuditInput = Join-Path $LoopDir "audits\$PhaseId-audit-input.md"
            $Result = Test-NonEmptyFile -Path $AuditInput
            if ($Result -ne "ok") {
                Add-Problem "phase $PhaseId missing audit input: $Result"
            }
        }
        if ($PhaseStatus -eq "accepted") {
            $AuditResult = Join-Path $LoopDir "audits\$PhaseId-audit.md"
            $AcceptedFile = Join-Path $RunDir "accepted.txt"
            $AuditResultCheck = Test-NonEmptyFile -Path $AuditResult
            if ($AuditResultCheck -ne "ok") {
                Add-Problem "phase $PhaseId missing audit result: $AuditResultCheck"
            } else {
                $AuditText = Get-Content -LiteralPath $AuditResult -Raw
                if ($AuditText -notmatch "(?m)^\s*Decision:\s*ACCEPTED\s*$") {
                    Add-Problem "phase $PhaseId accepted without ACCEPTED audit decision"
                }
            }
            $AcceptedCheck = Test-NonEmptyFile -Path $AcceptedFile
            if ($AcceptedCheck -ne "ok") {
                Add-Problem "phase $PhaseId missing accepted.txt: $AcceptedCheck"
            }
            $GateScript = Join-Path $PSScriptRoot "validate-phase-gates.ps1"
            if (Test-Path -LiteralPath $GateScript -PathType Leaf) {
                $GateOutput = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $GateScript -ProjectRoot $ProjectRoot -PhaseId $PhaseId -TargetStatus accepted -Quiet 2>&1)
                if ($LASTEXITCODE -ne 0) {
                    Add-Problem "phase $PhaseId accepted gate failed: $($GateOutput | Out-String)"
                }
            } else {
                Add-Problem "missing validate-phase-gates.ps1"
            }
        }
        if (($TerminalStatuses -notcontains $PhaseStatus) -and ($null -ne $Status.current_phase) -and ([string]$Status.current_phase.phase_id -ne $PhaseId)) {
            Add-Problem "non-terminal phase is not current_phase: $PhaseId status=$PhaseStatus"
        }
    }
}

if (-not $Quiet) {
    if ($Problems.Count -eq 0) {
        Write-Output "Loop validation: OK"
        Write-Output "Project root: $ProjectRoot"
    } else {
        Write-Output "Loop validation: FAILED"
        Write-Output "Project root: $ProjectRoot"
        foreach ($Problem in $Problems) {
            Write-Output "- $Problem"
        }
    }
}

if ($Problems.Count -gt 0) {
    exit 2
}

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

function Get-ObjectStringProperty {
    param(
        [AllowNull()]$Object,
        [Parameter(Mandatory = $true)][string]$Name
    )
    if ($null -eq $Object -or $null -eq $Object.PSObject.Properties[$Name]) {
        return ""
    }
    return [string]$Object.$Name
}

function Compare-SchemaVersion {
    param(
        [Parameter(Mandatory = $true)][string]$Left,
        [Parameter(Mandatory = $true)][string]$Right
    )
    try {
        $LeftVersion = [version]$Left
        $RightVersion = [version]$Right
    } catch {
        Add-Problem "invalid schema version string: '$Left' or '$Right'"
        return 0
    }
    return $LeftVersion.CompareTo($RightVersion)
}

$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$Problems = New-Object System.Collections.Generic.List[string]
$LoopDir = Join-Path $ProjectRoot ".ai-loop"
$StatusPath = Join-Path $LoopDir "status.json"
$ConfigPath = Join-Path $LoopDir "loop.config.json"
$SchemaPath = Join-Path $LoopDir "schema\schema-version.json"
$TransitionLogPath = Join-Path $LoopDir "events\state-transitions.ndjson"
$ValidStatuses = @("started", "evidence_collected", "audit_ready", "accepted", "rework", "blocked", "blocked_missing_evidence")
$TerminalStatuses = @("accepted", "rework", "blocked")

if (-not (Test-Path -LiteralPath $LoopDir -PathType Container)) {
    Add-Problem "missing .ai-loop directory"
}

foreach ($Directory in @("runs", "audits", "evidence", "memory", "gates", "roles", "skills", "events", "prompts", "templates", "workers", "schema")) {
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
    ".ai-loop/events/event-log.ndjson",
    ".ai-loop/schema/schema-version.json",
    ".ai-loop/schema/migration-log.md"
)) {
    Test-RequiredFile -Root $ProjectRoot -RelativePath $RelativePath
}

$Status = Read-JsonOrProblem -Path $StatusPath
$Config = Read-JsonOrProblem -Path $ConfigPath
$Manifest = Read-JsonOrProblem -Path (Join-Path $LoopDir "evidence\artifact-manifest.json")
$Schema = Read-JsonOrProblem -Path $SchemaPath
$TransitionRows = @()

if (Test-Path -LiteralPath $TransitionLogPath -PathType Leaf) {
    $LineNumber = 0
    foreach ($Line in @(Get-Content -LiteralPath $TransitionLogPath)) {
        $LineNumber++
        if ([string]::IsNullOrWhiteSpace($Line)) { continue }
        try {
            $Entry = $Line | ConvertFrom-Json
            foreach ($PropertyName in @("ts", "phase_id", "from_status", "to_status", "actor", "action", "paths")) {
                if ($null -eq $Entry.PSObject.Properties[$PropertyName]) {
                    Add-Problem "state-transitions.ndjson line $LineNumber missing required property: $PropertyName"
                }
            }
            $TransitionRows += [pscustomobject]@{
                line_number = $LineNumber
                entry = $Entry
            }
        } catch {
            Add-Problem "invalid state-transitions.ndjson line $LineNumber - $($_.Exception.Message)"
        }
    }
}

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

if ($null -ne $Schema) {
    foreach ($PropertyName in @("schema_name", "schema_version", "latest_schema_version", "min_supported_schema_version", "status_schema_version", "migration_log")) {
        if ([string]::IsNullOrWhiteSpace((Get-ObjectStringProperty -Object $Schema -Name $PropertyName))) {
            Add-Problem "schema-version.json missing required property: $PropertyName"
        }
    }
    if ($null -ne $Schema.PSObject.Properties["required_directories"]) {
        foreach ($RequiredDirectory in @($Schema.required_directories)) {
            $DirectoryPath = Join-Path $ProjectRoot ([string]$RequiredDirectory -replace "/", "\")
            if (-not (Test-Path -LiteralPath $DirectoryPath -PathType Container)) {
                Add-Problem "schema required directory missing: $RequiredDirectory"
            }
        }
    }
    if ($null -ne $Schema.PSObject.Properties["required_files"]) {
        foreach ($RequiredFile in @($Schema.required_files)) {
            Test-RequiredFile -Root $ProjectRoot -RelativePath ([string]$RequiredFile)
        }
    }
    $SchemaVersion = Get-ObjectStringProperty -Object $Schema -Name "schema_version"
    $LatestSchemaVersion = Get-ObjectStringProperty -Object $Schema -Name "latest_schema_version"
    $MinSupportedSchemaVersion = Get-ObjectStringProperty -Object $Schema -Name "min_supported_schema_version"
    $StatusSchemaVersion = Get-ObjectStringProperty -Object $Schema -Name "status_schema_version"
    $ConfigSchemaVersion = Get-ObjectStringProperty -Object $Config -Name "schema_version"
    if ($null -ne $Config -and -not [string]::IsNullOrWhiteSpace($ConfigSchemaVersion)) {
        if (-not [string]::IsNullOrWhiteSpace($SchemaVersion) -and $ConfigSchemaVersion -ne $SchemaVersion) {
            Add-Problem "loop.config.json schema_version differs from schema manifest: config=$ConfigSchemaVersion manifest=$SchemaVersion"
        }
        if (-not [string]::IsNullOrWhiteSpace($MinSupportedSchemaVersion) -and (Compare-SchemaVersion -Left $ConfigSchemaVersion -Right $MinSupportedSchemaVersion) -lt 0) {
            Add-Problem "loop.config.json schema_version is older than min supported: $ConfigSchemaVersion < $MinSupportedSchemaVersion"
        }
        if (-not [string]::IsNullOrWhiteSpace($LatestSchemaVersion) -and (Compare-SchemaVersion -Left $ConfigSchemaVersion -Right $LatestSchemaVersion) -gt 0) {
            Add-Problem "loop.config.json schema_version is newer than latest supported: $ConfigSchemaVersion > $LatestSchemaVersion"
        }
    } elseif ($null -ne $Config) {
        Add-Problem "loop.config.json missing schema_version"
    }
    if ($null -ne $Status -and -not [string]::IsNullOrWhiteSpace($StatusSchemaVersion)) {
        $StatusVersion = Get-ObjectStringProperty -Object $Status -Name "schema_version"
        if ($StatusVersion -ne $StatusSchemaVersion) {
            Add-Problem "status.json schema_version differs from schema manifest: status=$StatusVersion manifest=$StatusSchemaVersion"
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
            if ($null -ne $Meta.PSObject.Properties["transition_log"]) {
                if ([string]$Meta.transition_log -ne ".ai-loop/events/state-transitions.ndjson") {
                    Add-Problem "phase $PhaseId transition_log has unexpected path: $($Meta.transition_log)"
                }
                $PhaseTransitions = @($TransitionRows | Where-Object { [string]$_.entry.phase_id -eq $PhaseId })
                if ($PhaseTransitions.Count -eq 0) {
                    Add-Problem "phase $PhaseId has transition_log but no state transition entries"
                } else {
                    $LatestTransition = $PhaseTransitions | Sort-Object line_number | Select-Object -Last 1
                    if ([string]$LatestTransition.entry.to_status -ne $PhaseStatus) {
                        Add-Problem "phase $PhaseId transition log latest status differs from status.json: transition=$($LatestTransition.entry.to_status) status=$PhaseStatus"
                    }
                }
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
        if ($PhaseStatus -eq "rework" -or $PhaseStatus -eq "blocked") {
            $ExpectedDecision = if ($PhaseStatus -eq "rework") { "REWORK" } else { "BLOCKED" }
            $DecisionFileName = if ($PhaseStatus -eq "rework") { "rework.txt" } else { "blocked.txt" }
            $AuditResult = Join-Path $LoopDir "audits\$PhaseId-audit.md"
            $AuditFindings = Join-Path $LoopDir "audits\$PhaseId-findings.json"
            $DecisionFile = Join-Path $RunDir $DecisionFileName
            $AuditResultCheck = Test-NonEmptyFile -Path $AuditResult
            if ($AuditResultCheck -ne "ok") {
                Add-Problem "phase $PhaseId missing $ExpectedDecision audit result: $AuditResultCheck"
            } else {
                $AuditText = Get-Content -LiteralPath $AuditResult -Raw
                if ($AuditText -notmatch "(?m)^\s*Decision:\s*$ExpectedDecision\s*$") {
                    Add-Problem "phase $PhaseId $PhaseStatus without $ExpectedDecision audit decision"
                }
            }
            $DecisionCheck = Test-NonEmptyFile -Path $DecisionFile
            if ($DecisionCheck -ne "ok") {
                Add-Problem "phase $PhaseId missing $DecisionFileName`: $DecisionCheck"
            }
            $FindingsCheck = Test-NonEmptyFile -Path $AuditFindings
            if ($FindingsCheck -ne "ok") {
                Add-Problem "phase $PhaseId missing audit findings JSON: $FindingsCheck"
            } else {
                $Findings = Read-JsonOrProblem -Path $AuditFindings
                if ($null -ne $Findings) {
                    if ([string]$Findings.phase_id -ne $PhaseId) {
                        Add-Problem "phase $PhaseId audit findings have wrong phase_id: $($Findings.phase_id)"
                    }
                    if ([string]$Findings.decision -ne $ExpectedDecision) {
                        Add-Problem "phase $PhaseId audit findings have wrong decision: $($Findings.decision)"
                    }
                    if ($null -eq $Findings.PSObject.Properties["findings"]) {
                        Add-Problem "phase $PhaseId audit findings JSON missing findings array"
                    }
                }
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

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Add-Check {
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$Area,
        [Parameter(Mandatory = $true)][string]$Requirement,
        [Parameter(Mandatory = $true)][ValidateSet("pass", "warn", "fail")][string]$Status,
        [string]$Evidence = "",
        [string]$Notes = ""
    )
    $script:Checks.Add([pscustomobject][ordered]@{
        id = $Id
        area = $Area
        requirement = $Requirement
        status = $Status
        evidence = $Evidence
        notes = $Notes
    })
}

function Test-NonEmptyPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return "missing" }
    $Item = Get-Item -LiteralPath $Path -Force
    if (-not $Item.PSIsContainer -and $Item.Length -eq 0) { return "empty" }
    return "ok"
}

function Add-PathCheck {
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$Area,
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [string]$Requirement = ""
    )
    $Path = Join-Path $Root ($RelativePath -replace "/", "\")
    $Result = Test-NonEmptyPath -Path $Path
    if ([string]::IsNullOrWhiteSpace($Requirement)) {
        $Requirement = "$RelativePath exists and is non-empty when it is a file."
    }
    if ($Result -eq "ok") {
        Add-Check -Id $Id -Area $Area -Requirement $Requirement -Status "pass" -Evidence $RelativePath
    } else {
        Add-Check -Id $Id -Area $Area -Requirement $Requirement -Status "fail" -Evidence $RelativePath -Notes $Result
    }
}

function Read-JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    try {
        return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    } catch {
        return $null
    }
}

function Invoke-ScriptCheck {
    param(
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )
    $PreviousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $Output = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @Arguments 2>&1)
    $ExitCode = $LASTEXITCODE
    $ErrorActionPreference = $PreviousErrorActionPreference
    return [pscustomobject]@{
        exit_code = $ExitCode
        output = ($Output | Out-String).Trim()
    }
}

$KitRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = Split-Path -Parent $KitRoot
$ProjectRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ProjectRoot)
$Checks = New-Object System.Collections.Generic.List[object]

foreach ($Entry in @(
    @{ Id = "KIT-INIT"; Area = "kit"; Path = "scripts/init-loop.ps1"; Requirement = "Can initialize .ai-loop in an arbitrary project." },
    @{ Id = "KIT-MIGRATE"; Area = "kit"; Path = "scripts/migrate-loop.ps1"; Requirement = "Can migrate existing .ai-loop projects non-destructively." },
    @{ Id = "KIT-START"; Area = "kit"; Path = "scripts/start-phase.ps1"; Requirement = "Can start phases and produce phase requirements." },
    @{ Id = "KIT-COLLECT"; Area = "kit"; Path = "scripts/collect-evidence.ps1"; Requirement = "Can collect hash-backed evidence." },
    @{ Id = "KIT-AUDIT"; Area = "kit"; Path = "scripts/prepare-audit-pack.ps1"; Requirement = "Can prepare Codex audit packages." },
    @{ Id = "KIT-VALIDATE"; Area = "kit"; Path = "scripts/validate-phase-gates.ps1"; Requirement = "Can enforce phase gates." },
    @{ Id = "KIT-ACCEPT"; Area = "kit"; Path = "scripts/accept-phase.ps1"; Requirement = "Can accept only audited phases." },
    @{ Id = "KIT-DECIDE"; Area = "kit"; Path = "scripts/decide-phase.ps1"; Requirement = "Can record REWORK/BLOCKED decisions." },
    @{ Id = "KIT-REWORK"; Area = "kit"; Path = "scripts/scaffold-rework-phase.ps1"; Requirement = "Can scaffold bounded rework phases." },
    @{ Id = "KIT-RECOVERY"; Area = "kit"; Path = "scripts/validate-loop.ps1"; Requirement = "Can validate loop-wide recovery state." },
    @{ Id = "KIT-WORKER"; Area = "kit"; Path = "scripts/preflight-worker.ps1"; Requirement = "Can preflight external Worker invocation." },
    @{ Id = "KIT-INVOKE"; Area = "kit"; Path = "scripts/invoke-worker.ps1"; Requirement = "Can invoke Worker only after preflight." },
    @{ Id = "KIT-SKILLS"; Area = "kit"; Path = "scripts/link-skills.ps1"; Requirement = "Can link project-local skills." },
    @{ Id = "KIT-ENTRY"; Area = "kit"; Path = "scripts/ai-loop.ps1"; Requirement = "Provides a unified command entrypoint." }
)) {
    Add-PathCheck -Id $Entry.Id -Area $Entry.Area -Root $KitRoot -RelativePath $Entry.Path -Requirement $Entry.Requirement
}

foreach ($Entry in @(
    @{ Id = "TPL-README"; Path = "templates/.ai-loop/README.md" },
    @{ Id = "TPL-CONFIG"; Path = "templates/.ai-loop/loop.config.json" },
    @{ Id = "TPL-STATUS"; Path = "templates/.ai-loop/status.json" },
    @{ Id = "TPL-SCHEMA"; Path = "templates/.ai-loop/schema/schema-version.json" },
    @{ Id = "TPL-MEMORY"; Path = "templates/.ai-loop/memory/activeContext.md" },
    @{ Id = "TPL-CONSTRAINTS"; Path = "templates/.ai-loop/memory/constraint-ledger.md" },
    @{ Id = "TPL-GATES"; Path = "templates/.ai-loop/gates/pre-action-check.md" },
    @{ Id = "TPL-EVIDENCE"; Path = "templates/.ai-loop/evidence/artifact-manifest.json" },
    @{ Id = "TPL-SKILLS"; Path = "templates/.ai-loop/skills/skill-trigger-matrix.md" },
    @{ Id = "TPL-EVOLUTION"; Path = "templates/.ai-loop/evolution/project-loop-evolution.md" }
)) {
    Add-PathCheck -Id $Entry.Id -Area "templates" -Root $KitRoot -RelativePath $Entry.Path -Requirement "Reusable .ai-loop template includes $($Entry.Path)."
}

foreach ($Entry in @(
    @{ Id = "DOC-CN"; Root = $RepoRoot; Path = "README.md"; Requirement = "Chinese operator README exists." },
    @{ Id = "DOC-EN"; Root = $RepoRoot; Path = "README_EN.md"; Requirement = "English README exists." },
    @{ Id = "DOC-RUNBOOK"; Root = $KitRoot; Path = "docs/OPERATOR_RUNBOOK.md"; Requirement = "Operator runbook exists." },
    @{ Id = "DOC-BOUNDARY"; Root = $KitRoot; Path = "docs/AGENTS_VS_AI_LOOP_BOUNDARY.md"; Requirement = ".agents versus .ai-loop boundary is documented." },
    @{ Id = "DOC-WORKER"; Root = $KitRoot; Path = "docs/EXTERNAL_WORKER_PROTOCOL.md"; Requirement = "External Worker protocol is documented." }
)) {
    Add-PathCheck -Id $Entry.Id -Area "docs" -Root $Entry.Root -RelativePath $Entry.Path -Requirement $Entry.Requirement
}

$PluginRoot = Join-Path $RepoRoot "plugins\codex-loop-harness"
foreach ($Entry in @(
    @{ Id = "PLUGIN-MANIFEST"; Path = ".codex-plugin/plugin.json" },
    @{ Id = "PLUGIN-SUPERVISOR"; Path = "skills/loop-supervisor/SKILL.md" },
    @{ Id = "PLUGIN-AUDITOR"; Path = "skills/loop-auditor/SKILL.md" },
    @{ Id = "PLUGIN-RECOVERY"; Path = "skills/loop-recovery/SKILL.md" },
    @{ Id = "PLUGIN-RESEARCH"; Path = "skills/research-loop-orchestrator/SKILL.md" },
    @{ Id = "PLUGIN-WRAPPER"; Path = "scripts/ai-loop.ps1" }
)) {
    Add-PathCheck -Id $Entry.Id -Area "plugin" -Root $PluginRoot -RelativePath $Entry.Path -Requirement "Codex plugin scaffold includes $($Entry.Path)."
}
Add-Check -Id "PLUGIN-GLOBAL" -Area "plugin" -Requirement "Real global Codex plugin discovery is live-validated." -Status "warn" -Evidence "repo-local plugin smoke tests" -Notes "Skipped by policy until the user explicitly approves modifying real global Codex configuration."

foreach ($Entry in @(
    @{ Id = "PROJECT-LOOP"; Path = ".ai-loop/README.md"; Requirement = "Project has a local .ai-loop control plane." },
    @{ Id = "PROJECT-AGENTS"; Path = "AGENTS.md"; Requirement = "Project has a short AGENTS.md bootstrap." },
    @{ Id = "PROJECT-MEMORY"; Path = ".ai-loop/memory/activeContext.md"; Requirement = "Project has resumable active context." },
    @{ Id = "PROJECT-CONSTRAINTS"; Path = ".ai-loop/memory/constraint-ledger.md"; Requirement = "Project has local constraint ledger." },
    @{ Id = "PROJECT-EVIDENCE"; Path = ".ai-loop/evidence/artifact-manifest.json"; Requirement = "Project has machine-readable artifact manifest." },
    @{ Id = "PROJECT-SKILLS"; Path = ".ai-loop/skills/skill-trigger-matrix.md"; Requirement = "Project has skill trigger matrix." },
    @{ Id = "PROJECT-EVOLUTION"; Path = ".ai-loop/evolution/project-loop-evolution.md"; Requirement = "Project has project-local evolution file." }
)) {
    Add-PathCheck -Id $Entry.Id -Area "project" -Root $ProjectRoot -RelativePath $Entry.Path -Requirement $Entry.Requirement
}

$StatusPath = Join-Path $ProjectRoot ".ai-loop\status.json"
$Status = Read-JsonFile -Path $StatusPath
if ($null -eq $Status) {
    Add-Check -Id "STATE-STATUS" -Area "state" -Requirement "status.json is parseable." -Status "fail" -Evidence ".ai-loop/status.json"
} else {
    Add-Check -Id "STATE-STATUS" -Area "state" -Requirement "status.json is parseable." -Status "pass" -Evidence ".ai-loop/status.json"
    $CurrentPhase = $Status.current_phase
    if ($null -ne $CurrentPhase -and -not [string]::IsNullOrWhiteSpace([string]$CurrentPhase.phase_id)) {
        $PhaseId = [string]$CurrentPhase.phase_id
        $PhaseStatus = [string]$CurrentPhase.status
        $Evidence = ".ai-loop/runs/$PhaseId"
        if ($PhaseStatus -eq "accepted") {
            Add-Check -Id "STATE-CURRENT-PHASE" -Area "state" -Requirement "Current phase is in a terminal accepted state." -Status "pass" -Evidence $Evidence
        } else {
            Add-Check -Id "STATE-CURRENT-PHASE" -Area "state" -Requirement "Current phase is in a terminal accepted state." -Status "warn" -Evidence $Evidence -Notes "Current status is $PhaseStatus."
        }
    } else {
        Add-Check -Id "STATE-CURRENT-PHASE" -Area "state" -Requirement "Project can be initialized with no active phase." -Status "pass" -Evidence ".ai-loop/status.json"
    }
}

$ValidateLoop = Invoke-ScriptCheck -ScriptPath (Join-Path $PSScriptRoot "validate-loop.ps1") -Arguments @("-ProjectRoot", $ProjectRoot, "-Quiet")
if ($ValidateLoop.exit_code -eq 0) {
    Add-Check -Id "STATE-VALIDATE-LOOP" -Area "state" -Requirement "Loop-wide validator passes." -Status "pass" -Evidence "validate-loop.ps1"
} else {
    Add-Check -Id "STATE-VALIDATE-LOOP" -Area "state" -Requirement "Loop-wide validator passes." -Status "fail" -Evidence "validate-loop.ps1" -Notes $ValidateLoop.output
}

foreach ($Entry in @(
    @{ Id = "TEST-STRUCTURE"; Path = "scripts/Test-LoopStandard.ps1"; Requirement = "Structure self-check exists." },
    @{ Id = "TEST-LATEST"; Path = "scripts/Test-Phase020.ps1"; Requirement = "Latest full non-global matrix exists." },
    @{ Id = "TEST-PLUGIN"; Path = "scripts/Test-PluginInstall.ps1"; Requirement = "Repo-local plugin install smoke test exists." },
    @{ Id = "TEST-VALIDATE"; Path = "scripts/Test-ValidateLoopFailures.ps1"; Requirement = "Negative loop validation fixtures exist." }
)) {
    Add-PathCheck -Id $Entry.Id -Area "tests" -Root $KitRoot -RelativePath $Entry.Path -Requirement $Entry.Requirement
}

$FailCount = @($Checks | Where-Object { $_.status -eq "fail" }).Count
$WarnCount = @($Checks | Where-Object { $_.status -eq "warn" }).Count
$PassCount = @($Checks | Where-Object { $_.status -eq "pass" }).Count
$OverallStatus = if ($FailCount -gt 0) { "blocked" } elseif ($WarnCount -gt 0) { "ready_with_warnings" } else { "ready" }
$NextActions = New-Object System.Collections.Generic.List[string]
if ($FailCount -gt 0) {
    $NextActions.Add("Fix failing readiness checks before claiming 1.0 delivery.")
}
if ($WarnCount -gt 0) {
    $NextActions.Add("Resolve warnings when policy allows; global plugin discovery requires explicit user approval.")
}
if ($FailCount -eq 0 -and $WarnCount -eq 0) {
    $NextActions.Add("Run the full verification matrix and prepare release notes.")
}

$Result = [pscustomobject][ordered]@{
    schema_version = "1.0"
    project_root = $ProjectRoot
    kit_root = $KitRoot
    status = $OverallStatus
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    summary = [ordered]@{
        pass = $PassCount
        warn = $WarnCount
        fail = $FailCount
        total = $Checks.Count
    }
    checks = @($Checks.ToArray())
    next_actions = @($NextActions.ToArray())
}

if ($Json) {
    $Result | ConvertTo-Json -Depth 30
} else {
    Write-Output "# Loop Harness 1.0 Readiness"
    Write-Output ""
    Write-Output "Project root: $ProjectRoot"
    Write-Output "Kit root: $KitRoot"
    Write-Output "Status: $OverallStatus"
    Write-Output "Summary: pass=$PassCount warn=$WarnCount fail=$FailCount total=$($Checks.Count)"
    Write-Output ""
    foreach ($Check in $Checks) {
        Write-Output "[$($Check.status.ToUpperInvariant())] $($Check.id) - $($Check.requirement)"
        if (-not [string]::IsNullOrWhiteSpace($Check.evidence)) {
            Write-Output "  evidence: $($Check.evidence)"
        }
        if (-not [string]::IsNullOrWhiteSpace($Check.notes)) {
            Write-Output "  notes: $($Check.notes)"
        }
    }
}

if ($FailCount -gt 0) {
    exit 2
}

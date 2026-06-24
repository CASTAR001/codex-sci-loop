[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][string]$PhaseId,
    [string]$Title = "",
    [string]$Objective = "",
    [string[]]$Scope = @(),
    [string]$VerifyCommand = "",
    [ValidateSet("generic", "fullstack", "physics-research", "research-writing", "data-analysis")]
    [string]$TaskKind = "generic",
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
    $Value | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $Path -Encoding utf8
}

function Get-SafeGitArgs {
    param([Parameter(Mandatory = $true)][string]$Root)
    $SafeRoot = $Root.Replace("\", "/")
    return @("-c", "safe.directory=$SafeRoot", "-c", "core.excludesFile=", "-c", "core.autocrlf=false", "-C", $Root)
}

function Invoke-GitText {
    param([Parameter(Mandatory = $true)][string[]]$GitArgs)
    $PreviousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $Output = & git @GitArgs 2>&1
        $ExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $PreviousErrorActionPreference
    }
    if ($ExitCode -eq 0) {
        return ($Output | Out-String).TrimEnd()
    }
    return "MISSING: git command failed: git $($GitArgs -join ' ')`n$($Output | Out-String)"
}

function Get-DefaultSkillsForTaskKind {
    param([Parameter(Mandatory = $true)][string]$Kind)
    switch ($Kind) {
        "physics-research" { return @("invariant-contract", "deterministic-verification") }
        "research-writing" { return @("manuscript-consistency-audit", "deterministic-verification") }
        "data-analysis" { return @("invariant-contract", "deterministic-verification", "result-provenance-audit") }
        default { return @() }
    }
}

function Get-SkillTrigger {
    param([Parameter(Mandatory = $true)][string]$Skill)
    $Triggers = @{
        "research-task-tree" = "multi-step research, paper reproduction, long scientific coding project"
        "invariant-contract" = "physics, math, data, invariant-sensitive implementation"
        "bounded-experiment-loop" = "repeated runs, simulation, benchmark, parameter scan, long command"
        "deterministic-verification" = "correctness, equivalence, convergence, exactness, scaling, conservation, numerical claim"
        "independent-crosscheck" = "key result before relying on it or publishing it"
        "result-provenance-audit" = "final figure, table, processed dataset, result artifact"
        "manuscript-consistency-audit" = "paper, report, LaTeX, research notes, result summary"
        "skill-compliance-audit" = "skill-pack update or task-completion compliance audit"
    }
    return $Triggers[$Skill]
}

function Get-SkillArtifacts {
    param([Parameter(Mandatory = $true)][string]$Skill)
    $Artifacts = @{
        "research-task-tree" = @("tasks/master-task-tree.md", "tasks/task-status.md", "tasks/task-summary.md")
        "invariant-contract" = @("checks/invariant-contract.md", "checks/invariant-test-plan.md")
        "bounded-experiment-loop" = @("runs/run-ledger.csv", "runs/stop-report.md")
        "deterministic-verification" = @("checks/verification-ledger.md", "audits/dangerous-claims-report.md")
        "independent-crosscheck" = @("checks/crosscheck-plan.md", "checks/crosscheck-results.md")
        "result-provenance-audit" = @("figures/figure-provenance.md", "figures/data-provenance.md")
        "manuscript-consistency-audit" = @("drafts/symbol-table.md", "drafts/claim-source-ledger.md", "drafts/zombie-section-report.md")
        "skill-compliance-audit" = @("audits/skill-compliance-audit-report.md")
    }
    return @($Artifacts[$Skill])
}

function Add-MarkdownRow {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string[]]$Columns
    )
    $Escaped = $Columns | ForEach-Object { ($_ -replace "\|", "/").Trim() }
    Add-Content -LiteralPath $Path -Encoding utf8 -Value ("| " + ($Escaped -join " | ") + " |")
}

$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$ProjectGitArgs = Get-SafeGitArgs -Root $ProjectRoot
$LoopDir = Join-Path $ProjectRoot ".ai-loop"
$StatusPath = Join-Path $LoopDir "status.json"
if (-not (Test-Path -LiteralPath $StatusPath)) {
    throw "Missing .ai-loop/status.json. Run init-loop.ps1 first."
}

$Status = Get-Content -LiteralPath $StatusPath -Raw | ConvertFrom-Json
if ($null -ne $Status.current_phase -and -not $Force) {
    $CurrentStatus = $Status.current_phase.status
    $CurrentPhaseId = $Status.current_phase.phase_id
    if ($CurrentStatus -notin @("accepted", "rework", "blocked")) {
        throw "Cannot start $PhaseId because current phase $CurrentPhaseId is $CurrentStatus. Finish or use -Force intentionally."
    }
}

$RunDir = Join-Path $LoopDir (Join-Path "runs" $PhaseId)
if ((Test-Path -LiteralPath $RunDir) -and -not $Force) {
    throw "Run directory already exists: $RunDir. Use -Force to overwrite start files."
}
New-Item -ItemType Directory -Force -Path $RunDir | Out-Null

$Git = Get-Command git -ErrorAction SilentlyContinue
if ($null -eq $Git) {
    "MISSING: git executable was not found." | Set-Content -LiteralPath (Join-Path $RunDir "base_commit.txt") -Encoding utf8
    "MISSING: git executable was not found." | Set-Content -LiteralPath (Join-Path $RunDir "status_before.txt") -Encoding utf8
} else {
    $Inside = & git @ProjectGitArgs rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -eq 0 -and $Inside -eq "true") {
        Invoke-GitText -GitArgs ($ProjectGitArgs + @("rev-parse", "HEAD")) |
            Set-Content -LiteralPath (Join-Path $RunDir "base_commit.txt") -Encoding utf8
        Invoke-GitText -GitArgs ($ProjectGitArgs + @("status", "--short")) |
            Set-Content -LiteralPath (Join-Path $RunDir "status_before.txt") -Encoding utf8
} else {
    "MISSING: target project is not a git repository." | Set-Content -LiteralPath (Join-Path $RunDir "base_commit.txt") -Encoding utf8
    "MISSING: target project is not a git repository." | Set-Content -LiteralPath (Join-Path $RunDir "status_before.txt") -Encoding utf8
    }
}

$DefaultSkills = @(Get-DefaultSkillsForTaskKind -Kind $TaskKind)
$AllRequiredSkills = @($DefaultSkills + $RequiredSkills | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
$SkillRequirements = @()
foreach ($Skill in $AllRequiredSkills) {
    $SkillRequirements += [pscustomobject]@{
        skill = $Skill
        trigger = Get-SkillTrigger -Skill $Skill
        required = $true
        artifacts = @(Get-SkillArtifacts -Skill $Skill)
        status = "pending"
    }
}

$EvidenceRequired = @(
    ".ai-loop/runs/$PhaseId/prompt.md",
    ".ai-loop/runs/$PhaseId/report.md",
    ".ai-loop/runs/$PhaseId/status_after.txt",
    ".ai-loop/runs/$PhaseId/diff.patch",
    ".ai-loop/runs/$PhaseId/verify.log",
    ".ai-loop/runs/$PhaseId/changed_files.txt",
    ".ai-loop/runs/$PhaseId/changed_business_files.txt",
    ".ai-loop/runs/$PhaseId/changed_evidence_files.txt"
)

$Requirements = [ordered]@{
    phase_id = $PhaseId
    task_kind = $TaskKind
    claim_ids = @($ClaimIds)
    evidence_required = @($EvidenceRequired)
    required_skills = @($AllRequiredSkills)
    required_skill_artifacts = @($SkillRequirements)
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
}
Write-JsonFile -Value ([pscustomobject]$Requirements) -Path (Join-Path $RunDir "phase_requirements.json")

$ScopeText = if ($Scope.Count -gt 0) { ($Scope | ForEach-Object { "- $_" }) -join [Environment]::NewLine } else { "- No additional scope supplied." }
$VerifyText = if ([string]::IsNullOrWhiteSpace($VerifyCommand)) { "MISSING: Supervisor did not provide a verification command." } else { $VerifyCommand }
$ClaimText = if ($ClaimIds.Count -gt 0) { ($ClaimIds | ForEach-Object { "- $_" }) -join [Environment]::NewLine } else { "- CLAIM-$PhaseId" }
$SkillText = if ($SkillRequirements.Count -gt 0) {
    ($SkillRequirements | ForEach-Object {
        "- $($_.skill): $($_.trigger); artifacts: $(@($_.artifacts) -join '; ')"
    }) -join [Environment]::NewLine
} else {
    "- None required by task kind. If you introduce correctness-sensitive, scientific, numerical, provenance, or manuscript claims, report the trigger and required skill artifacts."
}
$Prompt = @"
# Worker Prompt: $PhaseId

## Boundary

- Execute only this phase.
- Do not decide the total route.
- Do not approve or accept this phase.
- Write a report to `.ai-loop/runs/$PhaseId/report.md`.

## Phase

- Phase ID: $PhaseId
- Title: $Title
- Objective: $Objective
- Task kind: $TaskKind

## Scope

$ScopeText

## Claim IDs

$ClaimText

## Verification Command

```powershell
$VerifyText
```

## Evidence Requirements

- Write a report to `.ai-loop/runs/$PhaseId/report.md`.
- Run or preserve the verification command output in `.ai-loop/runs/$PhaseId/verify.log`.
- Do not claim completion unless durable evidence exists.

## Required Skill Triggers

$SkillText

Codex will audit the report, diff, verify log, status files, and relevant source
files before deciding `ACCEPTED`, `REWORK`, or `BLOCKED`.
"@
$Prompt | Set-Content -LiteralPath (Join-Path $RunDir "prompt.md") -Encoding utf8

$BaseCommit = Get-Content -LiteralPath (Join-Path $RunDir "base_commit.txt") -Raw
$PhaseMeta = [ordered]@{
    phase_id = $PhaseId
    title = $Title
    objective = $Objective
    status = "started"
    run_dir = ".ai-loop/runs/$PhaseId"
    audit_input = ".ai-loop/audits/$PhaseId-audit-input.md"
    audit_result = ".ai-loop/audits/$PhaseId-audit.md"
    base_commit = $BaseCommit.Trim()
    verify_command = $VerifyCommand
    task_kind = $TaskKind
    claim_ids = @($ClaimIds)
    required_skills = @($AllRequiredSkills)
    requirements = ".ai-loop/runs/$PhaseId/phase_requirements.json"
    started_at = (Get-Date).ToUniversalTime().ToString("o")
    evidence_collected_at = $null
    audit_prepared_at = $null
    accepted_at = $null
}
Write-JsonFile -Value ([pscustomobject]$PhaseMeta) -Path (Join-Path $RunDir "phase_meta.json")

$Status.current_phase = $PhaseMeta
$Status.phases = @($Status.phases) + @([pscustomobject]$PhaseMeta)
Write-JsonFile -Value $Status -Path $StatusPath

$EvidenceDir = Join-Path $LoopDir "evidence"
$SkillsDir = Join-Path $LoopDir "skills"
New-Item -ItemType Directory -Force -Path $EvidenceDir, $SkillsDir | Out-Null
$EvidenceLedger = Join-Path $EvidenceDir "evidence-ledger.md"
$ArtifactIndex = Join-Path $EvidenceDir "artifact-index.md"
$SkillUsageLedger = Join-Path $SkillsDir "skill-usage-ledger.md"

if (Test-Path -LiteralPath $EvidenceLedger) {
    Add-MarkdownRow -Path $EvidenceLedger -Columns @("EVD-$PhaseId-001", $PhaseId, "CLAIM-$PhaseId", "prompt", ".ai-loop/runs/$PhaseId/prompt.md", "Codex Supervisor", "pending", "recorded", "Worker prompt generated.")
    Add-MarkdownRow -Path $EvidenceLedger -Columns @("EVD-$PhaseId-002", $PhaseId, "CLAIM-$PhaseId", "requirements", ".ai-loop/runs/$PhaseId/phase_requirements.json", "Codex Supervisor", "pending", "recorded", "Phase requirements generated.")
}
if (Test-Path -LiteralPath $ArtifactIndex) {
    Add-MarkdownRow -Path $ArtifactIndex -Columns @("ART-$PhaseId-001", $PhaseId, "prompt", ".ai-loop/runs/$PhaseId/prompt.md", "Supervisor", "active", "Worker prompt for phase.")
    Add-MarkdownRow -Path $ArtifactIndex -Columns @("ART-$PhaseId-002", $PhaseId, "requirements", ".ai-loop/runs/$PhaseId/phase_requirements.json", "Supervisor", "active", "Gate requirements for phase.")
}
if ((Test-Path -LiteralPath $SkillUsageLedger) -and $SkillRequirements.Count -gt 0) {
    foreach ($Requirement in $SkillRequirements) {
        Add-MarkdownRow -Path $SkillUsageLedger -Columns @($PhaseId, $Requirement.trigger, $Requirement.skill, "true", (@($Requirement.artifacts) -join "; "), "pending", "Required by task kind or Supervisor input.")
    }
}

Write-Output "Started phase $PhaseId at $RunDir"

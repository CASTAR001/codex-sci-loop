[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet("init", "start", "collect", "audit-pack", "validate", "accept", "resume", "link-skills", "doctor")]
    [string]$Command,

    [Parameter(Position = 1)]
    [string]$ProjectRoot = (Get-Location).Path,

    [Parameter(Position = 2)]
    [string]$PhaseId = "",

    [string]$Title = "",
    [string]$Objective = "",
    [string[]]$Scope = @(),
    [string]$VerifyCommand = "",
    [string]$ReportPath = "",
    [string]$AuditPath = "",
    [ValidateSet("generic", "fullstack", "physics-research", "research-writing", "data-analysis")]
    [string]$TaskKind = "generic",
    [Alias("Profile")]
    [ValidateSet("none", "research-core", "physics-sim", "manuscript", "full-research")]
    [string]$SkillProfile = "none",
    [Alias("Skills")]
    [ValidateSet("research-task-tree", "invariant-contract", "bounded-experiment-loop", "deterministic-verification", "independent-crosscheck", "result-provenance-audit", "manuscript-consistency-audit", "skill-compliance-audit")]
    [string[]]$RequiredSkills = @(),
    [string[]]$ClaimIds = @(),
    [string]$SkillLibraryRoot = "E:\codexfiles\test\.agents\skills",
    [switch]$Commit,
    [string]$CommitMessage = "",
    [switch]$Force,
    [string]$OverrideReason = "",
    [switch]$CreateAgentsBootstrap
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Require-PhaseId {
    if ([string]::IsNullOrWhiteSpace($PhaseId)) {
        throw "PhaseId is required for '$Command'. Example: ai-loop $Command <project-root> phase-001"
    }
}

function Test-ResearchSkills {
    param([Parameter(Mandatory = $true)][string]$Root)
    $Required = @(
        "research-task-tree",
        "invariant-contract",
        "bounded-experiment-loop",
        "deterministic-verification",
        "independent-crosscheck",
        "result-provenance-audit",
        "manuscript-consistency-audit",
        "skill-compliance-audit"
    )
    $Problems = New-Object System.Collections.Generic.List[string]
    foreach ($Skill in $Required) {
        $Path = Join-Path $Root (Join-Path $Skill "SKILL.md")
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
            $Problems.Add($Skill)
        }
    }
    return $Problems
}

function Exit-IfScriptFailed {
    param([Parameter(Mandatory = $true)][bool]$Succeeded)
    if (-not $Succeeded) {
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
        exit 1
    }
}

$KitRoot = Split-Path -Parent $PSScriptRoot
$ProjectRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ProjectRoot)

switch ($Command) {
    "init" {
        $ScriptParams = @{ ProjectRoot = $ProjectRoot }
        if ($Force) { $ScriptParams.Force = $true }
        $global:LASTEXITCODE = 0
        & (Join-Path $PSScriptRoot "init-loop.ps1") @ScriptParams
        Exit-IfScriptFailed -Succeeded $?
        New-Item -ItemType Directory -Force -Path (Join-Path $ProjectRoot ".agents\skills") | Out-Null
        if ($CreateAgentsBootstrap) {
            $AgentsPath = Join-Path $ProjectRoot "AGENTS.md"
            if ((Test-Path -LiteralPath $AgentsPath) -and -not $Force) {
                Write-Output "AGENTS.md already exists; leaving it unchanged: $AgentsPath"
            } else {
                @(
                    '# AGENTS.md'
                    ""
                    'This project uses `.ai-loop/` as the local Supervisor-Worker loop control plane.'
                    ""
                    'Before planning or modifying files, read:'
                    ""
                    '1. `.ai-loop/README.md`'
                    '2. `.ai-loop/memory/activeContext.md`'
                    '3. `.ai-loop/memory/constraint-ledger.md`'
                    '4. `.ai-loop/gates/pre-action-check.md`'
                    ""
                    'Do not accept work from prose alone; inspect evidence, diffs, verification logs, status, changed files, skill artifacts, and relevant source.'
                ) | Set-Content -LiteralPath $AgentsPath -Encoding utf8
                Write-Output "Created AGENTS.md bootstrap: $AgentsPath"
            }
        }
        Write-Output "Initialized agent skill directory: $(Join-Path $ProjectRoot ".agents\skills")"
    }
    "start" {
        Require-PhaseId
        $ScriptParams = @{
            ProjectRoot = $ProjectRoot
            PhaseId = $PhaseId
            Title = $Title
            Objective = $Objective
            VerifyCommand = $VerifyCommand
            TaskKind = $TaskKind
            SkillProfile = $SkillProfile
        }
        if ($Scope.Count -gt 0) { $ScriptParams.Scope = $Scope }
        if ($RequiredSkills.Count -gt 0) { $ScriptParams.RequiredSkills = $RequiredSkills }
        if ($ClaimIds.Count -gt 0) { $ScriptParams.ClaimIds = $ClaimIds }
        if ($Force) { $ScriptParams.Force = $true }
        $global:LASTEXITCODE = 0
        & (Join-Path $PSScriptRoot "start-phase.ps1") @ScriptParams
        Exit-IfScriptFailed -Succeeded $?
    }
    "collect" {
        Require-PhaseId
        $ScriptParams = @{
            ProjectRoot = $ProjectRoot
            PhaseId = $PhaseId
        }
        if (-not [string]::IsNullOrWhiteSpace($ReportPath)) { $ScriptParams.ReportPath = $ReportPath }
        if (-not [string]::IsNullOrWhiteSpace($VerifyCommand)) { $ScriptParams.VerifyCommand = $VerifyCommand }
        if ($Force) { $ScriptParams.Force = $true }
        $global:LASTEXITCODE = 0
        & (Join-Path $PSScriptRoot "collect-evidence.ps1") @ScriptParams
        Exit-IfScriptFailed -Succeeded $?
    }
    "audit-pack" {
        Require-PhaseId
        $ScriptParams = @{
            ProjectRoot = $ProjectRoot
            PhaseId = $PhaseId
        }
        $global:LASTEXITCODE = 0
        & (Join-Path $PSScriptRoot "prepare-audit-pack.ps1") @ScriptParams
        Exit-IfScriptFailed -Succeeded $?
    }
    "validate" {
        Require-PhaseId
        $ScriptParams = @{
            ProjectRoot = $ProjectRoot
            PhaseId = $PhaseId
        }
        $global:LASTEXITCODE = 0
        & (Join-Path $PSScriptRoot "validate-phase-gates.ps1") @ScriptParams
        Exit-IfScriptFailed -Succeeded $?
    }
    "accept" {
        Require-PhaseId
        $ScriptParams = @{
            ProjectRoot = $ProjectRoot
            PhaseId = $PhaseId
        }
        if (-not [string]::IsNullOrWhiteSpace($AuditPath)) { $ScriptParams.AuditPath = $AuditPath }
        if (-not [string]::IsNullOrWhiteSpace($CommitMessage)) { $ScriptParams.CommitMessage = $CommitMessage }
        if (-not [string]::IsNullOrWhiteSpace($OverrideReason)) { $ScriptParams.OverrideReason = $OverrideReason }
        if ($Commit) { $ScriptParams.Commit = $true }
        if ($Force) { $ScriptParams.Force = $true }
        $global:LASTEXITCODE = 0
        & (Join-Path $PSScriptRoot "accept-phase.ps1") @ScriptParams
        Exit-IfScriptFailed -Succeeded $?
    }
    "resume" {
        $LoopDir = Join-Path $ProjectRoot ".ai-loop"
        foreach ($Path in @(
            "memory\handoff-summary.md",
            "memory\activeContext.md",
            "memory\constraint-ledger.md",
            "evidence\evidence-ledger.md",
            "skills\skill-source-map.md",
            "status.json"
        )) {
            $FullPath = Join-Path $LoopDir $Path
            Write-Output ""
            Write-Output "===== .ai-loop/$($Path -replace '\\','/') ====="
            if (Test-Path -LiteralPath $FullPath -PathType Leaf) {
                Get-Content -LiteralPath $FullPath -Raw
            } else {
                Write-Output "MISSING: $FullPath"
            }
        }
    }
    "link-skills" {
        $ScriptParams = @{
            ProjectRoot = $ProjectRoot
            SkillLibraryRoot = $SkillLibraryRoot
            Profile = $SkillProfile
        }
        if ($RequiredSkills.Count -gt 0) { $ScriptParams.Skills = $RequiredSkills }
        if ($Force) { $ScriptParams.Force = $true }
        $global:LASTEXITCODE = 0
        & (Join-Path $PSScriptRoot "link-skills.ps1") @ScriptParams
        Exit-IfScriptFailed -Succeeded $?
    }
    "doctor" {
        $TemplateDir = Join-Path $KitRoot "templates\.ai-loop"
        $PluginManifest = Join-Path (Split-Path -Parent $KitRoot) "plugins\codex-loop-harness\.codex-plugin\plugin.json"
        $SkillProblems = @(Test-ResearchSkills -Root $SkillLibraryRoot)
        Write-Output "ai-loop doctor"
        Write-Output "Kit root: $KitRoot"
        Write-Output "Template: $TemplateDir"
        Write-Output "Skill library: $SkillLibraryRoot"
        Write-Output "Plugin manifest: $PluginManifest"
        if (-not (Test-Path -LiteralPath $TemplateDir -PathType Container)) { throw "Template directory missing: $TemplateDir" }
        if (-not (Test-Path -LiteralPath $PluginManifest -PathType Leaf)) { throw "Plugin manifest missing: $PluginManifest" }
        $null = Get-Content -LiteralPath $PluginManifest -Raw | ConvertFrom-Json
        if ($SkillProblems.Count -gt 0) {
            throw "Missing required research skills: $($SkillProblems -join ', ')"
        }
        Write-Output "Required research skills: OK"
        Write-Output "Plugin manifest JSON: OK"
        Write-Output "Doctor: OK"
    }
}

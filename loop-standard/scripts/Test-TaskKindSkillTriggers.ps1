[CmdletBinding()]
param(
    [switch]$KeepTemp
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Add-Problem {
    param([Parameter(Mandatory = $true)][string]$Message)
    $script:Problems.Add($Message)
}

function Assert-UnderRoot {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Path
    )
    $ResolvedRoot = [System.IO.Path]::GetFullPath($Root)
    $ResolvedPath = [System.IO.Path]::GetFullPath($Path)
    if (-not $ResolvedPath.StartsWith($ResolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to operate outside test root: $ResolvedPath"
    }
}

function Invoke-AiLoop {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $PreviousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $Output = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $AiLoopScript @Arguments 2>&1)
    $ErrorActionPreference = $PreviousErrorActionPreference
    return [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Text = ($Output | Out-String)
    }
}

function Assert-SkillSet {
    param(
        [Parameter(Mandatory = $true)][string]$PhaseId,
        [string[]]$Expected = @(),
        [string[]]$Forbidden = @()
    )
    $RequirementsPath = Join-Path $ProjectRoot ".ai-loop\runs\$PhaseId\phase_requirements.json"
    $PromptPath = Join-Path $ProjectRoot ".ai-loop\runs\$PhaseId\prompt.md"
    if (-not (Test-Path -LiteralPath $RequirementsPath -PathType Leaf)) {
        Add-Problem "$PhaseId missing phase_requirements.json."
        return
    }
    if (-not (Test-Path -LiteralPath $PromptPath -PathType Leaf)) {
        Add-Problem "$PhaseId missing prompt.md."
        return
    }
    $Requirements = Get-Content -LiteralPath $RequirementsPath -Raw | ConvertFrom-Json
    $Actual = @($Requirements.required_skills)
    $Prompt = Get-Content -LiteralPath $PromptPath -Raw

    foreach ($Skill in $Expected) {
        if ($Actual -notcontains $Skill) {
            Add-Problem "$PhaseId missing expected skill: $Skill"
        }
        if ($Prompt -notmatch [regex]::Escape($Skill)) {
            Add-Problem "$PhaseId prompt missing expected skill text: $Skill"
        }
    }
    foreach ($Skill in $Forbidden) {
        if ($Actual -contains $Skill) {
            Add-Problem "$PhaseId should not require skill: $Skill"
        }
    }
    if (@($Requirements.required_skill_artifacts).Count -ne $Expected.Count) {
        Add-Problem "$PhaseId required_skill_artifacts count mismatch. Expected $($Expected.Count), got $(@($Requirements.required_skill_artifacts).Count)."
    }
}

function Start-TestPhase {
    param(
        [Parameter(Mandatory = $true)][string]$PhaseId,
        [Parameter(Mandatory = $true)][string]$TaskKind,
        [string]$SkillProfile = "none",
        [string[]]$RequiredSkills = @()
    )
    $Arguments = @(
        "-Command", "start",
        "-ProjectRoot", $ProjectRoot,
        "-PhaseId", $PhaseId,
        "-TaskKind", $TaskKind,
        "-SkillProfile", $SkillProfile,
        "-Title", "Skill trigger fixture $PhaseId",
        "-Objective", "Verify skill trigger behavior for $TaskKind / $SkillProfile.",
        "-VerifyCommand", "cmd.exe /c echo verify-ok",
        "-Force"
    )
    foreach ($Skill in $RequiredSkills) {
        $Arguments += @("-RequiredSkills", $Skill)
    }
    $Result = Invoke-AiLoop -Arguments $Arguments
    if ($Result.ExitCode -ne 0) {
        Add-Problem "$PhaseId start failed with exit $($Result.ExitCode): $($Result.Text)"
    }
}

$KitRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = Split-Path -Parent $KitRoot
$AiLoopScript = Join-Path $PSScriptRoot "ai-loop.ps1"
. (Join-Path $PSScriptRoot "test-temp-root.ps1")
$TempRoot = New-LoopTestTempRoot -RepoRoot $RepoRoot -Name "task-kind-skills"
$Problems = New-Object System.Collections.Generic.List[string]

Assert-UnderRoot -Root $RepoRoot -Path $TempRoot
if ((Test-Path -LiteralPath $TempRoot) -and -not $KeepTemp) {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $TempRoot | Out-Null

$ProjectRoot = Join-Path $TempRoot "project"
New-Item -ItemType Directory -Force -Path $ProjectRoot | Out-Null
$Init = Invoke-AiLoop -Arguments @("-Command", "init", "-ProjectRoot", $ProjectRoot)
if ($Init.ExitCode -ne 0) {
    Add-Problem "init failed with exit $($Init.ExitCode): $($Init.Text)"
}

Start-TestPhase -PhaseId "phase-fullstack" -TaskKind "fullstack"
Assert-SkillSet -PhaseId "phase-fullstack" -Expected @() -Forbidden @(
    "research-task-tree",
    "invariant-contract",
    "bounded-experiment-loop",
    "deterministic-verification",
    "independent-crosscheck",
    "result-provenance-audit",
    "manuscript-consistency-audit",
    "skill-compliance-audit"
)

Start-TestPhase -PhaseId "phase-physics" -TaskKind "physics-research"
Assert-SkillSet -PhaseId "phase-physics" -Expected @("invariant-contract", "deterministic-verification")

Start-TestPhase -PhaseId "phase-data" -TaskKind "data-analysis"
Assert-SkillSet -PhaseId "phase-data" -Expected @("invariant-contract", "deterministic-verification", "result-provenance-audit")

Start-TestPhase -PhaseId "phase-writing" -TaskKind "research-writing"
Assert-SkillSet -PhaseId "phase-writing" -Expected @("manuscript-consistency-audit", "deterministic-verification")

Start-TestPhase -PhaseId "phase-physics-sim" -TaskKind "physics-research" -SkillProfile "physics-sim"
Assert-SkillSet -PhaseId "phase-physics-sim" -Expected @(
    "invariant-contract",
    "deterministic-verification",
    "research-task-tree",
    "bounded-experiment-loop",
    "independent-crosscheck",
    "result-provenance-audit",
    "skill-compliance-audit"
)

Start-TestPhase -PhaseId "phase-manual-extra" -TaskKind "fullstack" -RequiredSkills @("deterministic-verification")
Assert-SkillSet -PhaseId "phase-manual-extra" -Expected @("deterministic-verification")

if ($Problems.Count -gt 0) {
    Write-Output "Task-kind skill trigger test: FAILED"
    foreach ($Problem in $Problems) {
        Write-Output "- $Problem"
    }
    Write-Output "Fixture root: $TempRoot"
    exit 2
}

Write-Output "Task-kind skill trigger test: OK"
Write-Output "Fixture root: $TempRoot"
Write-Output "Cases checked: fullstack, physics-research, data-analysis, research-writing, physics-sim profile, manual extra skill"

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PhaseId,
    [Parameter(Mandatory = $true)][string]$Title,
    [Parameter(Mandatory = $true)][string]$Objective,
    [string]$TargetRoot = (Get-Location).Path,
    [string[]]$Scope = @(),
    [string]$VerifyCommand = "",
    [ValidateSet("generic", "fullstack", "physics-research", "research-writing", "data-analysis")]
    [string]$TaskKind = "generic",
    [ValidateSet("none", "research-core", "physics-sim", "manuscript", "full-research")]
    [string]$SkillProfile = "none",
    [ValidateSet("research-task-tree", "invariant-contract", "bounded-experiment-loop", "deterministic-verification", "independent-crosscheck", "result-provenance-audit", "manuscript-consistency-audit", "skill-compliance-audit")]
    [string[]]$RequiredSkills = @(),
    [string[]]$ClaimIds = @(),
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$LoopScript = Join-Path $PSScriptRoot "ai-loop.ps1"
$Arguments = @(
    "-Command", "start",
    "-ProjectRoot", $TargetRoot,
    "-PhaseId", $PhaseId,
    "-Title", $Title,
    "-Objective", $Objective,
    "-VerifyCommand", $VerifyCommand,
    "-TaskKind", $TaskKind,
    "-SkillProfile", $SkillProfile
)
if ($Scope.Count -gt 0) { $Arguments += @("-Scope") + @($Scope) }
if ($RequiredSkills.Count -gt 0) { $Arguments += @("-RequiredSkills") + @($RequiredSkills) }
if ($ClaimIds.Count -gt 0) { $Arguments += @("-ClaimIds") + @($ClaimIds) }
if ($Force) { $Arguments += "-Force" }

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $LoopScript @Arguments
exit $LASTEXITCODE

[CmdletBinding()]
param(
    [string]$KitRoot = "",
    [switch]$AllowPilotProject
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($KitRoot)) {
    $KitRoot = Split-Path -Parent $PSScriptRoot
}
$KitRoot = (Resolve-Path -LiteralPath $KitRoot).Path
$Problems = New-Object System.Collections.Generic.List[string]

function Add-Problem {
    param([Parameter(Mandatory = $true)][string]$Message)
    $script:Problems.Add($Message)
}

function Test-RequiredPath {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $Path = Join-Path $KitRoot $RelativePath
    if (-not (Test-Path -LiteralPath $Path)) {
        Add-Problem "Missing required path: $RelativePath"
    }
}

$RequiredPaths = @(
    "README.md",
    "PHASE_A_MANIFEST.md",
    "PHASE_A_VERIFICATION.md",
    "PHASE_B_PLAN.md",
    "templates\README.md",
    "templates\.ai-loop\README.md",
    "templates\.ai-loop\loop.config.json",
    "templates\.ai-loop\status.json",
    "templates\.ai-loop\runs\README.md",
    "templates\.ai-loop\audits\README.md",
    "templates\.ai-loop\evidence\evidence-ledger.md",
    "templates\.ai-loop\evidence\artifact-index.md",
    "templates\.ai-loop\evidence\command-log.md",
    "templates\.ai-loop\evidence\test-log.md",
    "templates\.ai-loop\evidence\provenance-map.md",
    "templates\.ai-loop\skills\skill-trigger-matrix.md",
    "templates\.ai-loop\skills\skill-usage-ledger.md",
    "templates\.ai-loop\skills\skill-artifact-map.md",
    "templates\.ai-loop\evolution\project-loop-evolution.md",
    "docs\README.md",
    "docs\OPERATOR_RUNBOOK.md",
    "docs\GLOBAL_INSTALL_PLAN.md",
    "docs\CONTROL_PLANE_BUILD_PLAN.md",
    "docs\AGENTS_VS_AI_LOOP_BOUNDARY.md",
    ".ai-loop\README.md",
    ".ai-loop\loop.config.json",
    ".ai-loop\status.json",
    ".ai-loop\evidence\README.md",
    ".ai-loop\evidence\evidence-ledger.md",
    ".ai-loop\evidence\artifact-index.md",
    ".ai-loop\evidence\command-log.md",
    ".ai-loop\evidence\test-log.md",
    ".ai-loop\evidence\provenance-map.md",
    ".ai-loop\skills\skill-trigger-matrix.md",
    ".ai-loop\skills\skill-usage-ledger.md",
    ".ai-loop\skills\skill-artifact-map.md",
    ".ai-loop\evolution\project-loop-evolution.md",
    ".ai-loop\audits\README.md",
    ".ai-loop\logs\README.md",
    ".ai-loop\templates\phase-plan.md",
    ".ai-loop\templates\prompt.md",
    ".ai-loop\templates\report.md",
    ".ai-loop\templates\audit-input.md",
    ".ai-loop\templates\audit.md",
    "prompts\codex-supervisor.md",
    "prompts\kimi-worker.md",
    "prompts\codex-audit.md",
    "scripts\init-loop.ps1",
    "scripts\start-phase.ps1",
    "scripts\collect-evidence.ps1",
    "scripts\prepare-audit-pack.ps1",
    "scripts\accept-phase.ps1",
    "scripts\validate-phase-gates.ps1",
    "scripts\test-pilot-loop.ps1",
    "scripts\install-global.ps1",
    "scripts\Initialize-AiLoop.ps1",
    "scripts\Start-LoopPhase.ps1",
    "scripts\Collect-LoopEvidence.ps1",
    "scripts\Prepare-LoopAuditPackage.ps1",
    "scripts\Accept-LoopPhase.ps1",
    "scripts\Test-LoopStandard.ps1"
)

foreach ($RelativePath in $RequiredPaths) {
    Test-RequiredPath -RelativePath $RelativePath
}

foreach ($JsonRelativePath in @(".ai-loop\loop.config.json", ".ai-loop\status.json", "templates\.ai-loop\loop.config.json", "templates\.ai-loop\status.json")) {
    $JsonPath = Join-Path $KitRoot $JsonRelativePath
    if (Test-Path -LiteralPath $JsonPath) {
        try {
            $null = Get-Content -LiteralPath $JsonPath -Raw | ConvertFrom-Json
        } catch {
            Add-Problem "Invalid JSON: $JsonRelativePath :: $($_.Exception.Message)"
        }
    }
}

$ConfigPath = Join-Path $KitRoot ".ai-loop\loop.config.json"
if (Test-Path -LiteralPath $ConfigPath) {
    $Config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
    $RequiredEvidence = @("prompt.md", "report.md", "diff.patch", "verify.log", "phase_requirements.json")
    foreach ($EvidenceName in $RequiredEvidence) {
        if ($Config.phase_evidence_required -notcontains $EvidenceName) {
            Add-Problem "loop.config.json missing phase evidence: $EvidenceName"
        }
    }
    foreach ($Decision in @("ACCEPTED", "REWORK", "BLOCKED")) {
        if ($Config.decisions -notcontains $Decision) {
            Add-Problem "loop.config.json missing decision: $Decision"
        }
    }
}

Get-ChildItem -LiteralPath (Join-Path $KitRoot "scripts") -Filter "*.ps1" | ForEach-Object {
    $Tokens = $null
    $Errors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$Tokens, [ref]$Errors)
    if ($Errors.Count -gt 0) {
        foreach ($ParseError in $Errors) {
            Add-Problem "PowerShell parse error in scripts\$($_.Name): $($ParseError.Message)"
        }
    }
}

$OldEvidenceName = "worker" + "-report.md"
$OldNameHits = @(Get-ChildItem -LiteralPath $KitRoot -Recurse -Force -File |
    Select-String -Pattern $OldEvidenceName -SimpleMatch)
if ($OldNameHits.Count -gt 0) {
    foreach ($Hit in $OldNameHits) {
        Add-Problem "Old evidence name found: $($Hit.Path):$($Hit.LineNumber)"
    }
}

$WorkspaceRoot = Split-Path -Parent $KitRoot
$PilotPath = Join-Path $WorkspaceRoot "pilot-project"
if (Test-Path -LiteralPath $PilotPath) {
    if (-not $AllowPilotProject) {
        Add-Problem "pilot-project exists; Phase A self-check expects no pilot project yet: $PilotPath"
    }
}

if ($Problems.Count -gt 0) {
    Write-Output "Loop standard self-check: FAILED"
    foreach ($Problem in $Problems) {
        Write-Output "- $Problem"
    }
    exit 1
}

Write-Output "Loop standard self-check: OK"
Write-Output "Kit root: $KitRoot"
Write-Output "Checked paths: $($RequiredPaths.Count)"

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Add-Problem {
    param([Parameter(Mandatory = $true)][string]$Message)
    $script:Problems.Add($Message)
}

$KitRoot = Split-Path -Parent $PSScriptRoot
$AuditPath = Join-Path $KitRoot "docs\DELIVERY_AUDIT_1.0.md"
$Problems = New-Object System.Collections.Generic.List[string]

if (-not (Test-Path -LiteralPath $AuditPath -PathType Leaf)) {
    Add-Problem "missing delivery audit: $AuditPath"
} else {
    $Text = Get-Content -LiteralPath $AuditPath -Raw
    foreach ($Needle in @(
        "ready",
        "phase-028",
        "Test-Phase028.ps1",
        ".ai-loop/evidence/global-plugin-discovery.json",
        "PLUGIN-GLOBAL",
        "Local-first operation",
        "Markdown-first project control plane",
        "Git-trackable state",
        "Worker-agnostic loop",
        "Initialize arbitrary project folders",
        "Start bounded phases",
        "Link project-local skills",
        "External Worker preflight and invocation evidence",
        "Hash-backed evidence collection",
        "State-machine gates",
        "Audit package generation",
        "Interrupted-state recovery",
        "Durable `REWORK` and `BLOCKED` handling",
        "Project-local memory, constraints, and evolution",
        "Non-destructive migration",
        "Release readiness reporting",
        "Complete PowerShell matrix",
        "Real global Codex plugin discovery"
    )) {
        if ($Text -notmatch [regex]::Escape($Needle)) {
            Add-Problem "delivery audit missing required evidence text: $Needle"
        }
    }

    if ($Text -match "Test-Phase020.ps1") {
        Add-Problem "delivery audit should not reference stale Test-Phase020.ps1 matrix."
    }
}

if ($Problems.Count -gt 0) {
    Write-Output "Delivery audit test: FAILED"
    foreach ($Problem in $Problems) {
        Write-Output "- $Problem"
    }
    exit 2
}

Write-Output "Delivery audit test: OK"

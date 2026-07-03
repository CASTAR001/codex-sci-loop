[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Add-Problem {
    param([Parameter(Mandatory = $true)][string]$Message)
    $script:Problems.Add($Message)
}

function Assert-Text {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string[]]$Patterns
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Add-Problem "missing file: $Path"
        return
    }
    $Text = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($Text)) {
        Add-Problem "empty file: $Path"
        return
    }
    foreach ($Pattern in $Patterns) {
        if ($Text -notmatch [regex]::Escape($Pattern)) {
            Add-Problem "$Path missing required text: $Pattern"
        }
    }
}

$KitRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = Split-Path -Parent $KitRoot
$Problems = New-Object System.Collections.Generic.List[string]

$ReleaseNotes = Join-Path $KitRoot "docs\RELEASE_NOTES_1.0.md"
$Checklist = Join-Path $KitRoot "docs\OPERATOR_CHECKLIST_1.0.md"
$DeliveryAudit = Join-Path $KitRoot "docs\DELIVERY_AUDIT_1.0.md"
$Readme = Join-Path $RepoRoot "README.md"
$ReadmeEn = Join-Path $RepoRoot "README_EN.md"
$KitReadme = Join-Path $KitRoot "README.md"

Assert-Text -Path $ReleaseNotes -Patterns @(
    "ready",
    "What 1.0 Delivers",
    "Verified Matrix",
    "release-check",
    "Test-Phase028.ps1",
    "Global Plugin Evidence",
    "PLUGIN-GLOBAL",
    "No real global Codex configuration mutation"
)

Assert-Text -Path $Checklist -Patterns @(
    "Before Installing Into A Project",
    "Initialize",
    "Link Skills",
    "Start A Phase",
    "External Worker Use",
    "Collect And Audit",
    "Recovery",
    "Release Readiness",
    "highest numbered",
    "RELEASE-MATRIX"
)

Assert-Text -Path $DeliveryAudit -Patterns @(
    "Codex Loop Harness 1.0 Delivery Audit",
    "Requirement Evidence Map",
    "Local-first operation",
    "Markdown-first project control plane",
    "Worker-agnostic loop",
    "Hash-backed evidence collection",
    "State-machine gates",
    "Durable `REWORK` and `BLOCKED` handling",
    "Complete PowerShell matrix",
    "PLUGIN-GLOBAL",
    "ready"
)

Assert-Text -Path $Readme -Patterns @(
    "RELEASE_NOTES_1.0.md",
    "OPERATOR_CHECKLIST_1.0.md"
)

Assert-Text -Path $ReadmeEn -Patterns @(
    "RELEASE_NOTES_1.0.md",
    "OPERATOR_CHECKLIST_1.0.md"
)

Assert-Text -Path $KitReadme -Patterns @(
    "RELEASE_NOTES_1.0.md",
    "OPERATOR_CHECKLIST_1.0.md"
)

if ($Problems.Count -gt 0) {
    Write-Output "Release docs test: FAILED"
    foreach ($Problem in $Problems) {
        Write-Output "- $Problem"
    }
    exit 2
}

Write-Output "Release docs test: OK"

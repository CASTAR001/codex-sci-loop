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

function Invoke-AiLoop {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $Output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $AiLoop @Arguments 2>&1
    return [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Output = ($Output -join "`n")
    }
}

function Expect-Ok {
    param(
        [Parameter(Mandatory = $true)][object]$Result,
        [Parameter(Mandatory = $true)][string]$Label
    )
    if ($Result.ExitCode -ne 0) {
        Add-Problem "$Label failed with exit $($Result.ExitCode): $($Result.Output)"
    }
}

$KitRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = Split-Path -Parent $KitRoot
$AiLoop = Join-Path $PSScriptRoot "ai-loop.ps1"
. (Join-Path $PSScriptRoot "test-temp-root.ps1")
$TempRoot = New-LoopTestTempRoot -RepoRoot $RepoRoot -Name "prune-temp-json"
$Problems = New-Object System.Collections.Generic.List[string]

if ((Test-Path -LiteralPath $TempRoot) -and -not $KeepTemp) {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $TempRoot | Out-Null

try {
    $Parent = Join-Path $TempRoot ".tmp-ai-loop-json"
    $OldRun = Join-Path $Parent "run-old"
    $NewRun = Join-Path $Parent "run-new"
    foreach ($Path in @($OldRun, $NewRun)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
        "marker" | Set-Content -LiteralPath (Join-Path $Path "marker.txt") -Encoding utf8
    }
    (Get-Item -LiteralPath $OldRun).LastWriteTimeUtc = (Get-Date).ToUniversalTime().AddDays(-7)
    (Get-Item -LiteralPath $NewRun).LastWriteTimeUtc = (Get-Date).ToUniversalTime()

    $DryRun = Invoke-AiLoop -Arguments @(
        "-Command", "prune-temp",
        "-ProjectRoot", $TempRoot,
        "-MinAgeHours", "24",
        "-KeepLatest", "1",
        "-Json"
    )
    Expect-Ok -Result $DryRun -Label "dry-run prune JSON"
    try {
        $DryRunJson = $DryRun.Output | ConvertFrom-Json
        if ($DryRunJson.mode -ne "dry-run") {
            Add-Problem "dry-run JSON mode was not dry-run: $($DryRunJson.mode)"
        }
        if ($DryRunJson.candidate_count -ne 1) {
            Add-Problem "dry-run JSON candidate_count should be 1: $($DryRun.Output)"
        }
        if ($DryRunJson.deleted_count -ne 0) {
            Add-Problem "dry-run JSON deleted_count should be 0: $($DryRun.Output)"
        }
        if (@($DryRunJson.candidates).Count -ne 1) {
            Add-Problem "dry-run JSON should include one candidate row: $($DryRun.Output)"
        }
        if ($DryRun.Output -match "AI Loop temp fixture prune") {
            Add-Problem "dry-run JSON output mixed text with JSON: $($DryRun.Output)"
        }
    } catch {
        Add-Problem "dry-run JSON was not parseable: $($_.Exception.Message) :: $($DryRun.Output)"
    }
    if (-not (Test-Path -LiteralPath $OldRun -PathType Container)) {
        Add-Problem "dry-run JSON removed old run unexpectedly."
    }

    $Delete = Invoke-AiLoop -Arguments @(
        "-Command", "prune-temp",
        "-ProjectRoot", $TempRoot,
        "-MinAgeHours", "24",
        "-KeepLatest", "1",
        "-Force",
        "-Json"
    )
    Expect-Ok -Result $Delete -Label "force prune JSON"
    try {
        $DeleteJson = $Delete.Output | ConvertFrom-Json
        if ($DeleteJson.mode -ne "delete") {
            Add-Problem "force JSON mode was not delete: $($DeleteJson.mode)"
        }
        if ($DeleteJson.candidate_count -ne 1) {
            Add-Problem "force JSON candidate_count should be 1: $($Delete.Output)"
        }
        if ($DeleteJson.deleted_count -ne 1) {
            Add-Problem "force JSON deleted_count should be 1: $($Delete.Output)"
        }
        if (@($DeleteJson.deleted).Count -ne 1) {
            Add-Problem "force JSON should include one deleted row: $($Delete.Output)"
        }
        if ($Delete.Output -match "Deleted count:") {
            Add-Problem "force JSON output mixed text with JSON: $($Delete.Output)"
        }
    } catch {
        Add-Problem "force JSON was not parseable: $($_.Exception.Message) :: $($Delete.Output)"
    }
    if (Test-Path -LiteralPath $OldRun -PathType Container) {
        Add-Problem "force JSON did not delete old run."
    }
    if (-not (Test-Path -LiteralPath $NewRun -PathType Container)) {
        Add-Problem "force JSON deleted retained new run."
    }
} finally {
    if ($Problems.Count -gt 0 -or $KeepTemp) {
        Write-Output "Fixture root: $TempRoot"
    } elseif (Test-Path -LiteralPath $TempRoot) {
        Remove-Item -LiteralPath $TempRoot -Recurse -Force
    }
}

if ($Problems.Count -gt 0) {
    Write-Output "Prune temp JSON test: FAILED"
    foreach ($Problem in $Problems) {
        Write-Output "- $Problem"
    }
    exit 2
}

Write-Output "Prune temp JSON test: OK"

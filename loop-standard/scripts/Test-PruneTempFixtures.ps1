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
$TempRoot = New-LoopTestTempRoot -RepoRoot $RepoRoot -Name "prune-temp-fixtures"
$Problems = New-Object System.Collections.Generic.List[string]

if ((Test-Path -LiteralPath $TempRoot) -and -not $KeepTemp) {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $TempRoot | Out-Null

try {
    $Parent = Join-Path $TempRoot ".tmp-ai-loop-alpha"
    $OtherParent = Join-Path $TempRoot ".tmp-not-ai-loop"
    $OldRunA = Join-Path $Parent "run-old-a"
    $OldRunB = Join-Path $Parent "run-old-b"
    $NewRun = Join-Path $Parent "run-new"
    $NotRun = Join-Path $Parent "scratch-old"
    $OutsideNamespaceRun = Join-Path $OtherParent "run-old"

    foreach ($Path in @($OldRunA, $OldRunB, $NewRun, $NotRun, $OutsideNamespaceRun)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
        "marker" | Set-Content -LiteralPath (Join-Path $Path "marker.txt") -Encoding utf8
    }

    (Get-Item -LiteralPath $OldRunA).LastWriteTimeUtc = (Get-Date).ToUniversalTime().AddDays(-5)
    (Get-Item -LiteralPath $OldRunB).LastWriteTimeUtc = (Get-Date).ToUniversalTime().AddDays(-4)
    (Get-Item -LiteralPath $NewRun).LastWriteTimeUtc = (Get-Date).ToUniversalTime()
    (Get-Item -LiteralPath $NotRun).LastWriteTimeUtc = (Get-Date).ToUniversalTime().AddDays(-5)
    (Get-Item -LiteralPath $OutsideNamespaceRun).LastWriteTimeUtc = (Get-Date).ToUniversalTime().AddDays(-5)

    $DryRun = Invoke-AiLoop -Arguments @(
        "-Command", "prune-temp",
        "-ProjectRoot", $TempRoot,
        "-MinAgeHours", "24",
        "-KeepLatest", "1"
    )
    Expect-Ok -Result $DryRun -Label "dry-run prune"
    if ($DryRun.Output -notmatch "Mode: dry-run") {
        Add-Problem "dry-run output did not report dry-run mode: $($DryRun.Output)"
    }
    if ($DryRun.Output -notmatch "Candidate count: 2") {
        Add-Problem "dry-run should report two old run candidates: $($DryRun.Output)"
    }
    foreach ($Path in @($OldRunA, $OldRunB, $NewRun, $NotRun, $OutsideNamespaceRun)) {
        if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
            Add-Problem "dry-run removed a directory unexpectedly: $Path"
        }
    }

    $Delete = Invoke-AiLoop -Arguments @(
        "-Command", "prune-temp",
        "-ProjectRoot", $TempRoot,
        "-MinAgeHours", "24",
        "-KeepLatest", "1",
        "-Force"
    )
    Expect-Ok -Result $Delete -Label "force prune"
    if ($Delete.Output -notmatch "Mode: delete") {
        Add-Problem "force output did not report delete mode: $($Delete.Output)"
    }
    if ($Delete.Output -notmatch "Deleted count: 2") {
        Add-Problem "force prune should delete two old run candidates: $($Delete.Output)"
    }
    foreach ($Path in @($OldRunA, $OldRunB)) {
        if (Test-Path -LiteralPath $Path -PathType Container) {
            Add-Problem "old run directory was not pruned: $Path"
        }
    }
    foreach ($Path in @($NewRun, $NotRun, $OutsideNamespaceRun)) {
        if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
            Add-Problem "prune removed a protected directory: $Path"
        }
    }

    $NoCandidates = Invoke-AiLoop -Arguments @(
        "-Command", "prune-temp",
        "-ProjectRoot", $TempRoot,
        "-MinAgeHours", "24",
        "-KeepLatest", "1",
        "-Force"
    )
    Expect-Ok -Result $NoCandidates -Label "idempotent prune"
    if ($NoCandidates.Output -notmatch "Candidate count: 0") {
        Add-Problem "second prune should be idempotent with no candidates: $($NoCandidates.Output)"
    }
} finally {
    if ($Problems.Count -gt 0 -or $KeepTemp) {
        Write-Output "Fixture root: $TempRoot"
    } elseif (Test-Path -LiteralPath $TempRoot) {
        Remove-Item -LiteralPath $TempRoot -Recurse -Force
    }
}

if ($Problems.Count -gt 0) {
    Write-Output "Prune temp fixtures test: FAILED"
    foreach ($Problem in $Problems) {
        Write-Output "- $Problem"
    }
    exit 2
}

Write-Output "Prune temp fixtures test: OK"

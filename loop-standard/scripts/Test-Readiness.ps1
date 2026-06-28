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
    $PreviousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $Output = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $AiLoop @Arguments 2>&1)
    $ExitCode = $LASTEXITCODE
    $ErrorActionPreference = $PreviousErrorActionPreference
    return [pscustomobject]@{
        ExitCode = $ExitCode
        Output = ($Output | Out-String).Trim()
    }
}

$KitRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = Split-Path -Parent $KitRoot
$AiLoop = Join-Path $PSScriptRoot "ai-loop.ps1"
. (Join-Path $PSScriptRoot "test-temp-root.ps1")
$TempRoot = New-LoopTestTempRoot -RepoRoot $RepoRoot -Name "readiness"
$Problems = New-Object System.Collections.Generic.List[string]

if ((Test-Path -LiteralPath $TempRoot) -and -not $KeepTemp) {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $TempRoot | Out-Null

try {
    $RootJson = Invoke-AiLoop -Arguments @("-Command", "readiness", "-ProjectRoot", $RepoRoot, "-Json")
    if ($RootJson.ExitCode -ne 0) {
        Add-Problem "root readiness JSON should not fail. Exit=$($RootJson.ExitCode) Output=$($RootJson.Output)"
    } else {
        try {
            $Parsed = $RootJson.Output | ConvertFrom-Json
            if ($Parsed.status -notin @("ready", "ready_with_warnings")) {
                Add-Problem "root readiness status should be ready or ready_with_warnings: $($Parsed.status)"
            }
            if ([int]$Parsed.summary.fail -ne 0) {
                Add-Problem "root readiness should have zero failing checks: $($RootJson.Output)"
            }
            $PluginGlobal = @($Parsed.checks | Where-Object { $_.id -eq "PLUGIN-GLOBAL" }) | Select-Object -First 1
            if ($null -eq $PluginGlobal -or $PluginGlobal.status -ne "warn") {
                Add-Problem "root readiness should include PLUGIN-GLOBAL warning until real global install is approved."
            }
            if ($RootJson.Output -match "Loop Harness 1.0 Readiness") {
                Add-Problem "root readiness JSON mixed human-readable text with JSON."
            }
        } catch {
            Add-Problem "root readiness JSON was not parseable: $($_.Exception.Message) :: $($RootJson.Output)"
        }
    }

    $RootText = Invoke-AiLoop -Arguments @("-Command", "readiness", "-ProjectRoot", $RepoRoot)
    if ($RootText.ExitCode -ne 0) {
        Add-Problem "root readiness text should not fail. Exit=$($RootText.ExitCode) Output=$($RootText.Output)"
    } elseif ($RootText.Output -notmatch "Loop Harness 1.0 Readiness") {
        Add-Problem "root readiness text missing heading: $($RootText.Output)"
    }

    $EmptyProject = Join-Path $TempRoot "empty-project"
    New-Item -ItemType Directory -Force -Path $EmptyProject | Out-Null
    $EmptyJson = Invoke-AiLoop -Arguments @("-Command", "readiness", "-ProjectRoot", $EmptyProject, "-Json")
    if ($EmptyJson.ExitCode -eq 0) {
        Add-Problem "empty project readiness should fail because .ai-loop is missing."
    }
    try {
        $ParsedEmpty = $EmptyJson.Output | ConvertFrom-Json
        if ($ParsedEmpty.status -ne "blocked") {
            Add-Problem "empty project readiness status should be blocked: $($ParsedEmpty.status)"
        }
        if ([int]$ParsedEmpty.summary.fail -le 0) {
            Add-Problem "empty project readiness should report failing checks: $($EmptyJson.Output)"
        }
    } catch {
        Add-Problem "empty project readiness failure should still emit parseable JSON: $($_.Exception.Message) :: $($EmptyJson.Output)"
    }
} finally {
    if ($Problems.Count -gt 0 -or $KeepTemp) {
        Write-Output "Fixture root: $TempRoot"
    } elseif (Test-Path -LiteralPath $TempRoot) {
        Remove-Item -LiteralPath $TempRoot -Recurse -Force
    }
}

if ($Problems.Count -gt 0) {
    Write-Output "Readiness test: FAILED"
    foreach ($Problem in $Problems) {
        Write-Output "- $Problem"
    }
    exit 2
}

Write-Output "Readiness test: OK"

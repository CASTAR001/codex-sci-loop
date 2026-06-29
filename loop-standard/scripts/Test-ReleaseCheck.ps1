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
$TempRoot = New-LoopTestTempRoot -RepoRoot $RepoRoot -Name "release-check"
$Problems = New-Object System.Collections.Generic.List[string]

if ((Test-Path -LiteralPath $TempRoot) -and -not $KeepTemp) {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $TempRoot | Out-Null

try {
    $SkipJson = Invoke-AiLoop -Arguments @("-Command", "release-check", "-ProjectRoot", $RepoRoot, "-Json", "-SkipMatrix")
    if ($SkipJson.ExitCode -ne 0) {
        Add-Problem "release-check -Json -SkipMatrix should not fail. Exit=$($SkipJson.ExitCode) Output=$($SkipJson.Output)"
    } else {
        try {
            $Parsed = $SkipJson.Output | ConvertFrom-Json
            if ($Parsed.status -ne "ready_with_warnings") {
                Add-Problem "skip-matrix release-check should be ready_with_warnings: $($Parsed.status)"
            }
            if ([int]$Parsed.summary.fail -ne 0) {
                Add-Problem "skip-matrix release-check should have zero failures: $($SkipJson.Output)"
            }
            if ([int]$Parsed.summary.skipped -ne 1) {
                Add-Problem "skip-matrix release-check should report one skipped check."
            }
            if ($SkipJson.Output -match "Loop Harness 1.0 Release Check") {
                Add-Problem "release-check JSON mixed human-readable heading into JSON."
            }
        } catch {
            Add-Problem "release-check -Json -SkipMatrix was not parseable JSON: $($_.Exception.Message) :: $($SkipJson.Output)"
        }
    }

    $MatrixJson = Invoke-AiLoop -Arguments @("-Command", "release-check", "-ProjectRoot", $RepoRoot, "-Json", "-MatrixScript", "Test-TaskKindSkillTriggers.ps1")
    if ($MatrixJson.ExitCode -ne 0) {
        Add-Problem "release-check with focused MatrixScript should not fail. Exit=$($MatrixJson.ExitCode) Output=$($MatrixJson.Output)"
    } else {
        try {
            $ParsedMatrix = $MatrixJson.Output | ConvertFrom-Json
            $MatrixCheck = @($ParsedMatrix.checks | Where-Object { $_.id -eq "RELEASE-MATRIX" }) | Select-Object -First 1
            if ($null -eq $MatrixCheck -or $MatrixCheck.status -ne "pass") {
                Add-Problem "focused release-check matrix should pass: $($MatrixJson.Output)"
            }
            if ($ParsedMatrix.commands.matrix.output -notmatch "Task-kind skill trigger test: OK") {
                Add-Problem "focused release-check did not run the requested matrix script."
            }
        } catch {
            Add-Problem "release-check focused matrix JSON was not parseable: $($_.Exception.Message) :: $($MatrixJson.Output)"
        }
    }

    $Text = Invoke-AiLoop -Arguments @("-Command", "release-check", "-ProjectRoot", $RepoRoot, "-SkipMatrix")
    if ($Text.ExitCode -ne 0) {
        Add-Problem "release-check text -SkipMatrix should not fail. Exit=$($Text.ExitCode) Output=$($Text.Output)"
    } elseif ($Text.Output -notmatch "Loop Harness 1.0 Release Check") {
        Add-Problem "release-check text output missing heading: $($Text.Output)"
    }

    $EmptyProject = Join-Path $TempRoot "empty-project"
    New-Item -ItemType Directory -Force -Path $EmptyProject | Out-Null
    $EmptyJson = Invoke-AiLoop -Arguments @("-Command", "release-check", "-ProjectRoot", $EmptyProject, "-Json", "-SkipMatrix")
    if ($EmptyJson.ExitCode -eq 0) {
        Add-Problem "empty project release-check should fail because .ai-loop is missing."
    }
    try {
        $ParsedEmpty = $EmptyJson.Output | ConvertFrom-Json
        if ($ParsedEmpty.status -ne "blocked") {
            Add-Problem "empty project release-check status should be blocked: $($ParsedEmpty.status)"
        }
        if ([int]$ParsedEmpty.summary.fail -le 0) {
            Add-Problem "empty project release-check should report failing checks."
        }
    } catch {
        Add-Problem "empty project release-check failure should still emit parseable JSON: $($_.Exception.Message) :: $($EmptyJson.Output)"
    }
} finally {
    if ($Problems.Count -gt 0 -or $KeepTemp) {
        Write-Output "Fixture root: $TempRoot"
    } elseif (Test-Path -LiteralPath $TempRoot) {
        Remove-Item -LiteralPath $TempRoot -Recurse -Force
    }
}

if ($Problems.Count -gt 0) {
    Write-Output "Release check test: FAILED"
    foreach ($Problem in $Problems) {
        Write-Output "- $Problem"
    }
    exit 2
}

Write-Output "Release check test: OK"

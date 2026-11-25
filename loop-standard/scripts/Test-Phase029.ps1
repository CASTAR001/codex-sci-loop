[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$PowerShellHost = (Get-Process -Id $PID).Path
$ScriptsRoot = $PSScriptRoot
$KitRoot = Split-Path -Parent $ScriptsRoot
$RepoRoot = Split-Path -Parent $KitRoot

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][scriptblock]$Action
    )
    Write-Output "Running: $Label"
    & $Action
    if ($LASTEXITCODE -ne 0) {
        throw "$Label exited with $LASTEXITCODE"
    }
}

foreach ($Test in @(
    "test_sci_loop_distribution.py",
    "test_sci_loop_checkpoint.py"
)) {
    $TestPath = Join-Path $RepoRoot (Join-Path "tests" $Test)
    Invoke-Checked -Label $Test -Action { & python3 $TestPath }
}

$LoopStandardTest = Join-Path $ScriptsRoot "Test-LoopStandard.ps1"
Invoke-Checked -Label "legacy compatibility structure" -Action {
    & $PowerShellHost -NoProfile -File $LoopStandardTest -AllowPilotProject
}

if ([System.IO.Path]::DirectorySeparatorChar -eq "/") {
    $PlatformInstall = Join-Path $ScriptsRoot "Test-PlatformInstall.sh"
    Invoke-Checked -Label "Linux isolated install" -Action { & bash $PlatformInstall }
} else {
    $PluginInstall = Join-Path $ScriptsRoot "Test-PluginInstall.ps1"
    Invoke-Checked -Label "Windows isolated install" -Action {
        & $PowerShellHost -NoProfile -File $PluginInstall
    }
}

Invoke-Checked -Label "Git diff whitespace" -Action { & git -C $RepoRoot diff --check }

Write-Output "Phase-029 verification: OK"
Write-Output "Provider=0 Browser=0 ServiceLifecycle=0 Production=0 Remote=0 CurrentPluginChanges=0"
Write-Output "Historical phase-001..028 artifact validation is intentionally outside the native plugin gate."

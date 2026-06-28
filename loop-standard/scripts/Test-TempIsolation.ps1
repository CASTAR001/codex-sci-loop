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

$KitRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = Split-Path -Parent $KitRoot
. (Join-Path $PSScriptRoot "test-temp-root.ps1")
$TempRoot = New-LoopTestTempRoot -RepoRoot $RepoRoot -Name "temp-isolation"
$PluginTest = Join-Path $PSScriptRoot "Test-PluginInstall.ps1"
$Problems = New-Object System.Collections.Generic.List[string]

if (-not (Test-Path -LiteralPath $PluginTest -PathType Leaf)) {
    throw "Test-PluginInstall.ps1 missing: $PluginTest"
}

if ((Test-Path -LiteralPath $TempRoot) -and -not $KeepTemp) {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $TempRoot | Out-Null

$Processes = @()
foreach ($Index in 1..2) {
    $OutPath = Join-Path $TempRoot "plugin-$Index.out.txt"
    $ErrPath = Join-Path $TempRoot "plugin-$Index.err.txt"
    $PowerShellPath = (Get-Command powershell.exe).Source
    $EscapedPluginTest = $PluginTest.Replace('"', '\"')
    $StartInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $StartInfo.FileName = $PowerShellPath
    $StartInfo.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$EscapedPluginTest`""
    $StartInfo.UseShellExecute = $false
    $StartInfo.RedirectStandardOutput = $true
    $StartInfo.RedirectStandardError = $true
    $StartInfo.CreateNoWindow = $true
    $Process = [System.Diagnostics.Process]::new()
    $Process.StartInfo = $StartInfo
    [void]$Process.Start()
    $Processes += [pscustomobject]@{
        Index = $Index
        OutPath = $OutPath
        ErrPath = $ErrPath
        Process = $Process
    }
}

foreach ($Entry in $Processes) {
    $OutText = $Entry.Process.StandardOutput.ReadToEnd()
    $ErrText = $Entry.Process.StandardError.ReadToEnd()
    $Entry.Process.WaitForExit()
    $OutText | Set-Content -LiteralPath $Entry.OutPath -Encoding utf8
    $ErrText | Set-Content -LiteralPath $Entry.ErrPath -Encoding utf8
    if ($Entry.Process.ExitCode -ne 0) {
        Add-Problem "parallel plugin smoke $($Entry.Index) failed with exit $($Entry.Process.ExitCode): $OutText $ErrText"
    }
}

$InstallRoots = @()
foreach ($Entry in $Processes) {
    $OutText = if (Test-Path -LiteralPath $Entry.OutPath) { Get-Content -LiteralPath $Entry.OutPath -Raw } else { "" }
    $Match = [regex]::Match($OutText, "(?m)^Install root:\s*(.+?)\s*$")
    if (-not $Match.Success) {
        Add-Problem "parallel plugin smoke $($Entry.Index) did not report install root: $OutText"
        continue
    }
    $InstallRoot = $Match.Groups[1].Value.Trim()
    $InstallRoots += $InstallRoot
    if (-not (Test-Path -LiteralPath (Join-Path $InstallRoot "bin\ai-loop.ps1") -PathType Leaf)) {
        Add-Problem "parallel plugin smoke $($Entry.Index) missing installed shim: $InstallRoot"
    }
}

if (@($InstallRoots | Select-Object -Unique).Count -ne 2) {
    Add-Problem "parallel plugin smoke tests should use distinct install roots: $($InstallRoots -join '; ')"
}

if ($Problems.Count -gt 0) {
    Write-Output "Temp isolation test: FAILED"
    foreach ($Problem in $Problems) {
        Write-Output "- $Problem"
    }
    Write-Output "Fixture root: $TempRoot"
    exit 2
}

Write-Output "Temp isolation test: OK"
Write-Output "Fixture root: $TempRoot"
Write-Output "Parallel install roots: $($InstallRoots -join '; ')"

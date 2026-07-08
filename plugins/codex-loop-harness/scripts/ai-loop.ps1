[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Arguments
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$PluginRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PluginRoot)
$LoopScript = Join-Path $RepoRoot "loop-standard\scripts\ai-loop.ps1"
if (-not (Test-Path -LiteralPath $LoopScript -PathType Leaf)) {
    $ConfiguredRoot = $env:LOOP_STANDARD_ROOT
    if (-not [string]::IsNullOrWhiteSpace($ConfiguredRoot)) {
        $LoopScript = Join-Path $ConfiguredRoot "scripts\ai-loop.ps1"
    }
}
if (-not (Test-Path -LiteralPath $LoopScript -PathType Leaf)) {
    throw "Cannot locate loop-standard scripts. Set LOOP_STANDARD_ROOT or run from the development repository."
}

$PowerShellHost = if ([System.IO.Path]::DirectorySeparatorChar -eq "\") { "powershell.exe" } else { "pwsh" }
if ($null -eq (Get-Command $PowerShellHost -ErrorAction SilentlyContinue)) {
    throw "Cannot locate $PowerShellHost. Install PowerShell 7 (pwsh) on Linux/macOS or Windows PowerShell on Windows."
}

& $PowerShellHost -NoProfile -ExecutionPolicy Bypass -File $LoopScript @Arguments
exit $LASTEXITCODE

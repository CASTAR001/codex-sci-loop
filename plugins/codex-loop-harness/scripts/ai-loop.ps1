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

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $LoopScript @Arguments
exit $LASTEXITCODE

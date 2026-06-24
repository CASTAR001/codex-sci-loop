[CmdletBinding()]
param(
    [string]$TargetRoot = (Get-Location).Path,
    [switch]$CreateAgentsBootstrap,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$LoopScript = Join-Path $PSScriptRoot "ai-loop.ps1"
$Arguments = @("-Command", "init", "-ProjectRoot", $TargetRoot)
if ($CreateAgentsBootstrap) { $Arguments += "-CreateAgentsBootstrap" }
if ($Force) { $Arguments += "-Force" }

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $LoopScript @Arguments
exit $LASTEXITCODE

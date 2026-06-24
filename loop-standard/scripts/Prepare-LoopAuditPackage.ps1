[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PhaseId,
    [string]$TargetRoot = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$LoopScript = Join-Path $PSScriptRoot "ai-loop.ps1"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $LoopScript -Command audit-pack -ProjectRoot $TargetRoot -PhaseId $PhaseId
exit $LASTEXITCODE

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PhaseId,
    [string]$TargetRoot = (Get-Location).Path,
    [string]$ReportPath = "",
    [string]$VerifyCommand = "",
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$LoopScript = Join-Path $PSScriptRoot "ai-loop.ps1"
$Arguments = @("-Command", "collect", "-ProjectRoot", $TargetRoot, "-PhaseId", $PhaseId)
if (-not [string]::IsNullOrWhiteSpace($ReportPath)) { $Arguments += @("-ReportPath", $ReportPath) }
if (-not [string]::IsNullOrWhiteSpace($VerifyCommand)) { $Arguments += @("-VerifyCommand", $VerifyCommand) }
if ($Force) { $Arguments += "-Force" }

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $LoopScript @Arguments
exit $LASTEXITCODE

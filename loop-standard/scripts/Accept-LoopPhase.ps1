[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PhaseId,
    [ValidateSet("ACCEPTED", "REWORK", "BLOCKED")][string]$Decision = "ACCEPTED",
    [string]$TargetRoot = (Get-Location).Path,
    [string]$AuditPath = "",
    [switch]$Commit,
    [string]$CommitMessage = "",
    [switch]$Force,
    [string]$OverrideReason = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($Decision -ne "ACCEPTED") {
    Write-Output "Compatibility wrapper does not accept non-ACCEPTED phases. Write the audit decision and keep the phase in REWORK or BLOCKED."
    exit 2
}

$LoopScript = Join-Path $PSScriptRoot "ai-loop.ps1"
$Arguments = @("-Command", "accept", "-ProjectRoot", $TargetRoot, "-PhaseId", $PhaseId)
if (-not [string]::IsNullOrWhiteSpace($AuditPath)) { $Arguments += @("-AuditPath", $AuditPath) }
if ($Commit) { $Arguments += "-Commit" }
if (-not [string]::IsNullOrWhiteSpace($CommitMessage)) { $Arguments += @("-CommitMessage", $CommitMessage) }
if ($Force) { $Arguments += "-Force" }
if (-not [string]::IsNullOrWhiteSpace($OverrideReason)) { $Arguments += @("-OverrideReason", $OverrideReason) }

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $LoopScript @Arguments
exit $LASTEXITCODE

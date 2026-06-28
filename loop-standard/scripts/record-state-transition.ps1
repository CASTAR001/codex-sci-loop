[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][string]$PhaseId,
    [string]$FromStatus = "",
    [Parameter(Mandatory = $true)][string]$ToStatus,
    [Parameter(Mandatory = $true)][string]$Actor,
    [Parameter(Mandatory = $true)][string]$Action,
    [string]$Reason = "",
    [string[]]$Paths = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$LoopDir = Join-Path $ProjectRoot ".ai-loop"
$EventsDir = Join-Path $LoopDir "events"
$TransitionLog = Join-Path $EventsDir "state-transitions.ndjson"
New-Item -ItemType Directory -Force -Path $EventsDir | Out-Null

$Entry = [ordered]@{
    schema_version = "1.0"
    ts = (Get-Date).ToUniversalTime().ToString("o")
    phase_id = $PhaseId
    from_status = $FromStatus
    to_status = $ToStatus
    actor = $Actor
    action = $Action
    reason = $Reason
    paths = @($Paths)
}

($Entry | ConvertTo-Json -Depth 20 -Compress) | Add-Content -LiteralPath $TransitionLog -Encoding utf8

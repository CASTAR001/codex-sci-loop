[CmdletBinding()]
param(
    [string]$ExpectedMessage = "hello",
    [string]$ExpectedPhase = "baseline"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$GreetingPath = Join-Path $ProjectRoot "src\greeting.txt"

if (-not (Test-Path -LiteralPath $GreetingPath)) {
    throw "Missing greeting file: $GreetingPath"
}

$Lines = Get-Content -LiteralPath $GreetingPath
$ExpectedMessageLine = "message=$ExpectedMessage"
$ExpectedPhaseLine = "phase=$ExpectedPhase"

if ($Lines -notcontains $ExpectedMessageLine) {
    throw "Expected line not found: $ExpectedMessageLine"
}

if ($Lines -notcontains $ExpectedPhaseLine) {
    throw "Expected line not found: $ExpectedPhaseLine"
}

Write-Output "verify: OK"
Write-Output "message: $ExpectedMessage"
Write-Output "phase: $ExpectedPhase"

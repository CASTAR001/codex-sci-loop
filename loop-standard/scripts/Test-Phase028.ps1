[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Scripts = @(
    @{ Path = ".\loop-standard\scripts\Test-GlobalPluginDiscoveryEvidence.ps1"; Arguments = @() },
    @{ Path = ".\loop-standard\scripts\Test-Readiness.ps1"; Arguments = @() },
    @{ Path = ".\loop-standard\scripts\Test-Phase027.ps1"; Arguments = @() }
)

foreach ($Script in $Scripts) {
    $ScriptPath = $Script.Path
    Write-Output "Running: $ScriptPath $($Script.Arguments -join ' ')"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @($Script.Arguments)
    if ($LASTEXITCODE -ne 0) {
        Write-Output "FAILED: $ScriptPath exited with $LASTEXITCODE"
        exit $LASTEXITCODE
    }
}

Write-Output "Phase-028 verification: OK"

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Scripts = @(
    @{ Path = ".\loop-standard\scripts\Test-LoopStandard.ps1"; Arguments = @("-AllowPilotProject") },
    @{ Path = ".\loop-standard\scripts\Test-PluginInstall.ps1"; Arguments = @() },
    @{ Path = ".\loop-standard\scripts\Test-ValidateLoopFailures.ps1"; Arguments = @() },
    @{ Path = ".\loop-standard\scripts\Test-CollectLedgerIdempotence.ps1"; Arguments = @() },
    @{ Path = ".\loop-standard\scripts\Test-SchemaVersioning.ps1"; Arguments = @() },
    @{ Path = ".\loop-standard\scripts\Test-PhaseDecisions.ps1"; Arguments = @() },
    @{ Path = ".\loop-standard\scripts\validate-loop.ps1"; Arguments = @("-ProjectRoot", ".") }
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

Write-Output "Phase-006 verification: OK"

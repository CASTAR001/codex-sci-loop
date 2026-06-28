[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Scripts = @(
    @{ Path = ".\loop-standard\scripts\Test-LoopStandard.ps1"; Arguments = @("-AllowPilotProject") },
    @{ Path = ".\loop-standard\scripts\Test-AuditFindingExtraction.ps1"; Arguments = @() },
    @{ Path = ".\loop-standard\scripts\Test-Phase014.ps1"; Arguments = @() },
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

Write-Output "Phase-015 verification: OK"

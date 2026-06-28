[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Scripts = @(
    @{ Path = ".\loop-standard\scripts\Test-TaskKindSkillTriggers.ps1"; Arguments = @() },
    @{ Path = ".\loop-standard\scripts\Test-Phase022.ps1"; Arguments = @() },
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

Write-Output "Phase-023 verification: OK"

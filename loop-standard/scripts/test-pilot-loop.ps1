[CmdletBinding()]
param(
    [string]$WorkspaceRoot = "",
    [switch]$KeepTemp
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($WorkspaceRoot)) {
    $WorkspaceRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
}
$WorkspaceRoot = (Resolve-Path -LiteralPath $WorkspaceRoot).Path
$KitRoot = Split-Path -Parent $PSScriptRoot
$TempRoot = Join-Path $WorkspaceRoot (".tmp-loop-e2e-" + (Get-Date -Format "yyyyMMddHHmmss"))
$ProjectRoot = Join-Path $TempRoot "pilot"
$ProjectGitArgs = @("-c", "safe.directory=$($ProjectRoot.Replace('\', '/'))", "-c", "core.excludesFile=", "-c", "core.autocrlf=false", "-C", $ProjectRoot)

function Invoke-NativeChecked {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )
    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code ${LASTEXITCODE}: $FilePath $($Arguments -join ' ')"
    }
}

New-Item -ItemType Directory -Force -Path (Join-Path $ProjectRoot "src"), (Join-Path $ProjectRoot "tests") | Out-Null

@(
    "# Temporary Pilot"
    ""
    "Run verification:"
    ""
    "powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\verify.ps1"
) | Set-Content -LiteralPath (Join-Path $ProjectRoot "README.md") -Encoding utf8

@"
message=hello
phase=baseline
"@ | Set-Content -LiteralPath (Join-Path $ProjectRoot "src\greeting.txt") -Encoding utf8

@"
[CmdletBinding()]
param(
    [string]`$ExpectedMessage = "hello",
    [string]`$ExpectedPhase = "baseline"
)

Set-StrictMode -Version Latest
`$ErrorActionPreference = "Stop"

`$ProjectRoot = Split-Path -Parent `$PSScriptRoot
`$GreetingPath = Join-Path `$ProjectRoot "src\greeting.txt"
`$Lines = Get-Content -LiteralPath `$GreetingPath

if (`$Lines -notcontains "message=`$ExpectedMessage") { throw "message mismatch" }
if (`$Lines -notcontains "phase=`$ExpectedPhase") { throw "phase mismatch" }

Write-Output "verify: OK"
Write-Output "message: `$ExpectedMessage"
Write-Output "phase: `$ExpectedPhase"
"@ | Set-Content -LiteralPath (Join-Path $ProjectRoot "tests\verify.ps1") -Encoding utf8

Invoke-NativeChecked -FilePath "git" -Arguments @("-C", $ProjectRoot, "init")
Invoke-NativeChecked -FilePath "git" -Arguments ($ProjectGitArgs + @("config", "user.name", "Loop E2E"))
Invoke-NativeChecked -FilePath "git" -Arguments ($ProjectGitArgs + @("config", "user.email", "loop-e2e@example.local"))
Invoke-NativeChecked -FilePath "git" -Arguments ($ProjectGitArgs + @("add", "README.md", "src/greeting.txt", "tests/verify.ps1"))
Invoke-NativeChecked -FilePath "git" -Arguments ($ProjectGitArgs + @("commit", "-m", "Initial e2e baseline"))

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $KitRoot "scripts\init-loop.ps1") -ProjectRoot $ProjectRoot | Out-Null
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $KitRoot "scripts\start-phase.ps1") `
    -ProjectRoot $ProjectRoot `
    -PhaseId "phase-001" `
    -Title "E2E pilot" `
    -Objective "Change the phase marker to worker-complete." `
    -Scope "src/greeting.txt" `
    -VerifyCommand "powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\verify.ps1 -ExpectedPhase worker-complete" | Out-Null

@"
message=hello
phase=worker-complete
"@ | Set-Content -LiteralPath (Join-Path $ProjectRoot "src\greeting.txt") -Encoding utf8

@"
# Worker Report: phase-001

## Summary

Changed ``phase=baseline`` to ``phase=worker-complete`` in ``src/greeting.txt``.

## Files Changed

- ``src/greeting.txt``

## Verification

The required verification command passed.

## Worker Boundary Statement

I executed only this phase and did not approve it.
"@ | Set-Content -LiteralPath (Join-Path $ProjectRoot ".ai-loop\runs\phase-001\report.md") -Encoding utf8

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $KitRoot "scripts\collect-evidence.ps1") -ProjectRoot $ProjectRoot -PhaseId "phase-001" | Out-Null
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $KitRoot "scripts\prepare-audit-pack.ps1") -ProjectRoot $ProjectRoot -PhaseId "phase-001" | Out-Null

$AuditPath = Join-Path $ProjectRoot ".ai-loop\audits\phase-001-audit.md"
@"
# Codex Audit: phase-001

## Evidence Checked

- report.md: checked
- diff.patch: checked
- verify.log: checked
- changed_business_files.txt: checked
- src/greeting.txt: checked

## Decision

Decision: ACCEPTED
"@ | Set-Content -LiteralPath $AuditPath -Encoding utf8

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $KitRoot "scripts\accept-phase.ps1") -ProjectRoot $ProjectRoot -PhaseId "phase-001" | Out-Null

$Status = Get-Content -LiteralPath (Join-Path $ProjectRoot ".ai-loop\status.json") -Raw | ConvertFrom-Json
if ($Status.current_phase.status -ne "accepted") {
    throw "E2E failed: current phase was not accepted."
}

$VerifyLog = Get-Content -LiteralPath (Join-Path $ProjectRoot ".ai-loop\runs\phase-001\verify.log") -Raw
if ($VerifyLog -notmatch "exit_code: 0") {
    throw "E2E failed: verify.log does not show exit_code: 0."
}

$BusinessFiles = Get-Content -LiteralPath (Join-Path $ProjectRoot ".ai-loop\runs\phase-001\changed_business_files.txt") -Raw
if ($BusinessFiles -notmatch "src/greeting.txt") {
    throw "E2E failed: changed_business_files.txt does not include src/greeting.txt."
}

Write-Output "pilot-loop-e2e: OK"
Write-Output "project: $ProjectRoot"

if (-not $KeepTemp) {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force
}

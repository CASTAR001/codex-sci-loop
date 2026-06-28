[CmdletBinding()]
param(
    [switch]$KeepTemp
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Add-Problem {
    param([Parameter(Mandatory = $true)][string]$Message)
    $script:Problems.Add($Message)
}

function Assert-UnderRoot {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Path
    )
    $ResolvedRoot = [System.IO.Path]::GetFullPath($Root)
    $ResolvedPath = [System.IO.Path]::GetFullPath($Path)
    if (-not $ResolvedPath.StartsWith($ResolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to operate outside test root: $ResolvedPath"
    }
}

function Invoke-AiLoop {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $PreviousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $Output = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $AiLoopScript @Arguments 2>&1)
    $ErrorActionPreference = $PreviousErrorActionPreference
    return [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Text = ($Output | Out-String)
    }
}

function Expect-Ok {
    param(
        [Parameter(Mandatory = $true)]$Result,
        [Parameter(Mandatory = $true)][string]$Label
    )
    if ($Result.ExitCode -ne 0) {
        Add-Problem "$Label failed with exit $($Result.ExitCode): $($Result.Text)"
    }
}

$KitRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = Split-Path -Parent $KitRoot
$AiLoopScript = Join-Path $PSScriptRoot "ai-loop.ps1"
. (Join-Path $PSScriptRoot "test-temp-root.ps1")
$TempRoot = New-LoopTestTempRoot -RepoRoot $RepoRoot -Name "external-worker-evidence"
$Problems = New-Object System.Collections.Generic.List[string]

Assert-UnderRoot -Root $RepoRoot -Path $TempRoot
if ((Test-Path -LiteralPath $TempRoot) -and -not $KeepTemp) {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $TempRoot | Out-Null

$ProjectRoot = Join-Path $TempRoot "project"
New-Item -ItemType Directory -Force -Path $ProjectRoot | Out-Null
"worker-evidence-fixture" | Set-Content -LiteralPath (Join-Path $ProjectRoot "README.md") -Encoding utf8
"Write-Output 'external worker evidence fixture: OK'; exit 0" |
    Set-Content -LiteralPath (Join-Path $ProjectRoot "verify.ps1") -Encoding utf8
& git -C $ProjectRoot init | Out-Null
& git -C $ProjectRoot -c user.email="loop@example.invalid" -c user.name="Loop Test" add README.md verify.ps1
& git -C $ProjectRoot -c user.email="loop@example.invalid" -c user.name="Loop Test" commit -m "Initial commit" | Out-Null
if ($LASTEXITCODE -ne 0) {
    Add-Problem "fixture git commit failed."
}

Expect-Ok -Result (Invoke-AiLoop -Arguments @("-Command", "init", "-ProjectRoot", $ProjectRoot)) -Label "init"
Expect-Ok -Result (Invoke-AiLoop -Arguments @(
    "-Command", "start",
    "-ProjectRoot", $ProjectRoot,
    "-PhaseId", "phase-001",
    "-TaskKind", "fullstack",
    "-Title", "External Worker evidence fixture",
    "-Objective", "Require local preflight and invocation evidence for external Worker use.",
    "-VerifyCommand", "powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\verify.ps1",
    "-WorkerProfile", "kimi-code",
    "-RequireExternalWorkerEvidence"
)) -Label "start"

$RunDir = Join-Path $ProjectRoot ".ai-loop\runs\phase-001"
"# Worker Report`n`nNo external service was called in this fixture; evidence files are tested locally." |
    Set-Content -LiteralPath (Join-Path $RunDir "report.md") -Encoding utf8

Expect-Ok -Result (Invoke-AiLoop -Arguments @("-Command", "collect", "-ProjectRoot", $ProjectRoot, "-PhaseId", "phase-001", "-Force")) -Label "collect missing worker evidence"
$MissingValidate = Invoke-AiLoop -Arguments @("-Command", "validate", "-ProjectRoot", $ProjectRoot, "-PhaseId", "phase-001")
if ($MissingValidate.ExitCode -eq 0) {
    Add-Problem "missing external Worker evidence should fail validation."
} elseif ($MissingValidate.Text -notmatch "external-worker-preflight" -or $MissingValidate.Text -notmatch "external-worker-invocation") {
    Add-Problem "missing external Worker evidence failed for unexpected reason: $($MissingValidate.Text)"
}

'{"decision":"SAFE_TO_INVOKE","fixture":true}' |
    Set-Content -LiteralPath (Join-Path $RunDir "external-worker-preflight.json") -Encoding utf8
"# External Worker Preflight`n`nDecision: SAFE_TO_INVOKE`nFixture only." |
    Set-Content -LiteralPath (Join-Path $RunDir "external-worker-preflight.md") -Encoding utf8
'{"exit_code":0,"dry_run":true,"fixture":true}' |
    Set-Content -LiteralPath (Join-Path $RunDir "external-worker-invocation.json") -Encoding utf8
"command: fixture external worker dry run`nexit_code: 0" |
    Set-Content -LiteralPath (Join-Path $RunDir "external-worker-invocation.log") -Encoding utf8

Expect-Ok -Result (Invoke-AiLoop -Arguments @("-Command", "collect", "-ProjectRoot", $ProjectRoot, "-PhaseId", "phase-001", "-Force")) -Label "collect complete worker evidence"
Expect-Ok -Result (Invoke-AiLoop -Arguments @("-Command", "validate", "-ProjectRoot", $ProjectRoot, "-PhaseId", "phase-001")) -Label "validate complete worker evidence"
Expect-Ok -Result (Invoke-AiLoop -Arguments @("-Command", "audit-pack", "-ProjectRoot", $ProjectRoot, "-PhaseId", "phase-001")) -Label "audit-pack complete worker evidence"

$Requirements = Get-Content -LiteralPath (Join-Path $RunDir "phase_requirements.json") -Raw | ConvertFrom-Json
if (-not [bool]$Requirements.require_external_worker_evidence) {
    Add-Problem "phase requirements should mark require_external_worker_evidence=true."
}
if (@($Requirements.required_worker_evidence).Count -ne 4) {
    Add-Problem "phase requirements should declare four required_worker_evidence entries."
}

$Manifest = Get-Content -LiteralPath (Join-Path $ProjectRoot ".ai-loop\evidence\artifact-manifest.json") -Raw | ConvertFrom-Json
$WorkerRecords = @($Manifest.artifacts | Where-Object { $_.phase -eq "phase-001" -and $_.type -eq "external-worker-evidence" })
if ($WorkerRecords.Count -ne 4) {
    Add-Problem "expected four external-worker-evidence manifest rows, found $($WorkerRecords.Count)."
} elseif (@($WorkerRecords | Where-Object { $_.status -ne "recorded" -or [string]::IsNullOrWhiteSpace([string]$_.sha256) }).Count -gt 0) {
    Add-Problem "external-worker-evidence manifest rows should be recorded with sha256."
}

$AuditInput = Get-Content -LiteralPath (Join-Path $ProjectRoot ".ai-loop\audits\phase-001-audit-input.md") -Raw
foreach ($Needle in @(
    "## External Worker Evidence Requirements",
    "external-worker-preflight.json",
    "external-worker-invocation.log",
    "Artifact Integrity Summary"
)) {
    if ($AuditInput -notmatch [regex]::Escape($Needle)) {
        Add-Problem "audit input missing expected text: $Needle"
    }
}

if ($Problems.Count -gt 0) {
    Write-Output "External Worker evidence test: FAILED"
    foreach ($Problem in $Problems) {
        Write-Output "- $Problem"
    }
    exit 2
}

Write-Output "External Worker evidence test: OK"
Write-Output "Fixture root: $TempRoot"
Write-Output "Cases checked: missing external Worker evidence blocks; complete local evidence validates and appears in manifest/audit pack"

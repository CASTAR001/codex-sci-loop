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

function Invoke-ValidateLoop {
    param([Parameter(Mandatory = $true)][string]$ProjectRoot)
    $PreviousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $Output = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ValidateLoopScript -ProjectRoot $ProjectRoot 2>&1)
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
$ValidateLoopScript = Join-Path $PSScriptRoot "validate-loop.ps1"
. (Join-Path $PSScriptRoot "test-temp-root.ps1")
$TempRoot = New-LoopTestTempRoot -RepoRoot $RepoRoot -Name "state-transitions"
$ProjectRoot = Join-Path $TempRoot "project"
$Problems = New-Object System.Collections.Generic.List[string]

Assert-UnderRoot -Root $RepoRoot -Path $TempRoot
if ((Test-Path -LiteralPath $TempRoot) -and -not $KeepTemp) {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $ProjectRoot | Out-Null

"transition smoke" | Set-Content -LiteralPath (Join-Path $ProjectRoot "README.md") -Encoding utf8
& git -C $ProjectRoot init | Out-Null
& git -C $ProjectRoot -c user.email="loop@example.invalid" -c user.name="Loop Test" add README.md
& git -C $ProjectRoot -c user.email="loop@example.invalid" -c user.name="Loop Test" commit -m "Initial commit" | Out-Null
if ($LASTEXITCODE -ne 0) {
    Add-Problem "git commit failed for transition fixture."
}

Expect-Ok -Result (Invoke-AiLoop -Arguments @("-Command", "init", "-ProjectRoot", $ProjectRoot)) -Label "init"
$StartResult = Invoke-AiLoop -Arguments @(
    "-Command", "start",
    "-ProjectRoot", $ProjectRoot,
    "-PhaseId", "phase-001",
    "-TaskKind", "fullstack",
    "-Title", "State transition smoke",
    "-Objective", "Exercise transition logging.",
    "-VerifyCommand", "powershell.exe -NoProfile -Command Write-Output transition-ok"
)
Expect-Ok -Result $StartResult -Label "start"
if ($StartResult.ExitCode -ne 0) {
    Write-Output "State transition test: FAILED"
    foreach ($Problem in $Problems) {
        Write-Output "- $Problem"
    }
    exit 2
}

$ReportPath = Join-Path $ProjectRoot ".ai-loop\runs\phase-001\report.md"
"# Worker Report`n`nNo business changes; transition smoke only." | Set-Content -LiteralPath $ReportPath -Encoding utf8

Expect-Ok -Result (Invoke-AiLoop -Arguments @("-Command", "collect", "-ProjectRoot", $ProjectRoot, "-PhaseId", "phase-001")) -Label "collect"
Expect-Ok -Result (Invoke-AiLoop -Arguments @("-Command", "audit-pack", "-ProjectRoot", $ProjectRoot, "-PhaseId", "phase-001")) -Label "audit-pack"

$AuditPath = Join-Path $ProjectRoot ".ai-loop\audits\phase-001-audit.md"
"# Audit`n`nDecision: ACCEPTED`n" | Set-Content -LiteralPath $AuditPath -Encoding utf8
Expect-Ok -Result (Invoke-AiLoop -Arguments @("-Command", "accept", "-ProjectRoot", $ProjectRoot, "-PhaseId", "phase-001")) -Label "accept"

$TransitionLog = Join-Path $ProjectRoot ".ai-loop\events\state-transitions.ndjson"
if (-not (Test-Path -LiteralPath $TransitionLog -PathType Leaf)) {
    Add-Problem "state transition log missing."
} else {
    $Transitions = @(Get-Content -LiteralPath $TransitionLog | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_ | ConvertFrom-Json })
    $PhaseTransitions = @($Transitions | Where-Object { $_.phase_id -eq "phase-001" })
    foreach ($ExpectedStatus in @("started", "evidence_collected", "audit_ready", "accepted")) {
        if (@($PhaseTransitions | Where-Object { $_.to_status -eq $ExpectedStatus }).Count -eq 0) {
            Add-Problem "state transition log missing to_status=$ExpectedStatus."
        }
    }
    $Latest = $PhaseTransitions | Select-Object -Last 1
    if ([string]$Latest.to_status -ne "accepted") {
        Add-Problem "latest state transition should be accepted, got $($Latest.to_status)."
    }
}

$ValidateResult = Invoke-ValidateLoop -ProjectRoot $ProjectRoot
if ($ValidateResult.ExitCode -ne 0) {
    Add-Problem "validate-loop should pass before transition tamper: $($ValidateResult.Text)"
}

$Lines = @(Get-Content -LiteralPath $TransitionLog)
$Last = $Lines[-1] | ConvertFrom-Json
$Last.to_status = "audit_ready"
$Lines[-1] = ($Last | ConvertTo-Json -Depth 20 -Compress)
$Lines | Set-Content -LiteralPath $TransitionLog -Encoding utf8

$TamperedValidate = Invoke-ValidateLoop -ProjectRoot $ProjectRoot
if ($TamperedValidate.ExitCode -eq 0) {
    Add-Problem "validate-loop should fail after transition log tamper."
} elseif ($TamperedValidate.Text -notmatch "transition log latest status differs") {
    Add-Problem "transition tamper failed for wrong reason: $($TamperedValidate.Text)"
}

if ($Problems.Count -gt 0) {
    Write-Output "State transition test: FAILED"
    foreach ($Problem in $Problems) {
        Write-Output "- $Problem"
    }
    exit 2
}

Write-Output "State transition test: OK"
Write-Output "Fixture root: $TempRoot"
Write-Output "Cases checked: normal lifecycle, tampered latest transition"

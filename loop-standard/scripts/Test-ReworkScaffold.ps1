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

function New-FixtureProject {
    param([Parameter(Mandatory = $true)][string]$Name)
    $ProjectRoot = Join-Path $TempRoot $Name
    Assert-UnderRoot -Root $RepoRoot -Path $ProjectRoot
    New-Item -ItemType Directory -Force -Path $ProjectRoot | Out-Null
    "fixture=$Name" | Set-Content -LiteralPath (Join-Path $ProjectRoot "README.md") -Encoding utf8
    "Write-Output 'rework scaffold fixture: OK'; exit 0" | Set-Content -LiteralPath (Join-Path $ProjectRoot "verify.ps1") -Encoding utf8
    & git -C $ProjectRoot init | Out-Null
    & git -C $ProjectRoot -c user.email="loop@example.invalid" -c user.name="Loop Test" add README.md verify.ps1
    & git -C $ProjectRoot -c user.email="loop@example.invalid" -c user.name="Loop Test" commit -m "Initial commit" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Add-Problem "$Name git commit failed."
    }

    Expect-Ok -Result (Invoke-AiLoop -Arguments @("-Command", "init", "-ProjectRoot", $ProjectRoot)) -Label "$Name init"
    Expect-Ok -Result (Invoke-AiLoop -Arguments @(
        "-Command", "start",
        "-ProjectRoot", $ProjectRoot,
        "-PhaseId", "phase-001",
        "-TaskKind", "fullstack",
        "-Title", "$Name source phase",
        "-Objective", "Create a source phase for decision testing.",
        "-VerifyCommand", "powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\verify.ps1"
    )) -Label "$Name start"
    "# Worker Report`n`nSource phase report." | Set-Content -LiteralPath (Join-Path $ProjectRoot ".ai-loop\runs\phase-001\report.md") -Encoding utf8
    "fixture=$Name`nchanged=true" | Set-Content -LiteralPath (Join-Path $ProjectRoot "README.md") -Encoding utf8
    Expect-Ok -Result (Invoke-AiLoop -Arguments @("-Command", "collect", "-ProjectRoot", $ProjectRoot, "-PhaseId", "phase-001", "-Force")) -Label "$Name collect"
    Expect-Ok -Result (Invoke-AiLoop -Arguments @("-Command", "audit-pack", "-ProjectRoot", $ProjectRoot, "-PhaseId", "phase-001")) -Label "$Name audit-pack"
    return $ProjectRoot
}

$KitRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = Split-Path -Parent $KitRoot
$AiLoopScript = Join-Path $PSScriptRoot "ai-loop.ps1"
$ValidateLoopScript = Join-Path $PSScriptRoot "validate-loop.ps1"
. (Join-Path $PSScriptRoot "test-temp-root.ps1")
$TempRoot = New-LoopTestTempRoot -RepoRoot $RepoRoot -Name "rework-scaffold"
$Problems = New-Object System.Collections.Generic.List[string]

Assert-UnderRoot -Root $RepoRoot -Path $TempRoot
if ((Test-Path -LiteralPath $TempRoot) -and -not $KeepTemp) {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $TempRoot | Out-Null

$ReworkProject = New-FixtureProject -Name "rework-project"
$ReworkAudit = Join-Path $ReworkProject ".ai-loop\audits\phase-001-audit.md"
@(
    "# Audit"
    ""
    "Decision: REWORK"
    ""
    "Finding: README needs a narrower correction."
    "Required fix: change only README.md and preserve verification."
) | Set-Content -LiteralPath $ReworkAudit -Encoding utf8
Expect-Ok -Result (Invoke-AiLoop -Arguments @(
    "-Command", "decide",
    "-ProjectRoot", $ReworkProject,
    "-PhaseId", "phase-001",
    "-Decision", "REWORK",
    "-Reason", "README needs a narrower correction."
)) -Label "rework decide"
Expect-Ok -Result (Invoke-AiLoop -Arguments @(
    "-Command", "scaffold-rework",
    "-ProjectRoot", $ReworkProject,
    "-PhaseId", "phase-001",
    "-ReworkPhaseId", "phase-002"
)) -Label "scaffold rework"

$ReworkSourcePath = Join-Path $ReworkProject ".ai-loop\runs\phase-002\rework_source.json"
$PromptPath = Join-Path $ReworkProject ".ai-loop\runs\phase-002\prompt.md"
$PhaseMetaPath = Join-Path $ReworkProject ".ai-loop\runs\phase-002\phase_meta.json"
$StatusPath = Join-Path $ReworkProject ".ai-loop\status.json"
foreach ($Path in @($ReworkSourcePath, $PromptPath, $PhaseMetaPath, $StatusPath)) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Add-Problem "expected scaffold output missing: $Path"
    }
}
if (Test-Path -LiteralPath $ReworkSourcePath -PathType Leaf) {
    $ReworkSource = Get-Content -LiteralPath $ReworkSourcePath -Raw | ConvertFrom-Json
    if ([string]$ReworkSource.source_phase_id -ne "phase-001") {
        Add-Problem "rework_source.json has wrong source_phase_id: $($ReworkSource.source_phase_id)"
    }
    if ([string]$ReworkSource.scaffolded_phase_id -ne "phase-002") {
        Add-Problem "rework_source.json has wrong scaffolded_phase_id: $($ReworkSource.scaffolded_phase_id)"
    }
}
if (Test-Path -LiteralPath $PromptPath -PathType Leaf) {
    $PromptText = Get-Content -LiteralPath $PromptPath -Raw
    foreach ($Needle in @("REWORK follow-up for source phase", "Do not broaden beyond the audit findings", "README needs a narrower correction", ".ai-loop/audits/phase-001-audit.md")) {
        if ($PromptText -notmatch [regex]::Escape($Needle)) {
            Add-Problem "rework prompt missing expected text: $Needle"
        }
    }
}
if (Test-Path -LiteralPath $StatusPath -PathType Leaf) {
    $Status = Get-Content -LiteralPath $StatusPath -Raw | ConvertFrom-Json
    if ([string]$Status.current_phase.phase_id -ne "phase-002") {
        Add-Problem "current phase should be phase-002 after scaffold, got $($Status.current_phase.phase_id)"
    }
    $SourcePhase = @($Status.phases | Where-Object { $_.phase_id -eq "phase-001" })[0]
    if ([string]$SourcePhase.status -ne "rework") {
        Add-Problem "source phase should remain rework, got $($SourcePhase.status)"
    }
}
$TransitionLog = Join-Path $ReworkProject ".ai-loop\events\state-transitions.ndjson"
if (Test-Path -LiteralPath $TransitionLog -PathType Leaf) {
    $Phase2Transitions = @(Get-Content -LiteralPath $TransitionLog | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_ | ConvertFrom-Json } | Where-Object { $_.phase_id -eq "phase-002" })
    if ($Phase2Transitions.Count -eq 0 -or [string]($Phase2Transitions | Select-Object -Last 1).to_status -ne "started") {
        Add-Problem "phase-002 should have latest transition to started."
    }
}
Expect-Ok -Result (Invoke-AiLoop -Arguments @("-Command", "validate-loop", "-ProjectRoot", $ReworkProject)) -Label "rework validate-loop"

$BlockedProject = New-FixtureProject -Name "blocked-project"
$BlockedAudit = Join-Path $BlockedProject ".ai-loop\audits\phase-001-audit.md"
"# Audit`n`nDecision: BLOCKED`n`nReason: unavailable dependency." | Set-Content -LiteralPath $BlockedAudit -Encoding utf8
Expect-Ok -Result (Invoke-AiLoop -Arguments @("-Command", "decide", "-ProjectRoot", $BlockedProject, "-PhaseId", "phase-001", "-Decision", "BLOCKED", "-Reason", "unavailable dependency")) -Label "blocked decide"
$BlockedScaffold = Invoke-AiLoop -Arguments @("-Command", "scaffold-rework", "-ProjectRoot", $BlockedProject, "-PhaseId", "phase-001", "-ReworkPhaseId", "phase-002")
if ($BlockedScaffold.ExitCode -eq 0) {
    Add-Problem "scaffold-rework should fail for BLOCKED source phase."
} elseif ($BlockedScaffold.Text -notmatch "not 'rework'") {
    Add-Problem "blocked scaffold failed for unexpected reason: $($BlockedScaffold.Text)"
}

if ($Problems.Count -gt 0) {
    Write-Output "Rework scaffold test: FAILED"
    foreach ($Problem in $Problems) {
        Write-Output "- $Problem"
    }
    exit 2
}

Write-Output "Rework scaffold test: OK"
Write-Output "Fixture root: $TempRoot"
Write-Output "Cases checked: REWORK scaffold, BLOCKED refusal"

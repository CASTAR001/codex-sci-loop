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

function Invoke-Required {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][scriptblock]$Action
    )
    $Output = @(& $Action 2>&1)
    if ($LASTEXITCODE -ne 0) {
        Add-Problem "$Label failed with exit $LASTEXITCODE`: $($Output | Out-String)"
    }
    return ($Output | Out-String)
}

function New-FixtureProject {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$PhaseId
    )
    $Project = Join-Path $TempRoot $Name
    Assert-UnderRoot -Root $RepoRoot -Path $Project
    New-Item -ItemType Directory -Force -Path $Project | Out-Null
    Push-Location $Project
    try {
        git init | Out-Null
        Set-Content -LiteralPath "README.md" -Encoding utf8 -Value "# $Name"
        Set-Content -LiteralPath "verify.ps1" -Encoding utf8 -Value "Write-Output 'decision fixture: OK'`nexit 0"
        git add README.md verify.ps1 | Out-Null
        git commit -m "Initial fixture" | Out-Null
    } finally {
        Pop-Location
    }

    Invoke-Required -Label "$Name init" -Action {
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File $AiLoopScript -Command init -ProjectRoot $Project
    } | Out-Null
    Invoke-Required -Label "$Name start" -Action {
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File $AiLoopScript -Command start -ProjectRoot $Project -PhaseId $PhaseId -TaskKind fullstack -Title "$Name decision fixture" -Objective "Exercise durable non-accepted decision state." -VerifyCommand "& .\verify.ps1"
    } | Out-Null

    Set-Content -LiteralPath (Join-Path $Project ".ai-loop\runs\$PhaseId\report.md") -Encoding utf8 -Value "# Worker Report`n`nDecision fixture report."
    Set-Content -LiteralPath (Join-Path $Project "README.md") -Encoding utf8 -Value "# $Name`n`nphase=$PhaseId"

    Invoke-Required -Label "$Name collect" -Action {
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File $AiLoopScript -Command collect -ProjectRoot $Project -PhaseId $PhaseId -Force
    } | Out-Null
    Invoke-Required -Label "$Name audit-pack" -Action {
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File $AiLoopScript -Command audit-pack -ProjectRoot $Project -PhaseId $PhaseId
    } | Out-Null
    return $Project
}

function Assert-DecisionState {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [Parameter(Mandatory = $true)][string]$PhaseId,
        [Parameter(Mandatory = $true)]
        [ValidateSet("REWORK", "BLOCKED")]
        [string]$Decision
    )
    $DecisionLower = $Decision.ToLowerInvariant()
    $DecisionFile = if ($Decision -eq "REWORK") { "rework.txt" } else { "blocked.txt" }
    $StatusPath = Join-Path $ProjectRoot ".ai-loop\status.json"
    $MetaPath = Join-Path $ProjectRoot ".ai-loop\runs\$PhaseId\phase_meta.json"
    $EventLog = Join-Path $ProjectRoot ".ai-loop\events\event-log.ndjson"
    $Status = Get-Content -LiteralPath $StatusPath -Raw | ConvertFrom-Json
    $Meta = Get-Content -LiteralPath $MetaPath -Raw | ConvertFrom-Json
    if ([string]$Status.current_phase.status -ne $DecisionLower) {
        Add-Problem "$PhaseId current_phase status should be $DecisionLower, got $($Status.current_phase.status)"
    }
    if ([string]$Meta.status -ne $DecisionLower) {
        Add-Problem "$PhaseId metadata status should be $DecisionLower, got $($Meta.status)"
    }
    if ([string]$Status.last_decision.decision -ne $Decision) {
        Add-Problem "$PhaseId last_decision should be $Decision, got $($Status.last_decision.decision)"
    }
    if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot ".ai-loop\runs\$PhaseId\$DecisionFile") -PathType Leaf)) {
        Add-Problem "$PhaseId missing $DecisionFile"
    }
    $EventText = if (Test-Path -LiteralPath $EventLog -PathType Leaf) { Get-Content -LiteralPath $EventLog -Raw } else { "" }
    if ($EventText -notmatch '"type":"phase_decision"' -or $EventText -notmatch $Decision) {
        Add-Problem "$PhaseId event log missing phase_decision for $Decision"
    }
    Invoke-Required -Label "$PhaseId validate-loop" -Action {
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ValidateLoopScript -ProjectRoot $ProjectRoot
    } | Out-Null
    $Resume = Invoke-Required -Label "$PhaseId resume" -Action {
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File $AiLoopScript -Command resume -ProjectRoot $ProjectRoot
    }
    if ($Resume -notmatch "Phase status: $DecisionLower") {
        Add-Problem "$PhaseId resume output did not show status $DecisionLower"
    }
    if ($Decision -eq "REWORK" -and $Resume -notmatch "Start a rework phase") {
        Add-Problem "$PhaseId resume output did not include rework next action"
    }
    if ($Decision -eq "BLOCKED" -and $Resume -notmatch "Resolve the blocker") {
        Add-Problem "$PhaseId resume output did not include blocked next action"
    }
}

$KitRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = Split-Path -Parent $KitRoot
$AiLoopScript = Join-Path $PSScriptRoot "ai-loop.ps1"
$ValidateLoopScript = Join-Path $PSScriptRoot "validate-loop.ps1"
. (Join-Path $PSScriptRoot "test-temp-root.ps1")
$TempRoot = New-LoopTestTempRoot -RepoRoot $RepoRoot -Name "phase-decisions"
$Problems = New-Object System.Collections.Generic.List[string]

Assert-UnderRoot -Root $RepoRoot -Path $TempRoot
if ((Test-Path -LiteralPath $TempRoot) -and -not $KeepTemp) {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $TempRoot | Out-Null

$ReworkProject = New-FixtureProject -Name "rework-fixture" -PhaseId "phase-001"
$ReworkAudit = Join-Path $ReworkProject ".ai-loop\audits\phase-001-audit.md"
Set-Content -LiteralPath $ReworkAudit -Encoding utf8 -Value "# Audit`n`nDecision: REWORK`n`nReason: fixture needs another bounded phase."
Invoke-Required -Label "rework decide" -Action {
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File $AiLoopScript -Command decide -ProjectRoot $ReworkProject -PhaseId phase-001 -Decision REWORK -Reason "fixture needs another bounded phase"
} | Out-Null
Assert-DecisionState -ProjectRoot $ReworkProject -PhaseId "phase-001" -Decision "REWORK"

$BlockedProject = New-FixtureProject -Name "blocked-fixture" -PhaseId "phase-001"
$BlockedAudit = Join-Path $BlockedProject ".ai-loop\audits\phase-001-audit.md"
Set-Content -LiteralPath $BlockedAudit -Encoding utf8 -Value "# Audit`n`nDecision: BLOCKED`n`nReason: fixture external dependency unavailable."
Invoke-Required -Label "blocked decide" -Action {
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File $AiLoopScript -Command decide -ProjectRoot $BlockedProject -PhaseId phase-001 -Decision BLOCKED -Reason "fixture external dependency unavailable"
} | Out-Null
Assert-DecisionState -ProjectRoot $BlockedProject -PhaseId "phase-001" -Decision "BLOCKED"

$MismatchProject = New-FixtureProject -Name "mismatch-fixture" -PhaseId "phase-001"
$MismatchAudit = Join-Path $MismatchProject ".ai-loop\audits\phase-001-audit.md"
Set-Content -LiteralPath $MismatchAudit -Encoding utf8 -Value "# Audit`n`nDecision: ACCEPTED`n"
$PreviousErrorActionPreference = $ErrorActionPreference
try {
    $ErrorActionPreference = "Continue"
    $MismatchOutput = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $AiLoopScript -Command decide -ProjectRoot $MismatchProject -PhaseId phase-001 -Decision REWORK 2>&1)
} finally {
    $ErrorActionPreference = $PreviousErrorActionPreference
}
if ($LASTEXITCODE -eq 0) {
    Add-Problem "decision mismatch should fail but exited 0"
} elseif (($MismatchOutput | Out-String) -notmatch "does not contain 'Decision: REWORK'") {
    Add-Problem "decision mismatch failed for unexpected reason: $($MismatchOutput | Out-String)"
}

if ($Problems.Count -gt 0) {
    Write-Output "Phase decision test: FAILED"
    foreach ($Problem in $Problems) {
        Write-Output "- $Problem"
    }
    exit 2
}

Write-Output "Phase decision test: OK"
Write-Output "Fixture root: $TempRoot"
Write-Output "Cases checked: REWORK, BLOCKED, decision mismatch"

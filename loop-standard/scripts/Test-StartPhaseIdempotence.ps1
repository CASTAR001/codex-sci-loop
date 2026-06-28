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

function Count-PhaseRows {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Phase
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return 0 }
    return @(
        Get-Content -LiteralPath $Path |
            Where-Object { $_ -like "*| $Phase |*" }
    ).Count
}

$KitRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = Split-Path -Parent $KitRoot
$AiLoopScript = Join-Path $PSScriptRoot "ai-loop.ps1"
. (Join-Path $PSScriptRoot "test-temp-root.ps1")
$TempRoot = New-LoopTestTempRoot -RepoRoot $RepoRoot -Name "start-idempotence"
$Problems = New-Object System.Collections.Generic.List[string]

if ((Test-Path -LiteralPath $TempRoot) -and -not $KeepTemp) {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $TempRoot | Out-Null

Push-Location $TempRoot
try {
    git init | Out-Null
    Set-Content -LiteralPath "README.md" -Encoding utf8 -Value "# Start idempotence fixture"
    Set-Content -LiteralPath "verify.ps1" -Encoding utf8 -Value "Write-Output 'start idempotence: OK'`nexit 0"
    git add README.md verify.ps1 | Out-Null
    git commit -m "Initial fixture" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Add-Problem "fixture git commit failed."
    }
} finally {
    Pop-Location
}

Expect-Ok -Result (Invoke-AiLoop -Arguments @("-Command", "init", "-ProjectRoot", $TempRoot)) -Label "init"
Expect-Ok -Result (Invoke-AiLoop -Arguments @(
    "-Command", "start",
    "-ProjectRoot", $TempRoot,
    "-PhaseId", "phase-001",
    "-TaskKind", "physics-research",
    "-Title", "First start",
    "-Objective", "First objective",
    "-VerifyCommand", "powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\verify.ps1"
)) -Label "start-1"
Expect-Ok -Result (Invoke-AiLoop -Arguments @(
    "-Command", "start",
    "-ProjectRoot", $TempRoot,
    "-PhaseId", "phase-001",
    "-TaskKind", "physics-research",
    "-Title", "Forced restart",
    "-Objective", "Second objective",
    "-VerifyCommand", "powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\verify.ps1",
    "-Force"
)) -Label "start-2-force"

$StatusPath = Join-Path $TempRoot ".ai-loop\status.json"
$Status = Get-Content -LiteralPath $StatusPath -Raw | ConvertFrom-Json
$PhaseEntries = @($Status.phases | Where-Object {
        $null -ne $_ -and
        $null -ne $_.PSObject.Properties["phase_id"] -and
        [string]$_.phase_id -eq "phase-001"
    })
if ($PhaseEntries.Count -ne 1) {
    Add-Problem "status.json should contain exactly one phase-001 entry after forced restart; found $($PhaseEntries.Count)"
}
if ($null -eq $Status.current_phase -or
    $null -eq $Status.current_phase.PSObject.Properties["phase_id"] -or
    $Status.current_phase.phase_id -ne "phase-001" -or
    $Status.current_phase.title -ne "Forced restart") {
    Add-Problem "current_phase should point to the refreshed phase metadata."
}

$EvidenceLedger = Join-Path $TempRoot ".ai-loop\evidence\evidence-ledger.md"
$ArtifactIndex = Join-Path $TempRoot ".ai-loop\evidence\artifact-index.md"
$SkillUsageLedger = Join-Path $TempRoot ".ai-loop\skills\skill-usage-ledger.md"
foreach ($Check in @(
    @{ Path = $EvidenceLedger; Expected = 2; Name = "evidence ledger" },
    @{ Path = $ArtifactIndex; Expected = 2; Name = "artifact index" },
    @{ Path = $SkillUsageLedger; Expected = 2; Name = "skill usage ledger" }
)) {
    $Count = Count-PhaseRows -Path $Check.Path -Phase "phase-001"
    if ($Count -ne $Check.Expected) {
        Add-Problem "$($Check.Name) should contain $($Check.Expected) phase rows after forced restart; found $Count"
    }
}

$PromptText = Get-Content -LiteralPath (Join-Path $TempRoot ".ai-loop\runs\phase-001\prompt.md") -Raw
if ($PromptText -notmatch "Forced restart" -or $PromptText -notmatch "Second objective") {
    Add-Problem "prompt.md should be refreshed by forced restart."
}

Expect-Ok -Result (Invoke-AiLoop -Arguments @("-Command", "validate-loop", "-ProjectRoot", $TempRoot)) -Label "validate-loop"

if ($Problems.Count -gt 0) {
    Write-Output "Start phase idempotence test: FAILED"
    foreach ($Problem in $Problems) {
        Write-Output "- $Problem"
    }
    Write-Output "Fixture root: $TempRoot"
    exit 2
}

Write-Output "Start phase idempotence test: OK"
Write-Output "Fixture root: $TempRoot"
Write-Output "Cases checked: forced restart refreshes status, prompt, evidence rows, artifact rows, and skill usage rows"

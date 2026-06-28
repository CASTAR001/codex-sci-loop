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
    "Write-Output 'skill artifact fixture: OK'; exit 0" | Set-Content -LiteralPath (Join-Path $ProjectRoot "verify.ps1") -Encoding utf8
    & git -C $ProjectRoot init | Out-Null
    & git -C $ProjectRoot -c user.email="loop@example.invalid" -c user.name="Loop Test" add README.md verify.ps1
    & git -C $ProjectRoot -c user.email="loop@example.invalid" -c user.name="Loop Test" commit -m "Initial commit" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Add-Problem "$Name git commit failed."
    }

    Expect-Ok -Result (Invoke-AiLoop -Arguments @("-Command", "init", "-ProjectRoot", $ProjectRoot)) -Label "$Name init"
    $SkillDir = Join-Path $ProjectRoot ".agents\skills\skill-compliance-audit"
    New-Item -ItemType Directory -Force -Path $SkillDir | Out-Null
    "# skill-compliance-audit fixture" | Set-Content -LiteralPath (Join-Path $SkillDir "SKILL.md") -Encoding utf8
    $SkillSourceMap = Join-Path $ProjectRoot ".ai-loop\skills\skill-source-map.md"
    Add-Content -LiteralPath $SkillSourceMap -Encoding utf8 -Value "| skill-compliance-audit | fixture | local | n/a | available | test fixture |"

    Expect-Ok -Result (Invoke-AiLoop -Arguments @(
        "-Command", "start",
        "-ProjectRoot", $ProjectRoot,
        "-PhaseId", "phase-001",
        "-TaskKind", "fullstack",
        "-Title", "$Name skill artifact phase",
        "-Objective", "Exercise required skill artifact manifest recording.",
        "-VerifyCommand", "powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\verify.ps1",
        "-Skills", "skill-compliance-audit"
    )) -Label "$Name start"
    "# Worker Report`n`nSkill artifact fixture." | Set-Content -LiteralPath (Join-Path $ProjectRoot ".ai-loop\runs\phase-001\report.md") -Encoding utf8
    return $ProjectRoot
}

$KitRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = Split-Path -Parent $KitRoot
$AiLoopScript = Join-Path $PSScriptRoot "ai-loop.ps1"
. (Join-Path $PSScriptRoot "test-temp-root.ps1")
$TempRoot = New-LoopTestTempRoot -RepoRoot $RepoRoot -Name "skill-artifact-manifest"
$Problems = New-Object System.Collections.Generic.List[string]

Assert-UnderRoot -Root $RepoRoot -Path $TempRoot
if ((Test-Path -LiteralPath $TempRoot) -and -not $KeepTemp) {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $TempRoot | Out-Null

$CompleteProject = New-FixtureProject -Name "complete-artifact"
$CompleteArtifact = Join-Path $CompleteProject "audits\skill-compliance-audit-report.md"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $CompleteArtifact) | Out-Null
"# Skill Compliance Audit`n`nstatus=complete" | Set-Content -LiteralPath $CompleteArtifact -Encoding utf8
Expect-Ok -Result (Invoke-AiLoop -Arguments @("-Command", "collect", "-ProjectRoot", $CompleteProject, "-PhaseId", "phase-001", "-Force")) -Label "complete collect"
Expect-Ok -Result (Invoke-AiLoop -Arguments @("-Command", "validate", "-ProjectRoot", $CompleteProject, "-PhaseId", "phase-001")) -Label "complete validate"

$ManifestPath = Join-Path $CompleteProject ".ai-loop\evidence\artifact-manifest.json"
$Manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$SkillRecord = @($Manifest.artifacts | Where-Object { $_.phase -eq "phase-001" -and $_.type -eq "skill-artifact" -and $_.path -eq "audits/skill-compliance-audit-report.md" })
if ($SkillRecord.Count -ne 1) {
    Add-Problem "expected one skill-artifact manifest row, found $($SkillRecord.Count)"
} elseif ([string]$SkillRecord[0].status -ne "recorded" -or [string]::IsNullOrWhiteSpace([string]$SkillRecord[0].sha256)) {
    Add-Problem "skill-artifact manifest row should be recorded with sha256."
}

Add-Content -LiteralPath $CompleteArtifact -Encoding utf8 -Value "`nmutation after collect"
$TamperedValidate = Invoke-AiLoop -Arguments @("-Command", "validate", "-ProjectRoot", $CompleteProject, "-PhaseId", "phase-001")
if ($TamperedValidate.ExitCode -eq 0) {
    Add-Problem "tampered skill artifact should fail validation."
} elseif ($TamperedValidate.Text -notmatch "artifact hash mismatch") {
    Add-Problem "tampered skill artifact failed for unexpected reason: $($TamperedValidate.Text)"
}

$MissingProject = New-FixtureProject -Name "missing-artifact"
Expect-Ok -Result (Invoke-AiLoop -Arguments @("-Command", "collect", "-ProjectRoot", $MissingProject, "-PhaseId", "phase-001", "-Force")) -Label "missing collect"
$MissingValidate = Invoke-AiLoop -Arguments @("-Command", "validate", "-ProjectRoot", $MissingProject, "-PhaseId", "phase-001")
if ($MissingValidate.ExitCode -eq 0) {
    Add-Problem "missing skill artifact should fail validation."
} elseif ($MissingValidate.Text -notmatch "required skill artifact") {
    Add-Problem "missing skill artifact failed for unexpected reason: $($MissingValidate.Text)"
}
$MissingManifest = Get-Content -LiteralPath (Join-Path $MissingProject ".ai-loop\evidence\artifact-manifest.json") -Raw | ConvertFrom-Json
$MissingRecord = @($MissingManifest.artifacts | Where-Object { $_.phase -eq "phase-001" -and $_.type -eq "skill-artifact" -and $_.path -eq "audits/skill-compliance-audit-report.md" })
if ($MissingRecord.Count -ne 1 -or [string]$MissingRecord[0].status -ne "missing") {
    Add-Problem "missing skill artifact should be recorded in manifest as missing."
}

if ($Problems.Count -gt 0) {
    Write-Output "Skill artifact manifest test: FAILED"
    foreach ($Problem in $Problems) {
        Write-Output "- $Problem"
    }
    exit 2
}

Write-Output "Skill artifact manifest test: OK"
Write-Output "Fixture root: $TempRoot"
Write-Output "Cases checked: recorded skill artifact, tampered hash, missing artifact"

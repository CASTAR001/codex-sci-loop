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

function Save-Json {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Path
    )
    $Object | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $Path -Encoding utf8
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

function New-InitializedProject {
    param([Parameter(Mandatory = $true)][string]$Name)
    $ProjectRoot = Join-Path $TempRoot $Name
    Assert-UnderRoot -Root $RepoRoot -Path $ProjectRoot
    New-Item -ItemType Directory -Force -Path $ProjectRoot | Out-Null
    $InitResult = Invoke-AiLoop -Arguments @("-Command", "init", "-ProjectRoot", $ProjectRoot)
    if ($InitResult.ExitCode -ne 0) {
        Add-Problem "$Name init failed with exit $($InitResult.ExitCode): $($InitResult.Text)"
    }
    return $ProjectRoot
}

function Get-LatestMigrationRecord {
    param([Parameter(Mandatory = $true)][string]$ProjectRoot)
    $RecordsRoot = Join-Path $ProjectRoot ".ai-loop\schema\migration-records"
    if (-not (Test-Path -LiteralPath $RecordsRoot -PathType Container)) { return $null }
    return Get-ChildItem -LiteralPath $RecordsRoot -Recurse -Filter "migration-record.json" |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1
}

$KitRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = Split-Path -Parent $KitRoot
$AiLoopScript = Join-Path $PSScriptRoot "ai-loop.ps1"
. (Join-Path $PSScriptRoot "test-temp-root.ps1")
$TempRoot = New-LoopTestTempRoot -RepoRoot $RepoRoot -Name "migrate-semantic"
$Problems = New-Object System.Collections.Generic.List[string]

Assert-UnderRoot -Root $RepoRoot -Path $TempRoot
if ((Test-Path -LiteralPath $TempRoot) -and -not $KeepTemp) {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $TempRoot | Out-Null

$LegacyProject = New-InitializedProject -Name "legacy-project"
$ConfigPath = Join-Path $LegacyProject ".ai-loop\loop.config.json"
$StatusPath = Join-Path $LegacyProject ".ai-loop\status.json"

$Config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$Config.schema_version = "1.2"
if ($null -ne $Config.PSObject.Properties["phase_evidence_required"]) {
    $Config.PSObject.Properties.Remove("phase_evidence_required")
}
$Config | Add-Member -NotePropertyName "required_evidence" -NotePropertyValue @("prompt.md", "report.md", "verify.log", "diff.patch")
Save-Json -Object $Config -Path $ConfigPath

$LegacyPhase = [pscustomobject][ordered]@{
    phase_id = "phase-legacy"
    title = "Legacy completed phase"
    objective = "Exercise semantic migration transforms"
    status = "completed"
    run_dir = ".ai-loop/runs/phase-legacy"
    audit_input = ".ai-loop/audits/phase-legacy-audit-input.md"
    audit_result = ".ai-loop/audits/phase-legacy-audit.md"
}
$Status = Get-Content -LiteralPath $StatusPath -Raw | ConvertFrom-Json
$Status.schema_version = "1.0"
$Status.current_phase = $null
$Status.phases = @($LegacyPhase)
$Status | Add-Member -NotePropertyName "current_phase_id" -NotePropertyValue "phase-legacy"
Save-Json -Object $Status -Path $StatusPath

$DryRun = Invoke-AiLoop -Arguments @("-Command", "migrate", "-ProjectRoot", $LegacyProject, "-DryRun", "-Json")
if ($DryRun.ExitCode -ne 0) {
    Add-Problem "semantic dry-run failed with exit $($DryRun.ExitCode): $($DryRun.Text)"
} else {
    try {
        $Plan = $DryRun.Text | ConvertFrom-Json
        $Ids = @($Plan.semantic_transforms)
        foreach ($ExpectedId in @("legacy-config-required-evidence", "legacy-status-current-phase-id", "legacy-phase-status-completed")) {
            if ($Ids -notcontains $ExpectedId) {
                Add-Problem "semantic dry-run missing transform id: $ExpectedId"
            }
        }
        $ActionsText = @($Plan.actions) -join "`n"
        if ($ActionsText -notmatch "semantic transform legacy-config-required-evidence") {
            Add-Problem "semantic dry-run did not report config transform."
        }
        if ($ActionsText -notmatch "semantic transform legacy-status-current-phase-id") {
            Add-Problem "semantic dry-run did not report current phase transform."
        }
        if ($ActionsText -notmatch "semantic transform legacy-phase-status-completed") {
            Add-Problem "semantic dry-run did not report status mapping transform."
        }
    } catch {
        Add-Problem "semantic dry-run did not emit parseable JSON: $($_.Exception.Message) :: $($DryRun.Text)"
    }
}

$ConfigAfterDryRun = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
if ($null -ne $ConfigAfterDryRun.PSObject.Properties["phase_evidence_required"]) {
    Add-Problem "semantic dry-run modified loop.config.json."
}
$StatusAfterDryRun = Get-Content -LiteralPath $StatusPath -Raw | ConvertFrom-Json
if ($null -ne $StatusAfterDryRun.current_phase) {
    Add-Problem "semantic dry-run modified status.json current_phase."
}
if ([string]$StatusAfterDryRun.phases[0].status -ne "completed") {
    Add-Problem "semantic dry-run modified phase status."
}

$Migrate = Invoke-AiLoop -Arguments @("-Command", "migrate", "-ProjectRoot", $LegacyProject)
if ($Migrate.ExitCode -ne 0) {
    Add-Problem "semantic migrate failed with exit $($Migrate.ExitCode): $($Migrate.Text)"
} else {
    $MigratedConfig = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
    if (@($MigratedConfig.phase_evidence_required) -notcontains "verify.log") {
        Add-Problem "semantic migrate did not copy required_evidence into phase_evidence_required."
    }
    if (@($MigratedConfig.required_evidence) -notcontains "verify.log") {
        Add-Problem "semantic migrate should preserve required_evidence source field."
    }

    $MigratedStatus = Get-Content -LiteralPath $StatusPath -Raw | ConvertFrom-Json
    if ($null -eq $MigratedStatus.current_phase -or [string]$MigratedStatus.current_phase.phase_id -ne "phase-legacy") {
        Add-Problem "semantic migrate did not hydrate current_phase from current_phase_id."
    }
    if ([string]$MigratedStatus.current_phase.status -ne "accepted") {
        Add-Problem "semantic migrate did not map current_phase status to accepted."
    }
    if ([string]$MigratedStatus.phases[0].status -ne "accepted") {
        Add-Problem "semantic migrate did not map phase status to accepted."
    }

    $RecordFile = Get-LatestMigrationRecord -ProjectRoot $LegacyProject
    if ($null -eq $RecordFile) {
        Add-Problem "semantic migrate did not write migration record."
    } else {
        $Record = Get-Content -LiteralPath $RecordFile.FullName -Raw | ConvertFrom-Json
        $RecordedIds = @($Record.semantic_transforms)
        foreach ($ExpectedId in @("legacy-config-required-evidence", "legacy-status-current-phase-id", "legacy-phase-status-completed")) {
            if ($RecordedIds -notcontains $ExpectedId) {
                Add-Problem "migration record missing semantic transform id: $ExpectedId"
            }
        }
    }
}

$CurrentProject = New-InitializedProject -Name "current-project"
$CurrentDryRun = Invoke-AiLoop -Arguments @("-Command", "migrate", "-ProjectRoot", $CurrentProject, "-DryRun", "-Json")
if ($CurrentDryRun.ExitCode -ne 0) {
    Add-Problem "current project dry-run failed with exit $($CurrentDryRun.ExitCode): $($CurrentDryRun.Text)"
} else {
    $CurrentPlan = $CurrentDryRun.Text | ConvertFrom-Json
    if (@($CurrentPlan.semantic_transforms).Count -ne 0) {
        Add-Problem "current project dry-run should not apply semantic transforms."
    }
}

if ($Problems.Count -gt 0) {
    Write-Output "Migrate semantic transforms test: FAILED"
    foreach ($Problem in $Problems) {
        Write-Output "- $Problem"
    }
    Write-Output "Fixture root: $TempRoot"
    exit 2
}

Write-Output "Migrate semantic transforms test: OK"
Write-Output "Fixture root: $TempRoot"
Write-Output "Cases checked: semantic dry-run, no-write dry-run, real migrate, no-op current project"

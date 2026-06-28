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

$KitRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = Split-Path -Parent $KitRoot
$AiLoopScript = Join-Path $PSScriptRoot "ai-loop.ps1"
$ValidateLoopScript = Join-Path $PSScriptRoot "validate-loop.ps1"
. (Join-Path $PSScriptRoot "test-temp-root.ps1")
$TempRoot = New-LoopTestTempRoot -RepoRoot $RepoRoot -Name "migrate-dry-run"
$Problems = New-Object System.Collections.Generic.List[string]

Assert-UnderRoot -Root $RepoRoot -Path $TempRoot
if ((Test-Path -LiteralPath $TempRoot) -and -not $KeepTemp) {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $TempRoot | Out-Null

$Project = New-InitializedProject -Name "old-project"
$ConfigPath = Join-Path $Project ".ai-loop\loop.config.json"
$StatusPath = Join-Path $Project ".ai-loop\status.json"
$SchemaDir = Join-Path $Project ".ai-loop\schema"
$SchemaPath = Join-Path $SchemaDir "schema-version.json"
$RemovedTemplateFile = Join-Path $Project ".ai-loop\workers\README.md"
$EventLogPath = Join-Path $Project ".ai-loop\events\event-log.ndjson"

$Config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$Config.schema_version = "1.1"
Save-Json -Object $Config -Path $ConfigPath

$Status = Get-Content -LiteralPath $StatusPath -Raw | ConvertFrom-Json
$Status.schema_version = "0.9"
Save-Json -Object $Status -Path $StatusPath

Remove-Item -LiteralPath $SchemaDir -Recurse -Force
if (Test-Path -LiteralPath $RemovedTemplateFile -PathType Leaf) {
    Remove-Item -LiteralPath $RemovedTemplateFile -Force
}
$EventBefore = if (Test-Path -LiteralPath $EventLogPath -PathType Leaf) {
    Get-Content -LiteralPath $EventLogPath -Raw
} else {
    ""
}

$BeforeValidate = Invoke-ValidateLoop -ProjectRoot $Project
if ($BeforeValidate.ExitCode -eq 0) {
    Add-Problem "old project should fail validate-loop before migration dry-run."
}

$DryRunJson = Invoke-AiLoop -Arguments @("-Command", "migrate", "-ProjectRoot", $Project, "-DryRun", "-Json")
if ($DryRunJson.ExitCode -ne 0) {
    Add-Problem "migrate -DryRun -Json failed with exit $($DryRunJson.ExitCode): $($DryRunJson.Text)"
} else {
    try {
        $Plan = $DryRunJson.Text | ConvertFrom-Json
        if ($Plan.mode -ne "dry-run") {
            Add-Problem "dry-run JSON mode was not dry-run: $($Plan.mode)"
        }
        if ([string]$Plan.from_schema_version -ne "1.1") {
            Add-Problem "dry-run JSON from_schema_version was wrong: $($Plan.from_schema_version)"
        }
        if ([string]$Plan.to_schema_version -ne "1.3") {
            Add-Problem "dry-run JSON to_schema_version was wrong: $($Plan.to_schema_version)"
        }
        $ActionsText = (@($Plan.actions) -join "`n")
        foreach ($Expected in @(
            "copied missing template file: .ai-loop/schema/schema-version.json",
            "copied missing template file: .ai-loop/workers/README.md",
            "updated loop.config.json schema_version to 1.3",
            "updated status.json schema_version to 1.1",
            "created migration-log.md from template"
        )) {
            if ($ActionsText -notmatch [regex]::Escape($Expected)) {
                Add-Problem "dry-run JSON missing expected action: $Expected"
            }
        }
    } catch {
        Add-Problem "migrate -DryRun -Json did not emit parseable JSON: $($_.Exception.Message) :: $($DryRunJson.Text)"
    }
}

$ConfigAfterDryRun = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
if ([string]$ConfigAfterDryRun.schema_version -ne "1.1") {
    Add-Problem "dry-run modified loop.config.json schema_version."
}
$StatusAfterDryRun = Get-Content -LiteralPath $StatusPath -Raw | ConvertFrom-Json
if ([string]$StatusAfterDryRun.schema_version -ne "0.9") {
    Add-Problem "dry-run modified status.json schema_version."
}
if (Test-Path -LiteralPath $SchemaPath -PathType Leaf) {
    Add-Problem "dry-run recreated schema-version.json."
}
if (Test-Path -LiteralPath $RemovedTemplateFile -PathType Leaf) {
    Add-Problem "dry-run restored missing template file."
}
$EventAfterDryRun = if (Test-Path -LiteralPath $EventLogPath -PathType Leaf) {
    Get-Content -LiteralPath $EventLogPath -Raw
} else {
    ""
}
if ($EventAfterDryRun -ne $EventBefore) {
    Add-Problem "dry-run modified event-log.ndjson."
}
$RecordsRoot = Join-Path $Project ".ai-loop\schema\migration-records"
if (Test-Path -LiteralPath $RecordsRoot -PathType Container) {
    Add-Problem "dry-run created migration-records directory."
}

$DryRunText = Invoke-AiLoop -Arguments @("-Command", "migrate", "-ProjectRoot", $Project, "-DryRun")
if ($DryRunText.ExitCode -ne 0) {
    Add-Problem "migrate -DryRun text failed with exit $($DryRunText.ExitCode): $($DryRunText.Text)"
} elseif ($DryRunText.Text -notmatch "No files were modified") {
    Add-Problem "migrate -DryRun text did not state that no files were modified: $($DryRunText.Text)"
}

$Migrate = Invoke-AiLoop -Arguments @("-Command", "migrate", "-ProjectRoot", $Project)
if ($Migrate.ExitCode -ne 0) {
    Add-Problem "real migrate failed after dry-run with exit $($Migrate.ExitCode): $($Migrate.Text)"
} else {
    $AfterValidate = Invoke-ValidateLoop -ProjectRoot $Project
    if ($AfterValidate.ExitCode -ne 0) {
        Add-Problem "project should validate after real migrate. Output: $($AfterValidate.Text)"
    }
    if (-not (Test-Path -LiteralPath $RemovedTemplateFile -PathType Leaf)) {
        Add-Problem "real migrate did not restore missing template file after dry-run."
    }
}

$FutureProject = New-InitializedProject -Name "future-project"
$FutureConfigPath = Join-Path $FutureProject ".ai-loop\loop.config.json"
$FutureConfig = Get-Content -LiteralPath $FutureConfigPath -Raw | ConvertFrom-Json
$FutureConfig.schema_version = "9.9"
Save-Json -Object $FutureConfig -Path $FutureConfigPath
$FutureDryRun = Invoke-AiLoop -Arguments @("-Command", "migrate", "-ProjectRoot", $FutureProject, "-DryRun")
if ($FutureDryRun.ExitCode -eq 0) {
    Add-Problem "future schema dry-run should fail without -Force."
} elseif ($FutureDryRun.Text -notmatch "Cannot migrate future schema") {
    Add-Problem "future schema dry-run failed for wrong reason: $($FutureDryRun.Text)"
}

if ($Problems.Count -gt 0) {
    Write-Output "Migrate dry-run test: FAILED"
    foreach ($Problem in $Problems) {
        Write-Output "- $Problem"
    }
    Write-Output "Fixture root: $TempRoot"
    exit 2
}

Write-Output "Migrate dry-run test: OK"
Write-Output "Fixture root: $TempRoot"
Write-Output "Cases checked: JSON plan, text plan, no writes, real migrate, future schema block"

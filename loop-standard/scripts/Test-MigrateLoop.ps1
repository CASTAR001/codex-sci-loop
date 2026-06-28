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
$ValidateLoopScript = Join-Path $PSScriptRoot "validate-loop.ps1"
$TempRoot = Join-Path $RepoRoot ".tmp-ai-loop-migrate"
$Problems = New-Object System.Collections.Generic.List[string]

Assert-UnderRoot -Root $RepoRoot -Path $TempRoot
if ((Test-Path -LiteralPath $TempRoot) -and -not $KeepTemp) {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $TempRoot | Out-Null

$OldProject = New-InitializedProject -Name "old-project"
$Marker = "CUSTOM-MEMORY-MARKER: preserve me through migration"
$ActiveContextPath = Join-Path $OldProject ".ai-loop\memory\activeContext.md"
Add-Content -LiteralPath $ActiveContextPath -Encoding utf8 -Value @("", $Marker)

$ConfigPath = Join-Path $OldProject ".ai-loop\loop.config.json"
$Config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$Config.schema_version = "1.1"
Save-Json -Object $Config -Path $ConfigPath

$StatusPath = Join-Path $OldProject ".ai-loop\status.json"
$Status = Get-Content -LiteralPath $StatusPath -Raw | ConvertFrom-Json
$Status.schema_version = "1.0"
Save-Json -Object $Status -Path $StatusPath

$SchemaDir = Join-Path $OldProject ".ai-loop\schema"
Remove-Item -LiteralPath $SchemaDir -Recurse -Force
$RemovedTemplateFile = Join-Path $OldProject ".ai-loop\workers\README.md"
if (Test-Path -LiteralPath $RemovedTemplateFile -PathType Leaf) {
    Remove-Item -LiteralPath $RemovedTemplateFile -Force
}

$BeforeValidate = Invoke-ValidateLoop -ProjectRoot $OldProject
if ($BeforeValidate.ExitCode -eq 0) {
    Add-Problem "old-project should fail validate-loop before migration."
}

$MigrateResult = Invoke-AiLoop -Arguments @("-Command", "migrate", "-ProjectRoot", $OldProject)
if ($MigrateResult.ExitCode -ne 0) {
    Add-Problem "old-project migration failed with exit $($MigrateResult.ExitCode): $($MigrateResult.Text)"
} else {
    $AfterValidate = Invoke-ValidateLoop -ProjectRoot $OldProject
    if ($AfterValidate.ExitCode -ne 0) {
        Add-Problem "old-project should pass validate-loop after migration. Output: $($AfterValidate.Text)"
    }

    $ActiveContextText = Get-Content -LiteralPath $ActiveContextPath -Raw
    if ($ActiveContextText -notmatch [regex]::Escape($Marker)) {
        Add-Problem "old-project migration overwrote project memory marker."
    }

    if (-not (Test-Path -LiteralPath $RemovedTemplateFile -PathType Leaf)) {
        Add-Problem "old-project migration did not restore missing template file: .ai-loop/workers/README.md"
    }

    $RecordFile = Get-LatestMigrationRecord -ProjectRoot $OldProject
    if ($null -eq $RecordFile) {
        Add-Problem "old-project migration did not write migration-record.json."
    } else {
        $Record = Get-Content -LiteralPath $RecordFile.FullName -Raw | ConvertFrom-Json
        if ([string]$Record.from_schema_version -ne "1.1") {
            Add-Problem "old-project migration record has wrong from_schema_version: $($Record.from_schema_version)"
        }
        if ([string]$Record.to_schema_version -ne "1.2") {
            Add-Problem "old-project migration record has wrong to_schema_version: $($Record.to_schema_version)"
        }
        if (@($Record.actions).Count -eq 0) {
            Add-Problem "old-project migration record has no actions."
        }
    }

    $EventLogPath = Join-Path $OldProject ".ai-loop\events\event-log.ndjson"
    $EventLogText = Get-Content -LiteralPath $EventLogPath -Raw
    if ($EventLogText -notmatch '"type":"migration"') {
        Add-Problem "old-project event-log.ndjson missing migration event."
    }
}

$FutureProject = New-InitializedProject -Name "future-project"
$FutureConfigPath = Join-Path $FutureProject ".ai-loop\loop.config.json"
$FutureConfig = Get-Content -LiteralPath $FutureConfigPath -Raw | ConvertFrom-Json
$FutureConfig.schema_version = "9.9"
Save-Json -Object $FutureConfig -Path $FutureConfigPath
$FutureResult = Invoke-AiLoop -Arguments @("-Command", "migrate", "-ProjectRoot", $FutureProject)
if ($FutureResult.ExitCode -eq 0) {
    Add-Problem "future-project migration should fail without -Force."
} elseif ($FutureResult.Text -notmatch "Cannot migrate future schema") {
    Add-Problem "future-project migration failed for the wrong reason: $($FutureResult.Text)"
}

$EmptyProject = Join-Path $TempRoot "empty-project"
New-Item -ItemType Directory -Force -Path $EmptyProject | Out-Null
$EmptyResult = Invoke-AiLoop -Arguments @("-Command", "migrate", "-ProjectRoot", $EmptyProject)
if ($EmptyResult.ExitCode -eq 0) {
    Add-Problem "empty-project migration should fail when .ai-loop is missing."
} elseif ($EmptyResult.Text -notmatch "Run ai-loop init first") {
    Add-Problem "empty-project migration failed for the wrong reason: $($EmptyResult.Text)"
}

if ($Problems.Count -gt 0) {
    Write-Output "Migrate loop test: FAILED"
    foreach ($Problem in $Problems) {
        Write-Output "- $Problem"
    }
    exit 2
}

Write-Output "Migrate loop test: OK"
Write-Output "Fixture root: $TempRoot"
Write-Output "Cases checked: old-project, future-project, empty-project"

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-JsonFile {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string]$Path,
        [int]$Depth = 30
    )
    $Value | ConvertTo-Json -Depth $Depth | Set-Content -LiteralPath $Path -Encoding utf8
}

function Add-Action {
    param([Parameter(Mandatory = $true)][string]$Message)
    $script:Actions.Add($Message)
}

function Backup-File {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$BackupDir
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return "" }
    New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
    $BackupPath = Join-Path $BackupDir (Split-Path -Leaf $Path)
    Copy-Item -LiteralPath $Path -Destination $BackupPath -Force
    return $BackupPath
}

function Get-ObjectStringProperty {
    param(
        [AllowNull()]$Object,
        [Parameter(Mandatory = $true)][string]$Name
    )
    if ($null -eq $Object -or $null -eq $Object.PSObject.Properties[$Name]) {
        return ""
    }
    return [string]$Object.$Name
}

function Set-JsonProperty {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        $Value
    )
    if ($null -ne $Object.PSObject.Properties[$Name]) {
        $Object.$Name = $Value
    } else {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    }
}

function Merge-TemplateDirectory {
    param(
        [Parameter(Mandatory = $true)][string]$SourceRoot,
        [Parameter(Mandatory = $true)][string]$DestinationRoot
    )
    New-Item -ItemType Directory -Force -Path $DestinationRoot | Out-Null
    foreach ($Directory in @(Get-ChildItem -LiteralPath $SourceRoot -Recurse -Directory -Force)) {
        $RelativeDirectory = $Directory.FullName.Substring($SourceRoot.Length).TrimStart("\", "/")
        $TargetDirectory = Join-Path $DestinationRoot $RelativeDirectory
        if (-not (Test-Path -LiteralPath $TargetDirectory -PathType Container)) {
            New-Item -ItemType Directory -Force -Path $TargetDirectory | Out-Null
            Add-Action "created directory: .ai-loop/$($RelativeDirectory -replace '\\','/')"
        }
    }
    foreach ($File in @(Get-ChildItem -LiteralPath $SourceRoot -Recurse -File -Force)) {
        $RelativeFile = $File.FullName.Substring($SourceRoot.Length).TrimStart("\", "/")
        $TargetFile = Join-Path $DestinationRoot $RelativeFile
        if (-not (Test-Path -LiteralPath $TargetFile -PathType Leaf)) {
            $TargetParent = Split-Path -Parent $TargetFile
            New-Item -ItemType Directory -Force -Path $TargetParent | Out-Null
            Copy-Item -LiteralPath $File.FullName -Destination $TargetFile -Force
            Add-Action "copied missing template file: .ai-loop/$($RelativeFile -replace '\\','/')"
        }
    }
}

function Merge-TopLevelJsonProperties {
    param(
        [Parameter(Mandatory = $true)]$Target,
        [Parameter(Mandatory = $true)]$Template,
        [Parameter(Mandatory = $true)][string]$Label
    )
    foreach ($Property in $Template.PSObject.Properties) {
        if ($null -eq $Target.PSObject.Properties[$Property.Name]) {
            $Target | Add-Member -NotePropertyName $Property.Name -NotePropertyValue $Property.Value
            Add-Action "added missing $Label property: $($Property.Name)"
        }
    }
}

function Add-EventLogEntry {
    param(
        [Parameter(Mandatory = $true)][string]$LoopDir,
        [Parameter(Mandatory = $true)]$Event
    )
    $EventDir = Join-Path $LoopDir "events"
    New-Item -ItemType Directory -Force -Path $EventDir | Out-Null
    $EventLog = Join-Path $EventDir "event-log.ndjson"
    ($Event | ConvertTo-Json -Depth 20 -Compress) | Add-Content -LiteralPath $EventLog -Encoding utf8
}

$KitRoot = Split-Path -Parent $PSScriptRoot
$TemplateLoopDir = Join-Path $KitRoot "templates\.ai-loop"
$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$LoopDir = Join-Path $ProjectRoot ".ai-loop"
$Actions = New-Object System.Collections.Generic.List[string]

if (-not (Test-Path -LiteralPath $LoopDir -PathType Container)) {
    throw "Cannot migrate because .ai-loop does not exist. Run ai-loop init first."
}
if (-not (Test-Path -LiteralPath $TemplateLoopDir -PathType Container)) {
    throw "Missing template directory: $TemplateLoopDir"
}

$TemplateConfigPath = Join-Path $TemplateLoopDir "loop.config.json"
$TemplateStatusPath = Join-Path $TemplateLoopDir "status.json"
$TemplateSchemaPath = Join-Path $TemplateLoopDir "schema\schema-version.json"
$TemplateMigrationLogPath = Join-Path $TemplateLoopDir "schema\migration-log.md"

$ConfigPath = Join-Path $LoopDir "loop.config.json"
$StatusPath = Join-Path $LoopDir "status.json"
$SchemaPath = Join-Path $LoopDir "schema\schema-version.json"
$MigrationLogPath = Join-Path $LoopDir "schema\migration-log.md"

$TemplateConfig = Get-Content -LiteralPath $TemplateConfigPath -Raw | ConvertFrom-Json
$TemplateStatus = Get-Content -LiteralPath $TemplateStatusPath -Raw | ConvertFrom-Json
$TemplateSchema = Get-Content -LiteralPath $TemplateSchemaPath -Raw | ConvertFrom-Json
$TargetSchemaVersion = [string]$TemplateSchema.schema_version
$TargetStatusSchemaVersion = [string]$TemplateSchema.status_schema_version
$StartedAt = (Get-Date).ToUniversalTime().ToString("o")

$CurrentConfig = $null
$CurrentSchemaVersion = "missing"
if (Test-Path -LiteralPath $ConfigPath -PathType Leaf) {
    $CurrentConfig = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
    $CurrentSchemaVersion = Get-ObjectStringProperty -Object $CurrentConfig -Name "schema_version"
    if ([string]::IsNullOrWhiteSpace($CurrentSchemaVersion)) {
        $CurrentSchemaVersion = "missing"
    }
}
if ($CurrentSchemaVersion -ne "missing") {
    try {
        if ([version]$CurrentSchemaVersion -gt [version]$TargetSchemaVersion -and -not $Force) {
            throw "Cannot migrate future schema $CurrentSchemaVersion to $TargetSchemaVersion without -Force."
        }
    } catch {
        if ($_.Exception.Message -like "Cannot migrate future schema*") { throw }
        throw "Invalid schema version in loop.config.json: $CurrentSchemaVersion"
    }
}

$MigrationRoot = Join-Path $LoopDir "schema\migration-records"
$Stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
$MigrationDir = Join-Path $MigrationRoot $Stamp
$BackupDir = Join-Path $MigrationDir "backups"
New-Item -ItemType Directory -Force -Path $MigrationDir | Out-Null

Merge-TemplateDirectory -SourceRoot $TemplateLoopDir -DestinationRoot $LoopDir

if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
    Copy-Item -LiteralPath $TemplateConfigPath -Destination $ConfigPath -Force
    Add-Action "created loop.config.json from template"
} else {
    $Config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
    $Before = $Config | ConvertTo-Json -Depth 30
    Merge-TopLevelJsonProperties -Target $Config -Template $TemplateConfig -Label "loop.config.json"
    if ((Get-ObjectStringProperty -Object $Config -Name "schema_version") -ne $TargetSchemaVersion) {
        Set-JsonProperty -Object $Config -Name "schema_version" -Value $TargetSchemaVersion
        Add-Action "updated loop.config.json schema_version to $TargetSchemaVersion"
    }
    $After = $Config | ConvertTo-Json -Depth 30
    if ($Before -ne $After) {
        Backup-File -Path $ConfigPath -BackupDir $BackupDir | Out-Null
        Write-JsonFile -Value $Config -Path $ConfigPath
    }
}

if (-not (Test-Path -LiteralPath $StatusPath -PathType Leaf)) {
    Copy-Item -LiteralPath $TemplateStatusPath -Destination $StatusPath -Force
    Add-Action "created status.json from template"
} else {
    $Status = Get-Content -LiteralPath $StatusPath -Raw | ConvertFrom-Json
    $Before = $Status | ConvertTo-Json -Depth 30
    Merge-TopLevelJsonProperties -Target $Status -Template $TemplateStatus -Label "status.json"
    if ((Get-ObjectStringProperty -Object $Status -Name "schema_version") -ne $TargetStatusSchemaVersion) {
        Set-JsonProperty -Object $Status -Name "schema_version" -Value $TargetStatusSchemaVersion
        Add-Action "updated status.json schema_version to $TargetStatusSchemaVersion"
    }
    if ([string]::IsNullOrWhiteSpace((Get-ObjectStringProperty -Object $Status -Name "project_name"))) {
        Set-JsonProperty -Object $Status -Name "project_name" -Value (Split-Path -Leaf $ProjectRoot)
        Add-Action "filled missing status.json project_name"
    }
    if ([string]::IsNullOrWhiteSpace((Get-ObjectStringProperty -Object $Status -Name "initialized_at"))) {
        Set-JsonProperty -Object $Status -Name "initialized_at" -Value $StartedAt
        Add-Action "filled missing status.json initialized_at"
    }
    $After = $Status | ConvertTo-Json -Depth 30
    if ($Before -ne $After) {
        Backup-File -Path $StatusPath -BackupDir $BackupDir | Out-Null
        Write-JsonFile -Value $Status -Path $StatusPath
    }
}

$SchemaNeedsWrite = $true
if (Test-Path -LiteralPath $SchemaPath -PathType Leaf) {
    try {
        $ExistingSchema = Get-Content -LiteralPath $SchemaPath -Raw | ConvertFrom-Json
        $SchemaNeedsWrite = ((Get-ObjectStringProperty -Object $ExistingSchema -Name "schema_version") -ne $TargetSchemaVersion)
    } catch {
        $SchemaNeedsWrite = $true
    }
}
if ($SchemaNeedsWrite) {
    Backup-File -Path $SchemaPath -BackupDir $BackupDir | Out-Null
    Copy-Item -LiteralPath $TemplateSchemaPath -Destination $SchemaPath -Force
    Add-Action "updated schema-version.json to $TargetSchemaVersion"
}

if (-not (Test-Path -LiteralPath $MigrationLogPath -PathType Leaf)) {
    Copy-Item -LiteralPath $TemplateMigrationLogPath -Destination $MigrationLogPath -Force
    Add-Action "created migration-log.md from template"
} else {
    Add-Content -LiteralPath $MigrationLogPath -Encoding utf8 -Value @(
        ""
        "## Migration $Stamp"
        ""
        "- From schema: $CurrentSchemaVersion"
        "- To schema: $TargetSchemaVersion"
        "- Record: .ai-loop/schema/migration-records/$Stamp/migration-record.json"
    )
    Add-Action "appended migration-log.md entry"
}

$FinishedAt = (Get-Date).ToUniversalTime().ToString("o")
$Record = [ordered]@{
    schema_version = "1.0"
    started_at = $StartedAt
    finished_at = $FinishedAt
    project_root = $ProjectRoot
    from_schema_version = $CurrentSchemaVersion
    to_schema_version = $TargetSchemaVersion
    status_schema_version = $TargetStatusSchemaVersion
    actions = @($Actions)
    backups = @(
        if (Test-Path -LiteralPath $BackupDir -PathType Container) {
            Get-ChildItem -LiteralPath $BackupDir -File | ForEach-Object {
                ".ai-loop/schema/migration-records/$Stamp/backups/$($_.Name)"
            }
        }
    )
}
$RecordPath = Join-Path $MigrationDir "migration-record.json"
Write-JsonFile -Value $Record -Path $RecordPath

Add-EventLogEntry -LoopDir $LoopDir -Event ([ordered]@{
    ts = $FinishedAt
    type = "migration"
    actor = "ai-loop migrate"
    summary = "Migrated .ai-loop schema from $CurrentSchemaVersion to $TargetSchemaVersion"
    phase = $null
    result = "migrated"
    evidence = @(".ai-loop/schema/migration-records/$Stamp/migration-record.json")
    paths = @(".ai-loop/schema/schema-version.json", ".ai-loop/loop.config.json", ".ai-loop/status.json", ".ai-loop/events/event-log.ndjson")
})

Write-Output "Migrated .ai-loop schema from $CurrentSchemaVersion to $TargetSchemaVersion"
Write-Output "Migration record: $RecordPath"
foreach ($Action in $Actions) {
    Write-Output "- $Action"
}

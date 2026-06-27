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

function New-CaseRoot {
    param([Parameter(Mandatory = $true)][string]$Name)
    $CaseRoot = Join-Path $TempRoot $Name
    Assert-UnderRoot -Root $RepoRoot -Path $CaseRoot
    New-Item -ItemType Directory -Force -Path $CaseRoot | Out-Null
    Copy-Item -LiteralPath (Join-Path $ValidRoot ".ai-loop") -Destination (Join-Path $CaseRoot ".ai-loop") -Recurse -Force
    return $CaseRoot
}

function Invoke-ValidateLoop {
    param([Parameter(Mandatory = $true)][string]$ProjectRoot)
    $Output = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ValidateLoopScript -ProjectRoot $ProjectRoot 2>&1)
    return [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Text = ($Output | Out-String)
    }
}

function Expect-Pass {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$ProjectRoot
    )
    $Result = Invoke-ValidateLoop -ProjectRoot $ProjectRoot
    if ($Result.ExitCode -ne 0) {
        Add-Problem "$Name expected validate-loop to pass, got exit $($Result.ExitCode): $($Result.Text)"
    }
}

function Expect-Failure {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [Parameter(Mandatory = $true)][string]$ExpectedText
    )
    $Result = Invoke-ValidateLoop -ProjectRoot $ProjectRoot
    if ($Result.ExitCode -eq 0) {
        Add-Problem "$Name expected validate-loop to fail, but it passed."
        return
    }
    if ($Result.Text -notmatch [regex]::Escape($ExpectedText)) {
        Add-Problem "$Name failed for the wrong reason. Expected '$ExpectedText'. Output: $($Result.Text)"
    }
}

$KitRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = Split-Path -Parent $KitRoot
$AiLoopScript = Join-Path $PSScriptRoot "ai-loop.ps1"
$ValidateLoopScript = Join-Path $PSScriptRoot "validate-loop.ps1"
$TempRoot = Join-Path $RepoRoot ".tmp-ai-loop-schema-versioning"
$Problems = New-Object System.Collections.Generic.List[string]

Assert-UnderRoot -Root $RepoRoot -Path $TempRoot
if ((Test-Path -LiteralPath $TempRoot) -and -not $KeepTemp) {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $TempRoot | Out-Null

$ValidRoot = Join-Path $TempRoot "valid-init"
New-Item -ItemType Directory -Force -Path $ValidRoot | Out-Null
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $AiLoopScript -Command init -ProjectRoot $ValidRoot | Out-Null
if ($LASTEXITCODE -ne 0) {
    Add-Problem "init failed for valid schema fixture with exit $LASTEXITCODE"
} else {
    Expect-Pass -Name "valid-init" -ProjectRoot $ValidRoot
}

$MissingSchemaRoot = New-CaseRoot -Name "missing-schema-manifest"
Remove-Item -LiteralPath (Join-Path $MissingSchemaRoot ".ai-loop\schema\schema-version.json") -Force
Expect-Failure -Name "missing-schema-manifest" -ProjectRoot $MissingSchemaRoot -ExpectedText "schema-version.json missing"

$OldConfigRoot = New-CaseRoot -Name "old-config-schema"
$OldConfigPath = Join-Path $OldConfigRoot ".ai-loop\loop.config.json"
$OldConfig = Get-Content -LiteralPath $OldConfigPath -Raw | ConvertFrom-Json
$OldConfig.schema_version = "1.1"
Save-Json -Object $OldConfig -Path $OldConfigPath
Expect-Failure -Name "old-config-schema" -ProjectRoot $OldConfigRoot -ExpectedText "older than min supported"

$FutureConfigRoot = New-CaseRoot -Name "future-config-schema"
$FutureConfigPath = Join-Path $FutureConfigRoot ".ai-loop\loop.config.json"
$FutureConfig = Get-Content -LiteralPath $FutureConfigPath -Raw | ConvertFrom-Json
$FutureConfig.schema_version = "9.9"
Save-Json -Object $FutureConfig -Path $FutureConfigPath
Expect-Failure -Name "future-config-schema" -ProjectRoot $FutureConfigRoot -ExpectedText "newer than latest supported"

$MismatchRoot = New-CaseRoot -Name "manifest-config-mismatch"
$MismatchSchemaPath = Join-Path $MismatchRoot ".ai-loop\schema\schema-version.json"
$MismatchSchema = Get-Content -LiteralPath $MismatchSchemaPath -Raw | ConvertFrom-Json
$MismatchSchema.schema_version = "1.3"
$MismatchSchema.latest_schema_version = "1.3"
Save-Json -Object $MismatchSchema -Path $MismatchSchemaPath
Expect-Failure -Name "manifest-config-mismatch" -ProjectRoot $MismatchRoot -ExpectedText "schema_version differs from schema manifest"

$MissingPropertyRoot = New-CaseRoot -Name "schema-missing-property"
$MissingPropertyPath = Join-Path $MissingPropertyRoot ".ai-loop\schema\schema-version.json"
$MissingProperty = Get-Content -LiteralPath $MissingPropertyPath -Raw | ConvertFrom-Json
$MissingProperty.PSObject.Properties.Remove("latest_schema_version")
Save-Json -Object $MissingProperty -Path $MissingPropertyPath
Expect-Failure -Name "schema-missing-property" -ProjectRoot $MissingPropertyRoot -ExpectedText "schema-version.json missing required property: latest_schema_version"

$StatusMismatchRoot = New-CaseRoot -Name "status-schema-mismatch"
$StatusMismatchPath = Join-Path $StatusMismatchRoot ".ai-loop\status.json"
$StatusMismatch = Get-Content -LiteralPath $StatusMismatchPath -Raw | ConvertFrom-Json
$StatusMismatch.schema_version = "9.9"
Save-Json -Object $StatusMismatch -Path $StatusMismatchPath
Expect-Failure -Name "status-schema-mismatch" -ProjectRoot $StatusMismatchRoot -ExpectedText "status.json schema_version differs from schema manifest"

if ($Problems.Count -gt 0) {
    Write-Output "Schema versioning test: FAILED"
    foreach ($Problem in $Problems) {
        Write-Output "- $Problem"
    }
    exit 2
}

Write-Output "Schema versioning test: OK"
Write-Output "Fixture root: $TempRoot"
Write-Output "Cases checked: 7"

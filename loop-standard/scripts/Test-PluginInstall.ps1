[CmdletBinding()]
param(
    [string]$InstallRoot = "",
    [string]$SkillLibraryRoot = "E:\codexfiles\test\.agents\skills",
    [switch]$KeepTemp
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Add-Problem {
    param([Parameter(Mandatory = $true)][string]$Message)
    $script:Problems.Add($Message)
}

function Test-RequiredFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Add-Problem "missing file: $Path"
        return
    }
    if ((Get-Item -LiteralPath $Path).Length -eq 0) {
        Add-Problem "empty file: $Path"
    }
}

function Read-JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    try {
        return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    } catch {
        Add-Problem "invalid JSON: $Path - $($_.Exception.Message)"
        return $null
    }
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

$KitRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = Split-Path -Parent $KitRoot
$Problems = New-Object System.Collections.Generic.List[string]

if ([string]::IsNullOrWhiteSpace($InstallRoot)) {
    $InstallRoot = Join-Path $RepoRoot ".tmp-ai-loop-plugin-smoke\install"
}
$TempRoot = Split-Path -Parent $InstallRoot
Assert-UnderRoot -Root $RepoRoot -Path $TempRoot

if ((Test-Path -LiteralPath $TempRoot) -and -not $KeepTemp) {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $TempRoot | Out-Null

$InstallScript = Join-Path $KitRoot "scripts\install-global.ps1"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $InstallScript `
    -InstallRoot $InstallRoot `
    -SkillLibraryRoot $SkillLibraryRoot `
    -InstallPlugin `
    -CreateShim `
    -CreateMarketplace `
    -Force | Out-Null
if ($LASTEXITCODE -ne 0) {
    Add-Problem "install-global.ps1 returned exit code $LASTEXITCODE"
}

$LoopStandard = Join-Path $InstallRoot "loop-standard"
$PluginRoot = Join-Path $InstallRoot "plugins\codex-loop-harness"
$ManifestPath = Join-Path $PluginRoot ".codex-plugin\plugin.json"
$ShimPath = Join-Path $InstallRoot "bin\ai-loop.ps1"
$MarketplacePath = Join-Path $InstallRoot ".agents\plugins\marketplace.json"
$PluginWrapper = Join-Path $PluginRoot "scripts\ai-loop.ps1"

foreach ($Path in @(
    (Join-Path $LoopStandard "scripts\ai-loop.ps1"),
    (Join-Path $LoopStandard "scripts\install-global.ps1"),
    $ManifestPath,
    $ShimPath,
    $MarketplacePath,
    $PluginWrapper
)) {
    Test-RequiredFile -Path $Path
}

$Manifest = Read-JsonFile -Path $ManifestPath
if ($null -ne $Manifest) {
    if ($Manifest.name -ne "codex-loop-harness") { Add-Problem "unexpected plugin name: $($Manifest.name)" }
    if ($Manifest.skills -ne "./skills/") { Add-Problem "plugin skills path should be ./skills/: $($Manifest.skills)" }
    if ([string]::IsNullOrWhiteSpace($Manifest.interface.displayName)) { Add-Problem "plugin manifest missing interface.displayName" }
}

$Marketplace = Read-JsonFile -Path $MarketplacePath
if ($null -ne $Marketplace) {
    $Entry = @($Marketplace.plugins | Where-Object { $_.name -eq "codex-loop-harness" })
    if ($Entry.Count -ne 1) {
        Add-Problem "marketplace must contain exactly one codex-loop-harness entry"
    } else {
        if ($Entry[0].source.source -ne "local") { Add-Problem "marketplace source must be local" }
        if ($Entry[0].source.path -ne "./plugins/codex-loop-harness") { Add-Problem "marketplace plugin path mismatch: $($Entry[0].source.path)" }
        if ($Entry[0].policy.installation -ne "AVAILABLE") { Add-Problem "marketplace installation policy mismatch" }
        if ($Entry[0].policy.authentication -ne "ON_INSTALL") { Add-Problem "marketplace authentication policy mismatch" }
    }
}

$ExpectedSkillNames = @("loop-supervisor", "loop-auditor", "loop-recovery", "research-loop-orchestrator")
foreach ($SkillName in $ExpectedSkillNames) {
    $SkillPath = Join-Path $PluginRoot "skills\$SkillName\SKILL.md"
    Test-RequiredFile -Path $SkillPath
    if (Test-Path -LiteralPath $SkillPath -PathType Leaf) {
        $Text = Get-Content -LiteralPath $SkillPath -Raw
        if ($Text -notmatch "(?s)^---.*?name:\s*$([regex]::Escape($SkillName)).*?description:\s*.+?---") {
            Add-Problem "skill frontmatter missing or mismatched: $SkillName"
        }
        if ($Text -match [regex]::Escape("E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1")) {
            Add-Problem "skill contains development-only absolute loop script path: $SkillName"
        }
    }
}

$ShimDoctor = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ShimPath -Command doctor 2>&1)
if ($LASTEXITCODE -ne 0 -or (($ShimDoctor | Out-String) -notmatch "Doctor:\s+OK")) {
    Add-Problem "installed shim doctor failed: $($ShimDoctor | Out-String)"
}

$PreviousLoopStandardRoot = $env:LOOP_STANDARD_ROOT
try {
    $env:LOOP_STANDARD_ROOT = $LoopStandard
    $WrapperDoctor = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $PluginWrapper -Command doctor -SkillLibraryRoot $SkillLibraryRoot 2>&1)
    if ($LASTEXITCODE -ne 0 -or (($WrapperDoctor | Out-String) -notmatch "Doctor:\s+OK")) {
        Add-Problem "plugin wrapper doctor failed: $($WrapperDoctor | Out-String)"
    }
} finally {
    $env:LOOP_STANDARD_ROOT = $PreviousLoopStandardRoot
}

if ($Problems.Count -gt 0) {
    Write-Output "Plugin install smoke test: FAILED"
    foreach ($Problem in $Problems) {
        Write-Output "- $Problem"
    }
    exit 2
}

Write-Output "Plugin install smoke test: OK"
Write-Output "Install root: $InstallRoot"
Write-Output "Marketplace: $MarketplacePath"
Write-Output "Plugin: $PluginRoot"
Write-Output "Shim: $ShimPath"

[CmdletBinding()]
param(
    [string]$InstallRoot = "",
    [string]$SkillLibraryRoot = "",
    [switch]$KeepTemp
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$PowerShellHost = (Get-Process -Id $PID).Path

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
. (Join-Path $PSScriptRoot "test-temp-root.ps1")
$Problems = New-Object System.Collections.Generic.List[string]

if ([string]::IsNullOrWhiteSpace($InstallRoot)) {
    $TempRoot = New-LoopTestTempRoot -RepoRoot $RepoRoot -Name "plugin-smoke"
    $InstallRoot = Join-Path $TempRoot "install"
} else {
    $TempRoot = Split-Path -Parent $InstallRoot
}
Assert-UnderRoot -Root $RepoRoot -Path $TempRoot

if ((Test-Path -LiteralPath $TempRoot) -and -not $KeepTemp) {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $TempRoot | Out-Null

if ([string]::IsNullOrWhiteSpace($SkillLibraryRoot)) {
    $SkillLibraryRoot = Join-Path $TempRoot "skills"
    foreach ($SkillName in @(
        "research-task-tree", "invariant-contract", "bounded-experiment-loop",
        "deterministic-verification", "independent-crosscheck", "result-provenance-audit",
        "manuscript-consistency-audit", "skill-compliance-audit"
    )) {
        $SkillDir = Join-Path $SkillLibraryRoot $SkillName
        New-Item -ItemType Directory -Force -Path $SkillDir | Out-Null
        Set-Content -LiteralPath (Join-Path $SkillDir "SKILL.md") -Value "# $SkillName fixture"
    }
}

$InstallScript = Join-Path $KitRoot "scripts\install-global.ps1"
& $PowerShellHost -NoProfile -File $InstallScript `
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
$PluginRoot = Join-Path $InstallRoot "plugins\codex-sci-loop"
$ManifestPath = Join-Path $PluginRoot ".codex-plugin\plugin.json"
$ShimPath = Join-Path $InstallRoot "bin\ai-loop.ps1"
$MarketplacePath = Join-Path $InstallRoot ".agents\plugins\marketplace.json"
$PluginCore = Join-Path $PluginRoot "scripts\sci_loop.py"
$HookManifest = Join-Path $PluginRoot "hooks\hooks.json"

foreach ($Path in @(
    (Join-Path $LoopStandard "scripts\ai-loop.ps1"),
    (Join-Path $LoopStandard "scripts\install-global.ps1"),
    $ManifestPath,
    $ShimPath,
    $MarketplacePath,
    $PluginCore,
    (Join-Path $PluginRoot "scripts\checkpoint.py")
)) {
    Test-RequiredFile -Path $Path
}
if (Test-Path -LiteralPath $HookManifest) {
    Add-Problem "native plugin copy contains a hook registration manifest"
}

$Manifest = Read-JsonFile -Path $ManifestPath
$SourceManifest = Read-JsonFile -Path (Join-Path $RepoRoot "plugins\codex-sci-loop\.codex-plugin\plugin.json")
if ($null -ne $Manifest) {
    if ($Manifest.name -ne "codex-sci-loop") { Add-Problem "unexpected plugin name: $($Manifest.name)" }
    if ($null -ne $SourceManifest -and $Manifest.version -ne $SourceManifest.version) { Add-Problem "installed plugin version differs from source: $($Manifest.version)" }
    if ($Manifest.skills -ne "./skills/") { Add-Problem "plugin skills path should be ./skills/: $($Manifest.skills)" }
    if ([string]::IsNullOrWhiteSpace($Manifest.interface.displayName)) { Add-Problem "plugin manifest missing interface.displayName" }
}

$Marketplace = Read-JsonFile -Path $MarketplacePath
if ($null -ne $Marketplace) {
    $Entry = @($Marketplace.plugins | Where-Object { $_.name -eq "codex-sci-loop" })
    if ($Entry.Count -ne 1) {
        Add-Problem "marketplace must contain exactly one codex-sci-loop entry"
    } else {
        if ($Entry[0].source.source -ne "local") { Add-Problem "marketplace source must be local" }
        if ($Entry[0].source.path -ne "./plugins/codex-sci-loop") { Add-Problem "marketplace plugin path mismatch: $($Entry[0].source.path)" }
        if ($Entry[0].policy.installation -ne "INSTALLED_BY_DEFAULT") { Add-Problem "marketplace installation policy mismatch" }
        if ($Entry[0].policy.authentication -ne "ON_INSTALL") { Add-Problem "marketplace authentication policy mismatch" }
    }
}

$ExpectedSkillNames = @("task-checkpoint", "research-verification")
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

$ShimDoctor = @(& $PowerShellHost -NoProfile -File $ShimPath -Command doctor 2>&1)
if ($LASTEXITCODE -ne 0 -or (($ShimDoctor | Out-String) -notmatch "Doctor:\s+OK")) {
    Add-Problem "installed shim doctor failed: $($ShimDoctor | Out-String)"
}

$PluginVersion = @(& python3 $PluginCore --version 2>&1)
if ($LASTEXITCODE -ne 0 -or $null -eq $SourceManifest -or (($PluginVersion | Out-String).Trim() -ne $SourceManifest.version)) {
    Add-Problem "plugin core version check failed: $($PluginVersion | Out-String)"
}
$PluginDistribution = @(& python3 $PluginCore validate-distribution 2>&1)
if ($LASTEXITCODE -ne 0 -or (($PluginDistribution | Out-String) -notmatch "DISTRIBUTION:\s+OK")) {
    Add-Problem "plugin distribution validation failed: $($PluginDistribution | Out-String)"
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

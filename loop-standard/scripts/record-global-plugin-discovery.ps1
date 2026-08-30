[CmdletBinding()]
param(
    [string]$ProjectRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
    [string]$InstallRoot = (Join-Path $env:USERPROFILE ".codex\loop-harness"),
    [string]$EvidencePath = "",
    [string]$PluginId = "codex-sci-loop",
    [string]$MarketplaceName = "loop-harness-local",
    [string]$MarketplaceAddJsonPath = "",
    [string]$MarketplaceListJsonPath = "",
    [string]$PluginListJsonPath = "",
    [string]$PluginAddJsonPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Add-Problem {
    param([Parameter(Mandatory = $true)][string]$Message)
    $script:Problems.Add($Message)
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

function Get-FileSha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Add-Problem "missing file: $Path"
        return ""
    }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Test-CodexCliJson {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string[]]$Needles
    )
    if ([string]::IsNullOrWhiteSpace($Path)) {
        Add-Problem "missing Codex CLI JSON path for $Label"
        return [pscustomobject][ordered]@{
            label = $Label
            status = "fail"
            path = ""
            sha256 = ""
        }
    }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Add-Problem "missing Codex CLI JSON file for $Label`: $Path"
        return [pscustomobject][ordered]@{
            label = $Label
            status = "fail"
            path = $Path
            sha256 = ""
        }
    }
    $Raw = Get-Content -LiteralPath $Path -Raw
    try {
        $null = $Raw | ConvertFrom-Json
    } catch {
        Add-Problem "Codex CLI JSON is not parseable for $Label`: $($_.Exception.Message)"
    }
    foreach ($Needle in $Needles) {
        $JsonNeedle = ($Needle | ConvertTo-Json -Compress).Trim('"')
        if ($Raw -notmatch [regex]::Escape($Needle) -and $Raw -notmatch [regex]::Escape($JsonNeedle)) {
            Add-Problem "Codex CLI JSON for $Label does not mention $Needle"
        }
    }
    return [pscustomobject][ordered]@{
        label = $Label
        status = "pass"
        path = $Path
        sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    }
}

$ProjectRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ProjectRoot)
$InstallRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($InstallRoot)
if ([string]::IsNullOrWhiteSpace($EvidencePath)) {
    $EvidencePath = Join-Path $ProjectRoot ".ai-loop\evidence\global-plugin-discovery.json"
}
$EvidencePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($EvidencePath)

$Problems = New-Object System.Collections.Generic.List[string]
$PluginRoot = Join-Path $InstallRoot "plugins\$PluginId"
$ManifestPath = Join-Path $PluginRoot ".codex-plugin\plugin.json"
$MarketplacePath = Join-Path $InstallRoot ".agents\plugins\marketplace.json"

$ManifestHash = Get-FileSha256 -Path $ManifestPath
$MarketplaceHash = Get-FileSha256 -Path $MarketplacePath
$Manifest = if (Test-Path -LiteralPath $ManifestPath -PathType Leaf) { Read-JsonFile -Path $ManifestPath } else { $null }
$Marketplace = if (Test-Path -LiteralPath $MarketplacePath -PathType Leaf) { Read-JsonFile -Path $MarketplacePath } else { $null }

if ($null -ne $Manifest) {
    if ([string]$Manifest.name -ne $PluginId) { Add-Problem "manifest name must be $PluginId" }
    if ([string]$Manifest.skills -ne "./skills/") { Add-Problem "manifest skills must be ./skills/" }
    if ([string]::IsNullOrWhiteSpace([string]$Manifest.interface.displayName)) { Add-Problem "manifest interface.displayName is required" }
}
if ($null -ne $Marketplace) {
    if ([string]$Marketplace.name -ne $MarketplaceName) { Add-Problem "marketplace name must be $MarketplaceName" }
    $Entry = @($Marketplace.plugins | Where-Object { $_.name -eq $PluginId })
    if ($Entry.Count -ne 1) {
        Add-Problem "marketplace must contain exactly one $PluginId entry"
    } else {
        if ([string]$Entry[0].source.source -ne "local") { Add-Problem "marketplace source must be local" }
        if ([string]$Entry[0].source.path -ne "./plugins/$PluginId") { Add-Problem "marketplace plugin path must be ./plugins/$PluginId" }
        if ([string]$Entry[0].policy.installation -ne "INSTALLED_BY_DEFAULT") { Add-Problem "marketplace installation policy must be INSTALLED_BY_DEFAULT" }
    }
}

$MarketplaceAdd = Test-CodexCliJson -Label "marketplace_add" -Path $MarketplaceAddJsonPath -Needles @($MarketplaceName, $InstallRoot)
$MarketplaceList = Test-CodexCliJson -Label "marketplace_list" -Path $MarketplaceListJsonPath -Needles @($MarketplaceName, $InstallRoot)
$PluginList = Test-CodexCliJson -Label "plugin_list" -Path $PluginListJsonPath -Needles @($PluginId, $MarketplaceName)
$PluginAdd = Test-CodexCliJson -Label "plugin_add" -Path $PluginAddJsonPath -Needles @($PluginId)

if ($Problems.Count -gt 0) {
    Write-Output "Global plugin discovery evidence: FAILED"
    foreach ($Problem in $Problems) {
        Write-Output "- $Problem"
    }
    exit 2
}

$Evidence = [pscustomobject][ordered]@{
    schema_version = "1.0"
    status = "pass"
    approval_scope = "PLUGIN-GLOBAL"
    validation_mode = "live-global-codex-plugin-discovery"
    plugin_id = $PluginId
    marketplace_name = $MarketplaceName
    install_root = $InstallRoot
    plugin_root = $PluginRoot
    manifest_path = $ManifestPath
    marketplace_path = $MarketplacePath
    manifest_sha256 = $ManifestHash
    marketplace_sha256 = $MarketplaceHash
    validated_at = (Get-Date).ToUniversalTime().ToString("o")
    codex_cli = [ordered]@{
        marketplace_add = $MarketplaceAdd.status
        marketplace_list = $MarketplaceList.status
        plugin_list = $PluginList.status
        plugin_add = $PluginAdd.status
        evidence_files = @($MarketplaceAdd, $MarketplaceList, $PluginList, $PluginAdd)
    }
    rollback = [ordered]@{
        command = "codex plugin remove $PluginId; codex plugin marketplace remove $MarketplaceName; Remove-Item -LiteralPath `"$InstallRoot`" -Recurse -Force"
        notes = "The install root is dedicated to Codex Loop Harness; remove the plugin, remove the marketplace, then delete the dedicated install root to roll back."
    }
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $EvidencePath) | Out-Null
$Evidence | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $EvidencePath -Encoding utf8
Write-Output "Global plugin discovery evidence: OK"
Write-Output "Evidence: $EvidencePath"

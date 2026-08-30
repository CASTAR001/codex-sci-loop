[CmdletBinding()]
param(
    [switch]$KeepTemp
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$PowerShellHost = if ([System.IO.Path]::DirectorySeparatorChar -eq "\") { "powershell.exe" } else { "pwsh" }

function Add-Problem {
    param([Parameter(Mandatory = $true)][string]$Message)
    $script:Problems.Add($Message)
}

$KitRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = Split-Path -Parent $KitRoot
. (Join-Path $PSScriptRoot "test-temp-root.ps1")
$TempRoot = New-LoopTestTempRoot -RepoRoot $RepoRoot -Name "global-plugin-evidence"
$Problems = New-Object System.Collections.Generic.List[string]

if ((Test-Path -LiteralPath $TempRoot) -and -not $KeepTemp) {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $TempRoot | Out-Null

try {
    $PluginId = "codex-sci-loop"
    $MarketplaceName = "loop-harness-local"
    $InstallRoot = Join-Path $TempRoot "install"
    $PluginRoot = Join-Path $InstallRoot "plugins\$PluginId"
    $ManifestDir = Join-Path $PluginRoot ".codex-plugin"
    $MarketplaceDir = Join-Path $InstallRoot ".agents\plugins"
    $CliDir = Join-Path $TempRoot "cli-json"
    New-Item -ItemType Directory -Force -Path $ManifestDir, $MarketplaceDir, $CliDir | Out-Null

    [ordered]@{
        name = $PluginId
        skills = "./skills/"
        interface = [ordered]@{
            displayName = "Codex Loop Harness"
        }
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $ManifestDir "plugin.json") -Encoding utf8

    [ordered]@{
        name = $MarketplaceName
        plugins = @(
            [ordered]@{
                name = $PluginId
                source = [ordered]@{
                    source = "local"
                    path = "./plugins/$PluginId"
                }
                policy = [ordered]@{
                    installation = "INSTALLED_BY_DEFAULT"
                }
            }
        )
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $MarketplaceDir "marketplace.json") -Encoding utf8

    $MarketplaceAddJson = Join-Path $CliDir "marketplace-add.json"
    $MarketplaceListJson = Join-Path $CliDir "marketplace-list.json"
    $PluginListJson = Join-Path $CliDir "plugin-list.json"
    $PluginAddJson = Join-Path $CliDir "plugin-add.json"
    [ordered]@{ name = $MarketplaceName; root = $InstallRoot } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $MarketplaceAddJson -Encoding utf8
    [ordered]@{ marketplaces = @([ordered]@{ name = $MarketplaceName; root = $InstallRoot }) } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $MarketplaceListJson -Encoding utf8
    [ordered]@{ marketplace = $MarketplaceName; plugins = @([ordered]@{ name = $PluginId }) } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $PluginListJson -Encoding utf8
    [ordered]@{ name = $PluginId; status = "installed" } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $PluginAddJson -Encoding utf8

    $EvidencePath = Join-Path $TempRoot ".ai-loop\evidence\global-plugin-discovery.json"
    $Recorder = Join-Path $PSScriptRoot "record-global-plugin-discovery.ps1"
    $Output = @(& $PowerShellHost -NoProfile -ExecutionPolicy Bypass -File $Recorder `
        -ProjectRoot $TempRoot `
        -InstallRoot $InstallRoot `
        -EvidencePath $EvidencePath `
        -MarketplaceAddJsonPath $MarketplaceAddJson `
        -MarketplaceListJsonPath $MarketplaceListJson `
        -PluginListJsonPath $PluginListJson `
        -PluginAddJsonPath $PluginAddJson 2>&1)
    if ($LASTEXITCODE -ne 0) {
        Add-Problem "record-global-plugin-discovery.ps1 failed: $($Output | Out-String)"
    }
    if (-not (Test-Path -LiteralPath $EvidencePath -PathType Leaf)) {
        Add-Problem "evidence file was not created: $EvidencePath"
    } else {
        $Evidence = Get-Content -LiteralPath $EvidencePath -Raw | ConvertFrom-Json
        if ([string]$Evidence.status -ne "pass") { Add-Problem "evidence status should be pass" }
        if ([string]$Evidence.approval_scope -ne "PLUGIN-GLOBAL") { Add-Problem "approval_scope should be PLUGIN-GLOBAL" }
        if ([string]$Evidence.plugin_id -ne $PluginId) { Add-Problem "plugin_id mismatch" }
        if ([string]$Evidence.codex_cli.marketplace_add -ne "pass") { Add-Problem "marketplace_add should pass" }
        if ([string]$Evidence.codex_cli.plugin_list -ne "pass") { Add-Problem "plugin_list should pass" }
        if ([string]$Evidence.codex_cli.plugin_add -ne "pass") { Add-Problem "plugin_add should pass" }
        if ([string]$Evidence.manifest_sha256 -notmatch '^[0-9A-Fa-f]{64}$') { Add-Problem "manifest_sha256 is not a SHA-256 digest" }
        if ([string]$Evidence.marketplace_sha256 -notmatch '^[0-9A-Fa-f]{64}$') { Add-Problem "marketplace_sha256 is not a SHA-256 digest" }
        if ([string]::IsNullOrWhiteSpace([string]$Evidence.rollback.command)) { Add-Problem "rollback command missing" }
    }
} finally {
    if ($Problems.Count -gt 0 -or $KeepTemp) {
        Write-Output "Fixture root: $TempRoot"
    } elseif (Test-Path -LiteralPath $TempRoot) {
        Remove-Item -LiteralPath $TempRoot -Recurse -Force
    }
}

if ($Problems.Count -gt 0) {
    Write-Output "Global plugin discovery evidence test: FAILED"
    foreach ($Problem in $Problems) {
        Write-Output "- $Problem"
    }
    exit 2
}

Write-Output "Global plugin discovery evidence test: OK"

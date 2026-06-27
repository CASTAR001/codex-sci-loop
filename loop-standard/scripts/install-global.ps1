[CmdletBinding()]
param(
    [string]$InstallRoot = "",
    [string]$CodexHome = "",
    [string]$SkillLibraryRoot = "E:\codexfiles\test\.agents\skills",
    [switch]$InstallPlugin,
    [switch]$CreateShim,
    [switch]$CreateMarketplace,
    [string]$MarketplaceName = "loop-harness-local",
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-TargetRoot {
    if (-not [string]::IsNullOrWhiteSpace($InstallRoot) -and -not [string]::IsNullOrWhiteSpace($CodexHome)) {
        $ResolvedInstall = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($InstallRoot)
        $ResolvedCodex = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($CodexHome)
        if ($ResolvedInstall -ne $ResolvedCodex) {
            throw "Use either -InstallRoot or -CodexHome, or pass the same path for both."
        }
        return $ResolvedInstall
    }
    if (-not [string]::IsNullOrWhiteSpace($InstallRoot)) {
        return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($InstallRoot)
    }
    if (-not [string]::IsNullOrWhiteSpace($CodexHome)) {
        return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($CodexHome)
    }
    throw "Missing install target. Use -InstallRoot <path>."
}

function Copy-CleanDirectory {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination,
        [Parameter(Mandatory = $true)][bool]$AllowReplace
    )
    if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
        throw "Missing source directory: $Source"
    }
    if (Test-Path -LiteralPath $Destination) {
        if (-not $AllowReplace) {
            throw "Destination already exists: $Destination. Use -Force to replace files."
        }
        Remove-Item -LiteralPath $Destination -Recurse -Force
    }
    Copy-Item -LiteralPath $Source -Destination $Destination -Recurse -Force
}

function Write-JsonFile {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string]$Path
    )
    $Value | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $Path -Encoding utf8
}

$KitRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = Split-Path -Parent $KitRoot
$InstallRoot = Resolve-TargetRoot
$LoopStandardDestination = Join-Path $InstallRoot "loop-standard"
$PluginSource = Join-Path $RepoRoot "plugins\codex-loop-harness"
$PluginDestination = Join-Path $InstallRoot "plugins\codex-loop-harness"
$BinDir = Join-Path $InstallRoot "bin"
$ShimPath = Join-Path $BinDir "ai-loop.ps1"
$MarketplaceDir = Join-Path $InstallRoot ".agents\plugins"
$MarketplacePath = Join-Path $MarketplaceDir "marketplace.json"

New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null

Copy-CleanDirectory -Source $KitRoot -Destination $LoopStandardDestination -AllowReplace ([bool]$Force)

if ($InstallPlugin) {
    Copy-CleanDirectory -Source $PluginSource -Destination $PluginDestination -AllowReplace ([bool]$Force)
}

if ($CreateMarketplace) {
    if (-not $InstallPlugin) {
        throw "-CreateMarketplace requires -InstallPlugin."
    }
    New-Item -ItemType Directory -Force -Path $MarketplaceDir | Out-Null
    if ((Test-Path -LiteralPath $MarketplacePath -PathType Leaf) -and -not $Force) {
        throw "Marketplace already exists: $MarketplacePath. Use -Force to replace it."
    }
    $Marketplace = [ordered]@{
        name = $MarketplaceName
        interface = [ordered]@{
            displayName = "Loop Harness Local"
        }
        plugins = @(
            [ordered]@{
                name = "codex-loop-harness"
                source = [ordered]@{
                    source = "local"
                    path = "./plugins/codex-loop-harness"
                }
                policy = [ordered]@{
                    installation = "AVAILABLE"
                    authentication = "ON_INSTALL"
                }
                category = "Productivity"
            }
        )
    }
    Write-JsonFile -Value $Marketplace -Path $MarketplacePath
}

if ($CreateShim) {
    New-Item -ItemType Directory -Force -Path $BinDir | Out-Null
    if ((Test-Path -LiteralPath $ShimPath) -and -not $Force) {
        throw "Shim already exists: $ShimPath. Use -Force to replace it."
    }
    $ShimText = @"
[CmdletBinding()]
param(
    [Parameter(Mandatory = `$true, Position = 0)]
    [ValidateSet("init", "start", "collect", "audit-pack", "validate", "validate-loop", "accept", "resume", "link-skills", "worker-preflight", "invoke-worker", "doctor")]
    [string]`$Command,

    [Parameter(Position = 1)]
    [string]`$ProjectRoot = (Get-Location).Path,

    [Parameter(Position = 2)]
    [string]`$PhaseId = "",

    [Parameter(ValueFromRemainingArguments = `$true)]
    [object[]]`$RemainingArguments
)

Set-StrictMode -Version Latest
`$ErrorActionPreference = "Stop"

`$LoopScript = Join-Path (Split-Path -Parent `$PSScriptRoot) "loop-standard\scripts\ai-loop.ps1"
if (-not (Test-Path -LiteralPath `$LoopScript -PathType Leaf)) {
    throw "Missing installed loop entrypoint: `$LoopScript"
}

`$ForwardArguments = @("-Command", `$Command, "-ProjectRoot", `$ProjectRoot, "-SkillLibraryRoot", "$SkillLibraryRoot")
if (-not [string]::IsNullOrWhiteSpace(`$PhaseId)) {
    `$ForwardArguments += @("-PhaseId", `$PhaseId)
}
`$ForwardArguments += @(`$RemainingArguments)

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File `$LoopScript @ForwardArguments
exit `$LASTEXITCODE
"@
    $ShimText | Set-Content -LiteralPath $ShimPath -Encoding utf8
}

$DoctorScript = Join-Path $LoopStandardDestination "scripts\ai-loop.ps1"
Write-Output "Installed loop-standard to $LoopStandardDestination"
if ($InstallPlugin) {
    Write-Output "Installed plugin to $PluginDestination"
}
if ($CreateMarketplace) {
    Write-Output "Created local marketplace: $MarketplacePath"
    Write-Output "Optional Codex marketplace add command:"
    Write-Output "codex plugin marketplace add `"$InstallRoot`""
}
if ($CreateShim) {
    Write-Output "Created shim: $ShimPath"
    Write-Output "Optional PATH entry:"
    Write-Output $BinDir
}
Write-Output "Verify installation with:"
if ($CreateShim) {
    Write-Output "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$ShimPath`" -Command doctor"
} else {
    Write-Output "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$DoctorScript`" -Command doctor -SkillLibraryRoot `"$SkillLibraryRoot`""
}

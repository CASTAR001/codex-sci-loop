[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$CodexHome,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$KitRoot = Split-Path -Parent $PSScriptRoot
$CodexHome = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($CodexHome)
$Destination = Join-Path $CodexHome "loop-standard"

if ((Test-Path -LiteralPath $Destination) -and -not $Force) {
    throw "Destination already exists: $Destination. Use -Force to replace files."
}

New-Item -ItemType Directory -Force -Path $CodexHome | Out-Null
New-Item -ItemType Directory -Force -Path $Destination | Out-Null

foreach ($Name in @("templates", "prompts", "scripts", "docs")) {
    $Source = Join-Path $KitRoot $Name
    $Target = Join-Path $Destination $Name
    if (Test-Path -LiteralPath $Target) {
        if (-not $Force) {
            throw "Target exists: $Target. Use -Force to replace files."
        }
        Remove-Item -LiteralPath $Target -Recurse -Force
    }
    Copy-Item -LiteralPath $Source -Destination $Target -Recurse -Force
}

Copy-Item -LiteralPath (Join-Path $KitRoot "README.md") -Destination (Join-Path $Destination "README.md") -Force

Write-Output "Installed loop-standard to $Destination"
Write-Output "Initialize a project with:"
Write-Output "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$Destination\scripts\init-loop.ps1`" -ProjectRoot <project-root>"

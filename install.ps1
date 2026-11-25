[CmdletBinding()]
param(
    [switch]$LegacyToolkit,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Arguments
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-LoopInstallPlatform {
    if ([System.IO.Path]::DirectorySeparatorChar -eq "\") {
        return "windows"
    }
    $Uname = ""
    try {
        $Uname = (& uname -s 2>$null)
    } catch {
        $Uname = ""
    }
    switch -Regex ($Uname) {
        "^Linux$" { return "linux" }
        "^Darwin$" { return "macos" }
        default { return "unknown" }
    }
}

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not $LegacyToolkit -and -not $Arguments) {
    $Codex = Get-Command codex -CommandType Application -ErrorAction SilentlyContinue
    if ($null -eq $Codex) {
        throw "Native plugin installation requires the Codex CLI (codex) on PATH."
    }
    & $Codex.Source plugin marketplace add $RepoRoot
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $Codex.Source plugin add codex-sci-loop@codex-sci-loop-local
    exit $LASTEXITCODE
}

$Platform = Get-LoopInstallPlatform

switch ($Platform) {
    "windows" {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot "loop-standard\scripts\install-global.ps1") @Arguments
        exit $LASTEXITCODE
    }
    "linux" {
        $LinuxInstaller = Join-Path $RepoRoot "loop-standard/scripts/install-global.sh"
        & bash $LinuxInstaller @Arguments
        exit $LASTEXITCODE
    }
    "macos" {
        throw "The compatibility toolkit installer supports Linux and Windows. Run install.ps1 without arguments to install the Codex plugin."
    }
    default {
        throw "Unsupported platform for loop harness install."
    }
}

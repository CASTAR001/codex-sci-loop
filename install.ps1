[CmdletBinding()]
param(
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
        throw "macOS installer placeholder: platform-specific packaging is reserved for a later phase."
    }
    default {
        throw "Unsupported platform for loop harness install."
    }
}

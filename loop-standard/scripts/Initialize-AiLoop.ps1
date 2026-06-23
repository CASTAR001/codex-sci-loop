[CmdletBinding()]
param(
    [string]$TargetRoot = (Get-Location).Path,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-JsonFile {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string]$Path
    )
    $Value | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $Path -Encoding utf8
}

$KitRoot = Split-Path -Parent $PSScriptRoot
$TemplateDir = Join-Path $KitRoot ".ai-loop"
$TargetRoot = (Resolve-Path -LiteralPath $TargetRoot).Path
$ProjectLoopDir = Join-Path $TargetRoot ".ai-loop"

if (-not (Test-Path -LiteralPath $TemplateDir -PathType Container)) {
    throw "Template directory not found: $TemplateDir"
}

if (Test-Path -LiteralPath $ProjectLoopDir) {
    if (-not $Force) {
        throw ".ai-loop already exists at $ProjectLoopDir. Use -Force to overwrite template files."
    }
    Copy-Item -Path (Join-Path $TemplateDir "*") -Destination $ProjectLoopDir -Recurse -Force
} else {
    Copy-Item -LiteralPath $TemplateDir -Destination $ProjectLoopDir -Recurse -Force
}

$StatusPath = Join-Path $ProjectLoopDir "status.json"
$Status = Get-Content -LiteralPath $StatusPath -Raw | ConvertFrom-Json
$Status.project_name = Split-Path -Leaf $TargetRoot
$Status.initialized_at = (Get-Date).ToUniversalTime().ToString("o")
Write-JsonFile -Value $Status -Path $StatusPath

Write-Output "Initialized .ai-loop at $ProjectLoopDir"

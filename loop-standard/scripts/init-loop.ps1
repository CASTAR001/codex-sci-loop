[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
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
$TemplateLoopDir = Join-Path $KitRoot "templates\.ai-loop"
$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$LoopDir = Join-Path $ProjectRoot ".ai-loop"

if (-not (Test-Path -LiteralPath $TemplateLoopDir -PathType Container)) {
    throw "Missing template directory: $TemplateLoopDir"
}

if (Test-Path -LiteralPath $LoopDir) {
    if (-not $Force) {
        throw ".ai-loop already exists at $LoopDir. Use -Force to refresh template files."
    }
    Copy-Item -Path (Join-Path $TemplateLoopDir "*") -Destination $LoopDir -Recurse -Force
} else {
    Copy-Item -LiteralPath $TemplateLoopDir -Destination $LoopDir -Recurse -Force
}

foreach ($Subdir in @("runs", "audits", "logs")) {
    New-Item -ItemType Directory -Force -Path (Join-Path $LoopDir $Subdir) | Out-Null
}
New-Item -ItemType Directory -Force -Path (Join-Path $ProjectRoot ".agents\skills") | Out-Null

$StatusPath = Join-Path $LoopDir "status.json"
$Status = Get-Content -LiteralPath $StatusPath -Raw | ConvertFrom-Json
$Status.project_name = Split-Path -Leaf $ProjectRoot
$Status.initialized_at = (Get-Date).ToUniversalTime().ToString("o")
Write-JsonFile -Value $Status -Path $StatusPath

Write-Output "Initialized loop template at $LoopDir"

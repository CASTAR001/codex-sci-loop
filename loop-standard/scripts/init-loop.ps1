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

function Merge-TemplateDirectory {
    param(
        [Parameter(Mandatory = $true)][string]$SourceRoot,
        [Parameter(Mandatory = $true)][string]$DestinationRoot,
        [switch]$Overwrite
    )

    New-Item -ItemType Directory -Force -Path $DestinationRoot | Out-Null
    foreach ($Directory in @(Get-ChildItem -LiteralPath $SourceRoot -Recurse -Directory -Force)) {
        $RelativeDirectory = $Directory.FullName.Substring($SourceRoot.Length).TrimStart("\", "/")
        New-Item -ItemType Directory -Force -Path (Join-Path $DestinationRoot $RelativeDirectory) | Out-Null
    }
    foreach ($File in @(Get-ChildItem -LiteralPath $SourceRoot -Recurse -File -Force)) {
        $RelativeFile = $File.FullName.Substring($SourceRoot.Length).TrimStart("\", "/")
        $TargetFile = Join-Path $DestinationRoot $RelativeFile
        if ($Overwrite -or -not (Test-Path -LiteralPath $TargetFile -PathType Leaf)) {
            $TargetParent = Split-Path -Parent $TargetFile
            New-Item -ItemType Directory -Force -Path $TargetParent | Out-Null
            Copy-Item -LiteralPath $File.FullName -Destination $TargetFile -Force
        }
    }
}

$KitRoot = Split-Path -Parent $PSScriptRoot
$TemplateLoopDir = Join-Path $KitRoot "templates\.ai-loop"
$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$LoopDir = Join-Path $ProjectRoot ".ai-loop"

if (-not (Test-Path -LiteralPath $TemplateLoopDir -PathType Container)) {
    throw "Missing template directory: $TemplateLoopDir"
}

if (Test-Path -LiteralPath $LoopDir) {
    Merge-TemplateDirectory -SourceRoot $TemplateLoopDir -DestinationRoot $LoopDir -Overwrite:$Force
} else {
    Copy-Item -LiteralPath $TemplateLoopDir -Destination $LoopDir -Recurse -Force
}

foreach ($Subdir in @("runs", "audits", "logs")) {
    New-Item -ItemType Directory -Force -Path (Join-Path $LoopDir $Subdir) | Out-Null
}
$AgentSkillsDir = Join-Path $ProjectRoot ".agents\skills"
try {
    New-Item -ItemType Directory -Force -Path $AgentSkillsDir | Out-Null
} catch {
    Write-Warning "Could not initialize optional agent skill directory: $AgentSkillsDir. Reason: $($_.Exception.Message)"
}

$StatusPath = Join-Path $LoopDir "status.json"
$Status = Get-Content -LiteralPath $StatusPath -Raw | ConvertFrom-Json
$Status.project_name = Split-Path -Leaf $ProjectRoot
$Status.initialized_at = (Get-Date).ToUniversalTime().ToString("o")
Write-JsonFile -Value $Status -Path $StatusPath

if ($Force) {
    Write-Output "Initialized loop template at $LoopDir with template refresh."
} else {
    Write-Output "Initialized loop template at $LoopDir with non-destructive merge."
}

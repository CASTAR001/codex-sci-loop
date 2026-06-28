[CmdletBinding()]
param(
    [switch]$KeepTemp
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Add-Problem {
    param([Parameter(Mandatory = $true)][string]$Message)
    $script:Problems.Add($Message)
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

function Invoke-Required {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][scriptblock]$Action
    )
    $Output = @(& $Action 2>&1)
    if ($LASTEXITCODE -ne 0) {
        Add-Problem "$Label failed with exit $LASTEXITCODE`: $($Output | Out-String)"
    }
}

function Count-PhaseRows {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Phase
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return 0 }
    return @(
        Get-Content -LiteralPath $Path |
            Where-Object { $_ -like "*| $Phase |*" }
    ).Count
}

$KitRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = Split-Path -Parent $KitRoot
$AiLoopScript = Join-Path $PSScriptRoot "ai-loop.ps1"
. (Join-Path $PSScriptRoot "test-temp-root.ps1")
$TempRoot = New-LoopTestTempRoot -RepoRoot $RepoRoot -Name "collect-idempotence"
$Problems = New-Object System.Collections.Generic.List[string]

Assert-UnderRoot -Root $RepoRoot -Path $TempRoot
if ((Test-Path -LiteralPath $TempRoot) -and -not $KeepTemp) {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $TempRoot | Out-Null

Push-Location $TempRoot
try {
    git init | Out-Null
    Set-Content -LiteralPath "README.md" -Encoding utf8 -Value "# Collect idempotence fixture"
    Set-Content -LiteralPath "verify.ps1" -Encoding utf8 -Value "Write-Output 'idempotent: OK'`nexit 0"
    git add README.md | Out-Null
    git add verify.ps1 | Out-Null
    git commit -m "Initial fixture" | Out-Null
} finally {
    Pop-Location
}

Invoke-Required -Label "init" -Action {
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File $AiLoopScript -Command init -ProjectRoot $TempRoot
}
Invoke-Required -Label "start" -Action {
    $VerifyCommand = "& .\verify.ps1"
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File $AiLoopScript -Command start -ProjectRoot $TempRoot -PhaseId phase-001 -TaskKind fullstack -Title "Collect idempotence" -Objective "Verify repeated collect refreshes ledger rows." -VerifyCommand $VerifyCommand
}

Set-Content -LiteralPath (Join-Path $TempRoot ".ai-loop\runs\phase-001\report.md") -Encoding utf8 -Value "# Worker Report`n`nRepeated collect fixture."
Set-Content -LiteralPath (Join-Path $TempRoot "README.md") -Encoding utf8 -Value "# Collect idempotence fixture`n`nphase=complete"

Invoke-Required -Label "collect-1" -Action {
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File $AiLoopScript -Command collect -ProjectRoot $TempRoot -PhaseId phase-001 -Force
}
Invoke-Required -Label "collect-2" -Action {
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File $AiLoopScript -Command collect -ProjectRoot $TempRoot -PhaseId phase-001 -Force
}
Invoke-Required -Label "validate" -Action {
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File $AiLoopScript -Command validate -ProjectRoot $TempRoot -PhaseId phase-001
}

$EvidenceLedger = Join-Path $TempRoot ".ai-loop\evidence\evidence-ledger.md"
$ArtifactIndex = Join-Path $TempRoot ".ai-loop\evidence\artifact-index.md"
$CommandLog = Join-Path $TempRoot ".ai-loop\evidence\command-log.md"
$TestLog = Join-Path $TempRoot ".ai-loop\evidence\test-log.md"
$ProvenanceMap = Join-Path $TempRoot ".ai-loop\evidence\provenance-map.md"

foreach ($Check in @(
    @{ Path = $EvidenceLedger; Expected = 9; Name = "evidence ledger" },
    @{ Path = $ArtifactIndex; Expected = 9; Name = "artifact index" },
    @{ Path = $CommandLog; Expected = 1; Name = "command log" },
    @{ Path = $TestLog; Expected = 1; Name = "test log" },
    @{ Path = $ProvenanceMap; Expected = 1; Name = "provenance map" }
)) {
    $Count = Count-PhaseRows -Path $Check.Path -Phase "phase-001"
    if ($Count -ne $Check.Expected) {
        Add-Problem "$($Check.Name) should contain $($Check.Expected) phase rows after repeated collect; found $Count"
    }
}

if ($Problems.Count -gt 0) {
    Write-Output "Collect ledger idempotence test: FAILED"
    foreach ($Problem in $Problems) {
        Write-Output "- $Problem"
    }
    exit 2
}

Write-Output "Collect ledger idempotence test: OK"
Write-Output "Fixture root: $TempRoot"

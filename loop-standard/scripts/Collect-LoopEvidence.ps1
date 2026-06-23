[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PhaseId,
    [string]$TargetRoot = (Get-Location).Path,
    [string]$ReportPath = "",
    [string]$VerifyCommand = ""
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

$TargetRoot = (Resolve-Path -LiteralPath $TargetRoot).Path
$LoopDir = Join-Path $TargetRoot ".ai-loop"
$StatusPath = Join-Path $LoopDir "status.json"
$PhaseDir = Join-Path $LoopDir (Join-Path "evidence" $PhaseId)
if (-not (Test-Path -LiteralPath $StatusPath)) {
    throw "Missing .ai-loop/status.json. Run Initialize-AiLoop.ps1 first."
}
New-Item -ItemType Directory -Force -Path $PhaseDir | Out-Null

$WorkerReportPath = Join-Path $PhaseDir "report.md"
if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
    $ResolvedReport = (Resolve-Path -LiteralPath $ReportPath).Path
    Copy-Item -LiteralPath $ResolvedReport -Destination $WorkerReportPath -Force
} elseif (-not (Test-Path -LiteralPath $WorkerReportPath)) {
    "MISSING: no Kimi Worker report was supplied." | Set-Content -LiteralPath $WorkerReportPath -Encoding utf8
}

$VerifyLogPath = Join-Path $PhaseDir "verify.log"
if (-not [string]::IsNullOrWhiteSpace($VerifyCommand)) {
    Push-Location -LiteralPath $TargetRoot
    try {
        $Started = (Get-Date).ToUniversalTime().ToString("o")
        $Output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $VerifyCommand 2>&1
        $ExitCode = $LASTEXITCODE
        $Finished = (Get-Date).ToUniversalTime().ToString("o")
        @(
            "verify_command: $VerifyCommand"
            "started_at: $Started"
            "finished_at: $Finished"
            "exit_code: $ExitCode"
            ""
            "output:"
            ($Output | Out-String)
        ) | Set-Content -LiteralPath $VerifyLogPath -Encoding utf8
    } finally {
        Pop-Location
    }
} elseif (-not (Test-Path -LiteralPath $VerifyLogPath)) {
    "MISSING: no verification command was run." | Set-Content -LiteralPath $VerifyLogPath -Encoding utf8
}

$DiffPath = Join-Path $PhaseDir "diff.patch"
$RepoStatusPath = Join-Path $PhaseDir "status.txt"
$Git = Get-Command git -ErrorAction SilentlyContinue
if ($null -ne $Git) {
    $Inside = & git -C $TargetRoot rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -eq 0 -and $Inside -eq "true") {
        (& git -C $TargetRoot diff --binary -- . 2>&1 | Out-String) | Set-Content -LiteralPath $DiffPath -Encoding utf8
        (& git -C $TargetRoot status --short 2>&1 | Out-String) | Set-Content -LiteralPath $RepoStatusPath -Encoding utf8
    } else {
        "MISSING: target root is not a git repository, so no diff could be captured." | Set-Content -LiteralPath $DiffPath -Encoding utf8
        "MISSING: target root is not a git repository." | Set-Content -LiteralPath $RepoStatusPath -Encoding utf8
    }
} else {
    "MISSING: git executable was not found, so no diff could be captured." | Set-Content -LiteralPath $DiffPath -Encoding utf8
    "MISSING: git executable was not found." | Set-Content -LiteralPath $RepoStatusPath -Encoding utf8
}

$Status = Get-Content -LiteralPath $StatusPath -Raw | ConvertFrom-Json
if ($null -ne $Status.current_phase -and $Status.current_phase.phase_id -eq $PhaseId) {
    $Status.current_phase.phase_status = "evidence_collected"
    $Status.current_phase.evidence_collected_at = (Get-Date).ToUniversalTime().ToString("o")
}
Write-JsonFile -Value $Status -Path $StatusPath

Write-Output "Collected evidence in $PhaseDir"

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][string]$PhaseId,
    [string]$ReportPath = "",
    [string]$VerifyCommand = "",
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

function Set-JsonProperty {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        $Value
    )
    if ($null -ne $Object.PSObject.Properties[$Name]) {
        $Object.$Name = $Value
    } else {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    }
}

function Add-MarkdownRow {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string[]]$Columns
    )
    $Escaped = $Columns | ForEach-Object { ($_ -replace "\|", "/").Trim() }
    Add-Content -LiteralPath $Path -Encoding utf8 -Value ("| " + ($Escaped -join " | ") + " |")
}

function Get-VerifyExitCode {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return "" }
    $Text = Get-Content -LiteralPath $Path -Raw
    if ($Text -match "(?m)^exit_code:\s*(-?\d+)\s*$") {
        return $Matches[1]
    }
    return ""
}

$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$ProjectGitArgs = @("-c", "safe.directory=$($ProjectRoot.Replace('\', '/'))", "-c", "core.excludesFile=", "-c", "core.autocrlf=false", "-C", $ProjectRoot)
$LoopDir = Join-Path $ProjectRoot ".ai-loop"
$RunDir = Join-Path $LoopDir (Join-Path "runs" $PhaseId)
$StatusPath = Join-Path $LoopDir "status.json"
$MetaPath = Join-Path $RunDir "phase_meta.json"

if (-not (Test-Path -LiteralPath $MetaPath)) {
    throw "Missing phase metadata. Run start-phase.ps1 first: $MetaPath"
}

$ReportTarget = Join-Path $RunDir "report.md"
if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
    Copy-Item -LiteralPath (Resolve-Path -LiteralPath $ReportPath).Path -Destination $ReportTarget -Force
} elseif (-not (Test-Path -LiteralPath $ReportTarget)) {
    "MISSING: Worker report was not provided." | Set-Content -LiteralPath $ReportTarget -Encoding utf8
}

$Meta = Get-Content -LiteralPath $MetaPath -Raw | ConvertFrom-Json
if ($Meta.status -eq "accepted" -and -not $Force) {
    throw "Cannot collect evidence for accepted phase $PhaseId."
}
$CommandToRun = if (-not [string]::IsNullOrWhiteSpace($VerifyCommand)) { $VerifyCommand } else { $Meta.verify_command }
$VerifyLog = Join-Path $RunDir "verify.log"
if (-not [string]::IsNullOrWhiteSpace($CommandToRun)) {
    Push-Location -LiteralPath $ProjectRoot
    try {
        $Started = (Get-Date).ToUniversalTime().ToString("o")
        $Output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $CommandToRun 2>&1
        $ExitCode = $LASTEXITCODE
        $Finished = (Get-Date).ToUniversalTime().ToString("o")
        @(
            "verify_command: $CommandToRun"
            "started_at: $Started"
            "finished_at: $Finished"
            "exit_code: $ExitCode"
            ""
            "output:"
            ($Output | Out-String)
        ) | Set-Content -LiteralPath $VerifyLog -Encoding utf8
    } finally {
        Pop-Location
    }
} else {
    "MISSING: no verification command was provided." | Set-Content -LiteralPath $VerifyLog -Encoding utf8
}

$Git = Get-Command git -ErrorAction SilentlyContinue
$StatusAfterPath = Join-Path $RunDir "status_after.txt"
$DiffPath = Join-Path $RunDir "diff.patch"
$ChangedFilesPath = Join-Path $RunDir "changed_files.txt"
$ChangedBusinessFilesPath = Join-Path $RunDir "changed_business_files.txt"
$ChangedEvidenceFilesPath = Join-Path $RunDir "changed_evidence_files.txt"
if ($null -ne $Git) {
    $Inside = & git @ProjectGitArgs rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -eq 0 -and $Inside -eq "true") {
        (& git @ProjectGitArgs status --short 2>&1 | Out-String) | Set-Content -LiteralPath $StatusAfterPath -Encoding utf8
        $BaseCommit = (Get-Content -LiteralPath (Join-Path $RunDir "base_commit.txt") -Raw).Trim()
        if ($BaseCommit -notmatch "^MISSING:" -and -not [string]::IsNullOrWhiteSpace($BaseCommit)) {
            (& git @ProjectGitArgs diff --binary $BaseCommit -- . 2>&1 | Out-String) | Set-Content -LiteralPath $DiffPath -Encoding utf8
            $ChangedFiles = @(& git @ProjectGitArgs diff --name-only $BaseCommit -- . 2>&1 |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                Sort-Object -Unique)
        } else {
            (& git @ProjectGitArgs diff --binary -- . 2>&1 | Out-String) | Set-Content -LiteralPath $DiffPath -Encoding utf8
            $ChangedFiles = @(& git @ProjectGitArgs status --short 2>&1 |
                ForEach-Object { if ($_ -match "^\s*\S+\s+(.+)$") { $Matches[1] } } |
                Sort-Object -Unique)
        }
        ($ChangedFiles | Out-String) | Set-Content -LiteralPath $ChangedFilesPath -Encoding utf8
        ($ChangedFiles | Where-Object { $_ -notlike ".ai-loop/*" -and $_ -ne ".ai-loop/" } | Out-String) |
            Set-Content -LiteralPath $ChangedBusinessFilesPath -Encoding utf8
        ($ChangedFiles | Where-Object { $_ -like ".ai-loop/*" -or $_ -eq ".ai-loop/" } | Out-String) |
            Set-Content -LiteralPath $ChangedEvidenceFilesPath -Encoding utf8
    } else {
        "MISSING: target project is not a git repository." | Set-Content -LiteralPath $StatusAfterPath -Encoding utf8
        "MISSING: target project is not a git repository." | Set-Content -LiteralPath $DiffPath -Encoding utf8
        "MISSING: target project is not a git repository." | Set-Content -LiteralPath $ChangedFilesPath -Encoding utf8
        "MISSING: target project is not a git repository." | Set-Content -LiteralPath $ChangedBusinessFilesPath -Encoding utf8
        "MISSING: target project is not a git repository." | Set-Content -LiteralPath $ChangedEvidenceFilesPath -Encoding utf8
    }
} else {
    "MISSING: git executable was not found." | Set-Content -LiteralPath $StatusAfterPath -Encoding utf8
    "MISSING: git executable was not found." | Set-Content -LiteralPath $DiffPath -Encoding utf8
    "MISSING: git executable was not found." | Set-Content -LiteralPath $ChangedFilesPath -Encoding utf8
    "MISSING: git executable was not found." | Set-Content -LiteralPath $ChangedBusinessFilesPath -Encoding utf8
    "MISSING: git executable was not found." | Set-Content -LiteralPath $ChangedEvidenceFilesPath -Encoding utf8
}

Set-JsonProperty -Object $Meta -Name "status" -Value "evidence_collected"
Set-JsonProperty -Object $Meta -Name "evidence_collected_at" -Value (Get-Date).ToUniversalTime().ToString("o")
Write-JsonFile -Value $Meta -Path $MetaPath

if (Test-Path -LiteralPath $StatusPath) {
    $Status = Get-Content -LiteralPath $StatusPath -Raw | ConvertFrom-Json
    if ($null -ne $Status.current_phase -and $Status.current_phase.phase_id -eq $PhaseId) {
        Set-JsonProperty -Object $Status.current_phase -Name "status" -Value "evidence_collected"
        Set-JsonProperty -Object $Status.current_phase -Name "evidence_collected_at" -Value $Meta.evidence_collected_at
    }
    for ($Index = 0; $Index -lt @($Status.phases).Count; $Index++) {
        if ($Status.phases[$Index].phase_id -eq $PhaseId) {
            Set-JsonProperty -Object $Status.phases[$Index] -Name "status" -Value "evidence_collected"
            Set-JsonProperty -Object $Status.phases[$Index] -Name "evidence_collected_at" -Value $Meta.evidence_collected_at
        }
    }
    Write-JsonFile -Value $Status -Path $StatusPath
}

$EvidenceDir = Join-Path $LoopDir "evidence"
New-Item -ItemType Directory -Force -Path $EvidenceDir | Out-Null
$EvidenceLedger = Join-Path $EvidenceDir "evidence-ledger.md"
$ArtifactIndex = Join-Path $EvidenceDir "artifact-index.md"
$CommandLog = Join-Path $EvidenceDir "command-log.md"
$TestLog = Join-Path $EvidenceDir "test-log.md"
$ProvenanceMap = Join-Path $EvidenceDir "provenance-map.md"
$RelativeRunDir = ".ai-loop/runs/$PhaseId"
$EvidenceRows = @(
    @("EVD-$PhaseId-003", $PhaseId, "CLAIM-$PhaseId", "worker-report", "$RelativeRunDir/report.md", "Worker", "pending", "recorded", "Worker report captured."),
    @("EVD-$PhaseId-004", $PhaseId, "CLAIM-$PhaseId", "status", "$RelativeRunDir/status_after.txt", "collect-evidence.ps1", "pending", "recorded", "Repository status captured after Worker execution."),
    @("EVD-$PhaseId-005", $PhaseId, "CLAIM-$PhaseId", "diff", "$RelativeRunDir/diff.patch", "collect-evidence.ps1", "pending", "recorded", "Diff captured."),
    @("EVD-$PhaseId-006", $PhaseId, "CLAIM-$PhaseId", "verification-log", "$RelativeRunDir/verify.log", "collect-evidence.ps1", "pending", "recorded", "Verification log captured."),
    @("EVD-$PhaseId-007", $PhaseId, "CLAIM-$PhaseId", "changed-files", "$RelativeRunDir/changed_files.txt", "collect-evidence.ps1", "pending", "recorded", "Changed files captured."),
    @("EVD-$PhaseId-008", $PhaseId, "CLAIM-$PhaseId", "business-files", "$RelativeRunDir/changed_business_files.txt", "collect-evidence.ps1", "pending", "recorded", "Changed business files captured."),
    @("EVD-$PhaseId-009", $PhaseId, "CLAIM-$PhaseId", "evidence-files", "$RelativeRunDir/changed_evidence_files.txt", "collect-evidence.ps1", "pending", "recorded", "Changed evidence files captured.")
)
if (Test-Path -LiteralPath $EvidenceLedger) {
    foreach ($Row in $EvidenceRows) { Add-MarkdownRow -Path $EvidenceLedger -Columns $Row }
}
if (Test-Path -LiteralPath $ArtifactIndex) {
    foreach ($Name in @("report.md", "status_after.txt", "diff.patch", "verify.log", "changed_files.txt", "changed_business_files.txt", "changed_evidence_files.txt")) {
        Add-MarkdownRow -Path $ArtifactIndex -Columns @("ART-$PhaseId-$Name", $PhaseId, "phase-evidence", "$RelativeRunDir/$Name", "collect-evidence.ps1", "active", "Phase evidence artifact.")
    }
}
if (Test-Path -LiteralPath $CommandLog) {
    $ExitCode = Get-VerifyExitCode -Path $VerifyLog
    $CommandStatus = if ($ExitCode -eq "0") { "passed" } elseif ([string]::IsNullOrWhiteSpace($ExitCode)) { "unknown" } else { "failed" }
    Add-MarkdownRow -Path $CommandLog -Columns @("CMD-$PhaseId-VERIFY", $PhaseId, "verification", $CommandToRun, $ExitCode, "$RelativeRunDir/verify.log", $CommandStatus, "Verification command executed by collect-evidence.ps1.")
}
if (Test-Path -LiteralPath $TestLog) {
    $ExitCode = Get-VerifyExitCode -Path $VerifyLog
    $TestStatus = if ($ExitCode -eq "0") { "passed" } elseif ([string]::IsNullOrWhiteSpace($ExitCode)) { "unknown" } else { "failed" }
    Add-MarkdownRow -Path $TestLog -Columns @("TEST-$PhaseId-VERIFY", $PhaseId, $CommandToRun, "$RelativeRunDir/verify.log", $ExitCode, $TestStatus, "Primary phase verification.")
}
if (Test-Path -LiteralPath $ProvenanceMap) {
    Add-MarkdownRow -Path $ProvenanceMap -Columns @("PROV-$PhaseId-DIFF", $PhaseId, "$RelativeRunDir/diff.patch", "$RelativeRunDir/base_commit.txt; $RelativeRunDir/status_after.txt", "git diff", "base commit recorded", "recorded", "Diff provenance for phase audit.")
}

Write-Output "Collected evidence for $PhaseId in $RunDir"

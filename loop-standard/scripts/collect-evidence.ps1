[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][string]$PhaseId,
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

$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$ProjectGitArgs = @("-c", "safe.directory=$($ProjectRoot.Replace('\', '/'))", "-c", "core.excludesFile=", "-C", $ProjectRoot)
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
    "MISSING: Kimi Worker report was not provided." | Set-Content -LiteralPath $ReportTarget -Encoding utf8
}

$Meta = Get-Content -LiteralPath $MetaPath -Raw | ConvertFrom-Json
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
if ($null -ne $Git) {
    $Inside = & git @ProjectGitArgs rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -eq 0 -and $Inside -eq "true") {
        (& git @ProjectGitArgs status --short 2>&1 | Out-String) | Set-Content -LiteralPath $StatusAfterPath -Encoding utf8
        $BaseCommit = (Get-Content -LiteralPath (Join-Path $RunDir "base_commit.txt") -Raw).Trim()
        if ($BaseCommit -notmatch "^MISSING:" -and -not [string]::IsNullOrWhiteSpace($BaseCommit)) {
            (& git @ProjectGitArgs diff --binary $BaseCommit -- . 2>&1 | Out-String) | Set-Content -LiteralPath $DiffPath -Encoding utf8
        } else {
            (& git @ProjectGitArgs diff --binary -- . 2>&1 | Out-String) | Set-Content -LiteralPath $DiffPath -Encoding utf8
        }
        (& git @ProjectGitArgs status --short 2>&1 |
            ForEach-Object { if ($_ -match "^\s*\S+\s+(.+)$") { $Matches[1] } } |
            Sort-Object -Unique |
            Out-String) | Set-Content -LiteralPath $ChangedFilesPath -Encoding utf8
    } else {
        "MISSING: target project is not a git repository." | Set-Content -LiteralPath $StatusAfterPath -Encoding utf8
        "MISSING: target project is not a git repository." | Set-Content -LiteralPath $DiffPath -Encoding utf8
        "MISSING: target project is not a git repository." | Set-Content -LiteralPath $ChangedFilesPath -Encoding utf8
    }
} else {
    "MISSING: git executable was not found." | Set-Content -LiteralPath $StatusAfterPath -Encoding utf8
    "MISSING: git executable was not found." | Set-Content -LiteralPath $DiffPath -Encoding utf8
    "MISSING: git executable was not found." | Set-Content -LiteralPath $ChangedFilesPath -Encoding utf8
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

Write-Output "Collected evidence for $PhaseId in $RunDir"

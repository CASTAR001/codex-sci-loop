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

function Remove-MarkdownRowsForPhase {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Phase
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return }
    $Lines = @(Get-Content -LiteralPath $Path)
    $Filtered = @($Lines | Where-Object { $_ -notlike "*| $Phase |*" })
    Set-Content -LiteralPath $Path -Encoding utf8 -Value $Filtered
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

function ConvertTo-RelativeArtifactPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return ($Path -replace "\\", "/").Trim()
}

function New-ArtifactRecord {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [Parameter(Mandatory = $true)][string]$Phase,
        [Parameter(Mandatory = $true)][string]$ArtifactId,
        [Parameter(Mandatory = $true)][string]$Type,
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$ProducedBy
    )
    $NormalizedPath = ConvertTo-RelativeArtifactPath -Path $RelativePath
    $AbsolutePath = Join-Path $ProjectRoot ($NormalizedPath -replace "/", "\")
    $Status = "recorded"
    $Sha256 = ""
    $SizeBytes = 0
    $ModifiedUtc = ""
    $Notes = "ok"
    if (-not (Test-Path -LiteralPath $AbsolutePath -PathType Leaf)) {
        $Status = "missing"
        $Notes = "file missing"
    } else {
        $Item = Get-Item -LiteralPath $AbsolutePath
        $SizeBytes = [int64]$Item.Length
        $ModifiedUtc = $Item.LastWriteTimeUtc.ToString("o")
        if ($Item.Length -eq 0) {
            $Status = "invalid"
            $Notes = "file empty"
        } else {
            $Text = Get-Content -LiteralPath $AbsolutePath -Raw -ErrorAction SilentlyContinue
            if ($Text -match "(?m)^\s*MISSING:") {
                $Status = "invalid"
                $Notes = "contains MISSING placeholder"
            }
            $Sha256 = (Get-FileHash -LiteralPath $AbsolutePath -Algorithm SHA256).Hash
        }
    }
    return [pscustomobject][ordered]@{
        artifact_id = $ArtifactId
        phase = $Phase
        type = $Type
        path = $NormalizedPath
        sha256 = $Sha256
        size_bytes = $SizeBytes
        modified_utc = $ModifiedUtc
        produced_by = $ProducedBy
        status = $Status
        recorded_at = (Get-Date).ToUniversalTime().ToString("o")
        notes = $Notes
    }
}

function Write-ArtifactManifest {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][object[]]$Records
    )
    $Manifest = [pscustomobject][ordered]@{
        schema_version = "1.0"
        artifacts = @()
    }
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        try {
            $Manifest = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
            if ($null -eq $Manifest.PSObject.Properties["artifacts"]) {
                $Manifest | Add-Member -NotePropertyName "artifacts" -NotePropertyValue @()
            }
        } catch {
            $Manifest = [pscustomobject][ordered]@{
                schema_version = "1.0"
                artifacts = @()
            }
        }
    }
    $Remaining = @($Manifest.artifacts | Where-Object {
        $Existing = $_
        -not (@($Records | Where-Object { $_.phase -eq $Existing.phase -and $_.path -eq $Existing.path }).Count -gt 0)
    })
    $Manifest.artifacts = @($Remaining + $Records)
    Write-JsonFile -Value $Manifest -Path $Path
}

function Get-ShortHash {
    param([AllowNull()][string]$Hash)
    if ([string]::IsNullOrWhiteSpace($Hash)) { return "n/a" }
    if ($Hash.Length -le 12) { return $Hash }
    return $Hash.Substring(0, 12)
}

function ConvertTo-ArtifactIdPart {
    param([Parameter(Mandatory = $true)][string]$Value)
    return (($Value -replace "[^A-Za-z0-9._-]", "-") -replace "-+", "-").Trim("-")
}

function ConvertTo-ProjectRelativeGitPath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [AllowNull()][string]$Prefix
    )
    $NormalizedPath = ($Path -replace "\\", "/").Trim()
    $PrefixValue = if ($null -eq $Prefix) { "" } else { $Prefix }
    $NormalizedPrefix = ($PrefixValue -replace "\\", "/").Trim()
    if ([string]::IsNullOrWhiteSpace($NormalizedPrefix)) {
        return $NormalizedPath
    }
    if (-not $NormalizedPrefix.EndsWith("/")) {
        $NormalizedPrefix = "$NormalizedPrefix/"
    }
    if ($NormalizedPath.StartsWith($NormalizedPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $NormalizedPath.Substring($NormalizedPrefix.Length)
    }
    return $NormalizedPath
}

function ConvertFrom-GitStatusLine {
    param([Parameter(Mandatory = $true)][string]$Line)
    if ($Line.Length -lt 4) { return "" }
    $Path = $Line.Substring(3).Trim()
    if ($Path -match " -> ") {
        $Path = ($Path -split " -> ")[-1].Trim()
    }
    return $Path.Trim('"')
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
$PreviousStatusForTransition = [string]$Meta.status
if ($Meta.status -eq "accepted" -and -not $Force) {
    throw "Cannot collect evidence for accepted phase $PhaseId."
}
$CommandToRun = if (-not [string]::IsNullOrWhiteSpace($VerifyCommand)) { $VerifyCommand } else { $Meta.verify_command }
$VerifyLog = Join-Path $RunDir "verify.log"
if (-not [string]::IsNullOrWhiteSpace($CommandToRun)) {
    Push-Location -LiteralPath $ProjectRoot
    try {
        $Started = (Get-Date).ToUniversalTime().ToString("o")
        $PreviousErrorActionPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = "Continue"
            $Output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $CommandToRun 2>&1
            $ExitCode = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $PreviousErrorActionPreference
        }
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
        $GitPrefixOutput = & git @ProjectGitArgs rev-parse --show-prefix 2>$null
        $GitPrefix = if ($LASTEXITCODE -eq 0) { ($GitPrefixOutput | Out-String).Trim() } else { "" }
        (& git @ProjectGitArgs status --short 2>&1 | Out-String) | Set-Content -LiteralPath $StatusAfterPath -Encoding utf8
        $BaseCommit = (Get-Content -LiteralPath (Join-Path $RunDir "base_commit.txt") -Raw).Trim()
        if ($BaseCommit -notmatch "^MISSING:" -and -not [string]::IsNullOrWhiteSpace($BaseCommit)) {
            (& git @ProjectGitArgs diff --binary $BaseCommit -- . 2>&1 | Out-String) | Set-Content -LiteralPath $DiffPath -Encoding utf8
            $DiffChangedFiles = @(& git @ProjectGitArgs diff --name-only $BaseCommit -- . 2>&1 |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                Sort-Object -Unique)
            $StatusChangedFiles = @(& git @ProjectGitArgs status --porcelain --untracked-files=all -- . 2>&1 |
                ForEach-Object { ConvertFrom-GitStatusLine -Line $_ } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                Sort-Object -Unique)
            $ChangedFiles = @($DiffChangedFiles + $StatusChangedFiles | Sort-Object -Unique)
        } else {
            (& git @ProjectGitArgs diff --binary -- . 2>&1 | Out-String) | Set-Content -LiteralPath $DiffPath -Encoding utf8
            $ChangedFiles = @(& git @ProjectGitArgs status --porcelain --untracked-files=all -- . 2>&1 |
                ForEach-Object { ConvertFrom-GitStatusLine -Line $_ } |
                Sort-Object -Unique)
        }
        $ChangedFiles = @($ChangedFiles |
            ForEach-Object { ConvertTo-ProjectRelativeGitPath -Path $_ -Prefix $GitPrefix } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique)
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
Set-JsonProperty -Object $Meta -Name "transition_log" -Value ".ai-loop/events/state-transitions.ndjson"
Write-JsonFile -Value $Meta -Path $MetaPath

if (Test-Path -LiteralPath $StatusPath) {
    $Status = Get-Content -LiteralPath $StatusPath -Raw | ConvertFrom-Json
    if ($null -ne $Status.current_phase -and $Status.current_phase.phase_id -eq $PhaseId) {
        Set-JsonProperty -Object $Status.current_phase -Name "status" -Value "evidence_collected"
        Set-JsonProperty -Object $Status.current_phase -Name "evidence_collected_at" -Value $Meta.evidence_collected_at
        Set-JsonProperty -Object $Status.current_phase -Name "transition_log" -Value ".ai-loop/events/state-transitions.ndjson"
    }
    for ($Index = 0; $Index -lt @($Status.phases).Count; $Index++) {
        if ($Status.phases[$Index].phase_id -eq $PhaseId) {
            Set-JsonProperty -Object $Status.phases[$Index] -Name "status" -Value "evidence_collected"
            Set-JsonProperty -Object $Status.phases[$Index] -Name "evidence_collected_at" -Value $Meta.evidence_collected_at
            Set-JsonProperty -Object $Status.phases[$Index] -Name "transition_log" -Value ".ai-loop/events/state-transitions.ndjson"
        }
    }
    Write-JsonFile -Value $Status -Path $StatusPath
}
& (Join-Path $PSScriptRoot "record-state-transition.ps1") `
    -ProjectRoot $ProjectRoot `
    -PhaseId $PhaseId `
    -FromStatus $PreviousStatusForTransition `
    -ToStatus "evidence_collected" `
    -Actor "collect-evidence.ps1" `
    -Action "collect" `
    -Reason "Collected phase evidence." `
    -Paths @(".ai-loop/status.json", ".ai-loop/runs/$PhaseId/phase_meta.json", ".ai-loop/events/state-transitions.ndjson")

$EvidenceDir = Join-Path $LoopDir "evidence"
New-Item -ItemType Directory -Force -Path $EvidenceDir | Out-Null
$EvidenceLedger = Join-Path $EvidenceDir "evidence-ledger.md"
$ArtifactManifest = Join-Path $EvidenceDir "artifact-manifest.json"
$ArtifactIndex = Join-Path $EvidenceDir "artifact-index.md"
$CommandLog = Join-Path $EvidenceDir "command-log.md"
$TestLog = Join-Path $EvidenceDir "test-log.md"
$ProvenanceMap = Join-Path $EvidenceDir "provenance-map.md"
$RelativeRunDir = ".ai-loop/runs/$PhaseId"
$RequirementsPath = Join-Path $RunDir "phase_requirements.json"
$Requirements = $null
if (Test-Path -LiteralPath $RequirementsPath -PathType Leaf) {
    try {
        $Requirements = Get-Content -LiteralPath $RequirementsPath -Raw | ConvertFrom-Json
    } catch {
        $Requirements = $null
    }
}
foreach ($LedgerPath in @($EvidenceLedger, $ArtifactIndex, $CommandLog, $TestLog, $ProvenanceMap)) {
    Remove-MarkdownRowsForPhase -Path $LedgerPath -Phase $PhaseId
}
$EvidenceRows = @(
    @("EVD-$PhaseId-001", $PhaseId, "CLAIM-$PhaseId", "prompt", "$RelativeRunDir/prompt.md", "Codex Supervisor", "pending", "recorded", "Worker prompt generated."),
    @("EVD-$PhaseId-002", $PhaseId, "CLAIM-$PhaseId", "requirements", "$RelativeRunDir/phase_requirements.json", "Codex Supervisor", "pending", "recorded", "Phase requirements generated."),
    @("EVD-$PhaseId-003", $PhaseId, "CLAIM-$PhaseId", "worker-report", "$RelativeRunDir/report.md", "Worker", "pending", "recorded", "Worker report captured."),
    @("EVD-$PhaseId-004", $PhaseId, "CLAIM-$PhaseId", "status", "$RelativeRunDir/status_after.txt", "collect-evidence.ps1", "pending", "recorded", "Repository status captured after Worker execution."),
    @("EVD-$PhaseId-005", $PhaseId, "CLAIM-$PhaseId", "diff", "$RelativeRunDir/diff.patch", "collect-evidence.ps1", "pending", "recorded", "Diff captured."),
    @("EVD-$PhaseId-006", $PhaseId, "CLAIM-$PhaseId", "verification-log", "$RelativeRunDir/verify.log", "collect-evidence.ps1", "pending", "recorded", "Verification log captured."),
    @("EVD-$PhaseId-007", $PhaseId, "CLAIM-$PhaseId", "changed-files", "$RelativeRunDir/changed_files.txt", "collect-evidence.ps1", "pending", "recorded", "Changed files captured."),
    @("EVD-$PhaseId-008", $PhaseId, "CLAIM-$PhaseId", "business-files", "$RelativeRunDir/changed_business_files.txt", "collect-evidence.ps1", "pending", "recorded", "Changed business files captured."),
    @("EVD-$PhaseId-009", $PhaseId, "CLAIM-$PhaseId", "evidence-files", "$RelativeRunDir/changed_evidence_files.txt", "collect-evidence.ps1", "pending", "recorded", "Changed evidence files captured.")
)
$KnownEvidencePaths = New-Object System.Collections.Generic.List[string]
foreach ($Row in $EvidenceRows) {
    $KnownEvidencePaths.Add((ConvertTo-RelativeArtifactPath -Path ([string]$Row[4])))
}
$AdditionalRequiredEvidencePaths = New-Object System.Collections.Generic.List[string]
if ($null -ne $Requirements -and $null -ne $Requirements.PSObject.Properties["evidence_required"]) {
    foreach ($RequiredPath in @($Requirements.evidence_required)) {
        $ArtifactPath = ConvertTo-RelativeArtifactPath -Path ([string]$RequiredPath)
        if ([string]::IsNullOrWhiteSpace($ArtifactPath)) { continue }
        if ($KnownEvidencePaths -contains $ArtifactPath) { continue }
        $KnownEvidencePaths.Add($ArtifactPath)
        $AdditionalRequiredEvidencePaths.Add($ArtifactPath)
        $EvidenceType = if ($ArtifactPath -like "*external-worker-*") { "external-worker-evidence" } else { "required-evidence" }
        $Producer = if ($ArtifactPath -like "*external-worker-preflight*") {
            "preflight-worker.ps1"
        } elseif ($ArtifactPath -like "*external-worker-invocation*") {
            "invoke-worker.ps1"
        } else {
            "phase requirements"
        }
        $EvidenceRows += ,@("EVD-$PhaseId-REQ-$($AdditionalRequiredEvidencePaths.Count)", $PhaseId, "CLAIM-$PhaseId", $EvidenceType, $ArtifactPath, $Producer, "pending", "recorded", "Additional required evidence from phase_requirements.json.")
    }
}
if (Test-Path -LiteralPath $EvidenceLedger) {
    foreach ($Row in $EvidenceRows) { Add-MarkdownRow -Path $EvidenceLedger -Columns $Row }
}
if (Test-Path -LiteralPath $ArtifactIndex) {
    foreach ($Name in @("prompt.md", "phase_requirements.json", "report.md", "status_after.txt", "diff.patch", "verify.log", "changed_files.txt", "changed_business_files.txt", "changed_evidence_files.txt")) {
        $ArtifactPath = "$RelativeRunDir/$Name"
        $Producer = if ($Name -in @("prompt.md", "phase_requirements.json")) { "start-phase.ps1" } elseif ($Name -eq "report.md") { "Worker" } else { "collect-evidence.ps1" }
        $Record = New-ArtifactRecord -ProjectRoot $ProjectRoot -Phase $PhaseId -ArtifactId "ART-$PhaseId-$Name" -Type "phase-evidence" -RelativePath $ArtifactPath -ProducedBy $Producer
        $Notes = "sha256=$(Get-ShortHash -Hash $Record.sha256); size=$($Record.size_bytes); status=$($Record.status)"
        Add-MarkdownRow -Path $ArtifactIndex -Columns @("ART-$PhaseId-$Name", $PhaseId, "phase-evidence", $ArtifactPath, $Producer, $Record.status, $Notes)
    }
    foreach ($ArtifactPath in @($AdditionalRequiredEvidencePaths)) {
        $Producer = if ($ArtifactPath -like "*external-worker-preflight*") {
            "preflight-worker.ps1"
        } elseif ($ArtifactPath -like "*external-worker-invocation*") {
            "invoke-worker.ps1"
        } else {
            "phase requirements"
        }
        $ArtifactType = if ($ArtifactPath -like "*external-worker-*") { "external-worker-evidence" } else { "phase-evidence" }
        $ArtifactId = "ART-$PhaseId-required-$(ConvertTo-ArtifactIdPart -Value $ArtifactPath)"
        $Record = New-ArtifactRecord -ProjectRoot $ProjectRoot -Phase $PhaseId -ArtifactId $ArtifactId -Type $ArtifactType -RelativePath $ArtifactPath -ProducedBy $Producer
        $Notes = "sha256=$(Get-ShortHash -Hash $Record.sha256); size=$($Record.size_bytes); status=$($Record.status)"
        Add-MarkdownRow -Path $ArtifactIndex -Columns @($ArtifactId, $PhaseId, $ArtifactType, $ArtifactPath, $Producer, $Record.status, $Notes)
    }
    if ($null -ne $Requirements -and $null -ne $Requirements.PSObject.Properties["required_skill_artifacts"]) {
        foreach ($Requirement in @($Requirements.required_skill_artifacts)) {
            $Skill = [string]$Requirement.skill
            if ([string]::IsNullOrWhiteSpace($Skill)) { continue }
            foreach ($Artifact in @($Requirement.artifacts)) {
                $ArtifactPath = ConvertTo-RelativeArtifactPath -Path ([string]$Artifact)
                if ([string]::IsNullOrWhiteSpace($ArtifactPath)) { continue }
                $ArtifactId = "ART-$PhaseId-skill-$(ConvertTo-ArtifactIdPart -Value $Skill)-$(ConvertTo-ArtifactIdPart -Value $ArtifactPath)"
                $Record = New-ArtifactRecord -ProjectRoot $ProjectRoot -Phase $PhaseId -ArtifactId $ArtifactId -Type "skill-artifact" -RelativePath $ArtifactPath -ProducedBy $Skill
                $Notes = "sha256=$(Get-ShortHash -Hash $Record.sha256); size=$($Record.size_bytes); status=$($Record.status)"
                Add-MarkdownRow -Path $ArtifactIndex -Columns @($ArtifactId, $PhaseId, "skill-artifact", $ArtifactPath, $Skill, $Record.status, $Notes)
            }
        }
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

$ManifestRecords = @(
    New-ArtifactRecord -ProjectRoot $ProjectRoot -Phase $PhaseId -ArtifactId "ART-$PhaseId-prompt.md" -Type "phase-evidence" -RelativePath "$RelativeRunDir/prompt.md" -ProducedBy "start-phase.ps1"
    New-ArtifactRecord -ProjectRoot $ProjectRoot -Phase $PhaseId -ArtifactId "ART-$PhaseId-phase_requirements.json" -Type "phase-evidence" -RelativePath "$RelativeRunDir/phase_requirements.json" -ProducedBy "start-phase.ps1"
    New-ArtifactRecord -ProjectRoot $ProjectRoot -Phase $PhaseId -ArtifactId "ART-$PhaseId-report.md" -Type "phase-evidence" -RelativePath "$RelativeRunDir/report.md" -ProducedBy "Worker"
    New-ArtifactRecord -ProjectRoot $ProjectRoot -Phase $PhaseId -ArtifactId "ART-$PhaseId-status_after.txt" -Type "phase-evidence" -RelativePath "$RelativeRunDir/status_after.txt" -ProducedBy "collect-evidence.ps1"
    New-ArtifactRecord -ProjectRoot $ProjectRoot -Phase $PhaseId -ArtifactId "ART-$PhaseId-diff.patch" -Type "phase-evidence" -RelativePath "$RelativeRunDir/diff.patch" -ProducedBy "collect-evidence.ps1"
    New-ArtifactRecord -ProjectRoot $ProjectRoot -Phase $PhaseId -ArtifactId "ART-$PhaseId-verify.log" -Type "phase-evidence" -RelativePath "$RelativeRunDir/verify.log" -ProducedBy "collect-evidence.ps1"
    New-ArtifactRecord -ProjectRoot $ProjectRoot -Phase $PhaseId -ArtifactId "ART-$PhaseId-changed_files.txt" -Type "phase-evidence" -RelativePath "$RelativeRunDir/changed_files.txt" -ProducedBy "collect-evidence.ps1"
    New-ArtifactRecord -ProjectRoot $ProjectRoot -Phase $PhaseId -ArtifactId "ART-$PhaseId-changed_business_files.txt" -Type "phase-evidence" -RelativePath "$RelativeRunDir/changed_business_files.txt" -ProducedBy "collect-evidence.ps1"
    New-ArtifactRecord -ProjectRoot $ProjectRoot -Phase $PhaseId -ArtifactId "ART-$PhaseId-changed_evidence_files.txt" -Type "phase-evidence" -RelativePath "$RelativeRunDir/changed_evidence_files.txt" -ProducedBy "collect-evidence.ps1"
)
foreach ($ArtifactPath in @($AdditionalRequiredEvidencePaths)) {
    $Producer = if ($ArtifactPath -like "*external-worker-preflight*") {
        "preflight-worker.ps1"
    } elseif ($ArtifactPath -like "*external-worker-invocation*") {
        "invoke-worker.ps1"
    } else {
        "phase requirements"
    }
    $ArtifactType = if ($ArtifactPath -like "*external-worker-*") { "external-worker-evidence" } else { "phase-evidence" }
    $ArtifactId = "ART-$PhaseId-required-$(ConvertTo-ArtifactIdPart -Value $ArtifactPath)"
    $ManifestRecords += New-ArtifactRecord -ProjectRoot $ProjectRoot -Phase $PhaseId -ArtifactId $ArtifactId -Type $ArtifactType -RelativePath $ArtifactPath -ProducedBy $Producer
}
if ($null -ne $Requirements -and $null -ne $Requirements.PSObject.Properties["required_skill_artifacts"]) {
    foreach ($Requirement in @($Requirements.required_skill_artifacts)) {
        $Skill = [string]$Requirement.skill
        if ([string]::IsNullOrWhiteSpace($Skill)) { continue }
        foreach ($Artifact in @($Requirement.artifacts)) {
            $ArtifactPath = ConvertTo-RelativeArtifactPath -Path ([string]$Artifact)
            if ([string]::IsNullOrWhiteSpace($ArtifactPath)) { continue }
            $ArtifactId = "ART-$PhaseId-skill-$(ConvertTo-ArtifactIdPart -Value $Skill)-$(ConvertTo-ArtifactIdPart -Value $ArtifactPath)"
            $ManifestRecords += New-ArtifactRecord -ProjectRoot $ProjectRoot -Phase $PhaseId -ArtifactId $ArtifactId -Type "skill-artifact" -RelativePath $ArtifactPath -ProducedBy $Skill
        }
    }
}
Write-ArtifactManifest -Path $ArtifactManifest -Records $ManifestRecords

Write-Output "Collected evidence for $PhaseId in $RunDir"

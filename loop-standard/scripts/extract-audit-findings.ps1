[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][string]$PhaseId,
    [string]$AuditPath = "",
    [string]$OutputPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function ConvertTo-NormalizedPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return ($Path -replace "\\", "/").Trim()
}

function Write-JsonFile {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string]$Path
    )
    $Value | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $Path -Encoding utf8
}

function New-Finding {
    param(
        [Parameter(Mandatory = $true)][int]$Index,
        [Parameter(Mandatory = $true)][string]$Summary,
        [string]$Severity = "",
        [string]$RequiredFix = "",
        [string[]]$Evidence = @(),
        [string[]]$Files = @(),
        [string[]]$SourceLines = @()
    )
    $SeverityValue = if ([string]::IsNullOrWhiteSpace($Severity)) { "unspecified" } else { $Severity.Trim() }
    return [pscustomobject][ordered]@{
        finding_id = ("F-{0:D3}" -f $Index)
        severity = $SeverityValue
        summary = $Summary.Trim()
        required_fix = $RequiredFix.Trim()
        evidence = @($Evidence | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        files = @($Files | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        source_lines = @($SourceLines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        status = "open"
    }
}

function Split-ListValue {
    param([AllowNull()][string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return @() }
    return @($Value -split "\s*[,;]\s*" | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$LoopDir = Join-Path $ProjectRoot ".ai-loop"
$AuditDir = Join-Path $LoopDir "audits"
if ([string]::IsNullOrWhiteSpace($AuditPath)) {
    $AuditPath = Join-Path $AuditDir "$PhaseId-audit.md"
}
$AuditPath = (Resolve-Path -LiteralPath $AuditPath).Path
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $AuditDir "$PhaseId-findings.json"
}

$AuditText = Get-Content -LiteralPath $AuditPath -Raw
$Decision = "UNKNOWN"
if ($AuditText -match "(?m)^\s*Decision:\s*(ACCEPTED|REWORK|BLOCKED)\s*$") {
    $Decision = $Matches[1].ToUpperInvariant()
}

$script:Findings = New-Object System.Collections.Generic.List[object]
$script:CurrentSummary = ""
$script:CurrentSeverity = ""
$script:CurrentRequiredFix = ""
$script:CurrentEvidence = New-Object System.Collections.Generic.List[string]
$script:CurrentFiles = New-Object System.Collections.Generic.List[string]
$script:CurrentSourceLines = New-Object System.Collections.Generic.List[string]

function Flush-CurrentFinding {
    if ([string]::IsNullOrWhiteSpace($script:CurrentSummary)) { return }
    $script:Findings.Add((New-Finding `
        -Index ($script:Findings.Count + 1) `
        -Summary $script:CurrentSummary `
        -Severity $script:CurrentSeverity `
        -RequiredFix $script:CurrentRequiredFix `
        -Evidence @($script:CurrentEvidence) `
        -Files @($script:CurrentFiles) `
        -SourceLines @($script:CurrentSourceLines)))
    $script:CurrentSummary = ""
    $script:CurrentSeverity = ""
    $script:CurrentRequiredFix = ""
    $script:CurrentEvidence = New-Object System.Collections.Generic.List[string]
    $script:CurrentFiles = New-Object System.Collections.Generic.List[string]
    $script:CurrentSourceLines = New-Object System.Collections.Generic.List[string]
}

$LineNumber = 0
foreach ($RawLine in @($AuditText -split "`r?`n")) {
    $LineNumber++
    $Line = $RawLine.Trim()
    if ([string]::IsNullOrWhiteSpace($Line)) { continue }
    if ($Line -match "^(?:[-*]\s*)?Finding\s*:\s*(.+)$") {
        Flush-CurrentFinding
        $CurrentSummary = $Matches[1].Trim()
        $CurrentSourceLines.Add("L${LineNumber}: $Line")
        continue
    }
    if ($Line -match "^(?:[-*]\s*)?Severity\s*:\s*(.+)$") {
        $CurrentSeverity = $Matches[1].Trim()
        $CurrentSourceLines.Add("L${LineNumber}: $Line")
        continue
    }
    if ($Line -match "^(?:[-*]\s*)?(?:Required fix|Fix|Action)\s*:\s*(.+)$") {
        $CurrentRequiredFix = $Matches[1].Trim()
        $CurrentSourceLines.Add("L${LineNumber}: $Line")
        continue
    }
    if ($Line -match "^(?:[-*]\s*)?Evidence\s*:\s*(.+)$") {
        foreach ($Item in @(Split-ListValue -Value $Matches[1])) {
            $CurrentEvidence.Add($Item)
        }
        $CurrentSourceLines.Add("L${LineNumber}: $Line")
        continue
    }
    if ($Line -match "^(?:[-*]\s*)?(?:File|Files|Path|Paths)\s*:\s*(.+)$") {
        foreach ($Item in @(Split-ListValue -Value $Matches[1])) {
            $CurrentFiles.Add($Item)
        }
        $CurrentSourceLines.Add("L${LineNumber}: $Line")
        continue
    }
}
Flush-CurrentFinding

$RelativeAudit = ConvertTo-NormalizedPath -Path ($AuditPath.Substring($ProjectRoot.Length).TrimStart("\", "/"))
$RelativeOutput = ConvertTo-NormalizedPath -Path ($OutputPath.Substring($ProjectRoot.Length).TrimStart("\", "/"))
$Notes = ""
if ($script:Findings.Count -eq 0) {
    $Notes = "No structured 'Finding:' entries were found. Legacy prose fallback may still be used by scaffold-rework."
} else {
    $Notes = "Structured findings extracted from audit result."
}
$FindingsArray = @()
foreach ($Finding in $script:Findings) {
    $FindingsArray += $Finding
}
$Result = [pscustomobject][ordered]@{
    schema_version = "1.0"
    phase_id = $PhaseId
    decision = $Decision
    audit_path = $RelativeAudit
    findings_path = $RelativeOutput
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    finding_count = $script:Findings.Count
    findings = @($FindingsArray)
    parser = "extract-audit-findings.ps1"
    notes = $Notes
}

Write-JsonFile -Value $Result -Path $OutputPath
Write-Output "Extracted $($script:Findings.Count) audit finding(s): $OutputPath"

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PhaseId,
    [string]$TargetRoot = (Get-Location).Path
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
$ConfigPath = Join-Path $LoopDir "loop.config.json"
$PhaseDir = Join-Path $LoopDir (Join-Path "evidence" $PhaseId)
$AuditDir = Join-Path $LoopDir (Join-Path "audits" $PhaseId)

if (-not (Test-Path -LiteralPath $StatusPath)) {
    throw "Missing .ai-loop/status.json. Run Initialize-AiLoop.ps1 first."
}

New-Item -ItemType Directory -Force -Path $AuditDir | Out-Null

$Required = @("prompt.md", "report.md", "diff.patch", "verify.log", "status.txt")
$Missing = New-Object System.Collections.Generic.List[string]
foreach ($Name in $Required) {
    $Path = Join-Path $PhaseDir $Name
    if (-not (Test-Path -LiteralPath $Path)) {
        $Missing.Add($Name)
        continue
    }
    $FirstText = Get-Content -LiteralPath $Path -Raw
    if ($FirstText -match "(?m)^\s*MISSING:") {
        $Missing.Add("$Name contains MISSING placeholder")
    }
}

$MissingText = if ($Missing.Count -eq 0) { "None" } else { ($Missing | ForEach-Object { "- $_" }) -join [Environment]::NewLine }
$AuditInputPath = Join-Path $AuditDir "audit-input.md"
$AuditInput = @"
# Audit Input: $PhaseId

## Target Root

```text
$TargetRoot
```

## Required Files

- status: $StatusPath
- config: $ConfigPath
- prompt: $(Join-Path $PhaseDir "prompt.md")
- worker report: $(Join-Path $PhaseDir "report.md")
- diff: $(Join-Path $PhaseDir "diff.patch")
- verify log: $(Join-Path $PhaseDir "verify.log")
- repository status: $(Join-Path $PhaseDir "status.txt")

## Missing Or Invalid Evidence

$MissingText

## Codex Audit Requirement

Codex must inspect the prompt, Worker report, diff, verify log, repository
status, and relevant source files. Codex must not accept based only on the
Worker report.

Write the audit result to:

```text
$(Join-Path $AuditDir "audit.md")
```

The audit decision must be exactly one of: ACCEPTED, REWORK, BLOCKED.
"@
$AuditInput | Set-Content -LiteralPath $AuditInputPath -Encoding utf8

$Status = Get-Content -LiteralPath $StatusPath -Raw | ConvertFrom-Json
if ($null -ne $Status.current_phase -and $Status.current_phase.phase_id -eq $PhaseId) {
    if ($Missing.Count -eq 0) {
        $Status.current_phase.phase_status = "audit_ready"
    } else {
        $Status.current_phase.phase_status = "blocked_missing_evidence"
    }
    $Status.current_phase.audit_input = ".ai-loop/audits/$PhaseId/audit-input.md"
    $Status.current_phase.audit_prepared_at = (Get-Date).ToUniversalTime().ToString("o")
}
Write-JsonFile -Value $Status -Path $StatusPath

if ($Missing.Count -gt 0) {
    Write-Output "Prepared audit input with missing evidence: $AuditInputPath"
    exit 2
}

Write-Output "Prepared audit input: $AuditInputPath"

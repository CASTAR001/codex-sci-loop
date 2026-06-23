[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PhaseId,
    [Parameter(Mandatory = $true)][string]$Title,
    [Parameter(Mandatory = $true)][string]$Objective,
    [string]$TargetRoot = (Get-Location).Path,
    [string[]]$Scope = @(),
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

$TargetRoot = (Resolve-Path -LiteralPath $TargetRoot).Path
$LoopDir = Join-Path $TargetRoot ".ai-loop"
$StatusPath = Join-Path $LoopDir "status.json"
if (-not (Test-Path -LiteralPath $StatusPath)) {
    throw "Missing .ai-loop/status.json. Run Initialize-AiLoop.ps1 first."
}

$Status = Get-Content -LiteralPath $StatusPath -Raw | ConvertFrom-Json
if ($null -ne $Status.current_phase -and -not $Force) {
    $CurrentState = $Status.current_phase.phase_status
    if ($CurrentState -notin @("accepted", "rework", "blocked")) {
        throw "Current phase '$($Status.current_phase.phase_id)' is still '$CurrentState'. Use -Force only if you are intentionally replacing it."
    }
}

$PhaseDir = Join-Path $LoopDir (Join-Path "evidence" $PhaseId)
New-Item -ItemType Directory -Force -Path $PhaseDir | Out-Null

$KitRoot = Split-Path -Parent $PSScriptRoot
$WorkerPromptPath = Join-Path $KitRoot "prompts\kimi-worker.md"
$WorkerPrompt = Get-Content -LiteralPath $WorkerPromptPath -Raw
$ScopeText = if ($Scope.Count -gt 0) { ($Scope | ForEach-Object { "- $_" }) -join [Environment]::NewLine } else { "- No additional file scope supplied." }
$VerifyText = if ([string]::IsNullOrWhiteSpace($VerifyCommand)) { "No verification command supplied by Supervisor. Worker must report this as a risk unless verification is impossible." } else { $VerifyCommand }

$Prompt = @"
$WorkerPrompt

## Phase Specification

- Phase ID: $PhaseId
- Title: $Title
- Objective: $Objective

## Scope

$ScopeText

## Verification Command

```powershell
$VerifyText
```

## Evidence Required From Worker

Write your report to:

```text
.ai-loop/evidence/$PhaseId/report.md
```

Do not approve this phase. Codex will audit the report, diff, verification log,
status, and relevant source files.
"@

$PromptPath = Join-Path $PhaseDir "prompt.md"
$Prompt | Set-Content -LiteralPath $PromptPath -Encoding utf8

$PhaseRecord = [ordered]@{
    phase_id = $PhaseId
    title = $Title
    objective = $Objective
    phase_status = "worker_prompt_ready"
    evidence_dir = ".ai-loop/evidence/$PhaseId"
    audit_dir = ".ai-loop/audits/$PhaseId"
    verify_command = $VerifyCommand
    started_at = (Get-Date).ToUniversalTime().ToString("o")
}

$Status.current_phase = $PhaseRecord
$Status.phases = @($Status.phases) + @([pscustomobject]$PhaseRecord)
Write-JsonFile -Value $Status -Path $StatusPath

Write-Output "Created Worker prompt: $PromptPath"

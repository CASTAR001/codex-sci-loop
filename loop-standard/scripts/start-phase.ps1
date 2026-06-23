[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][string]$PhaseId,
    [string]$Title = "",
    [string]$Objective = "",
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

function Get-SafeGitArgs {
    param([Parameter(Mandatory = $true)][string]$Root)
    $SafeRoot = $Root.Replace("\", "/")
    return @("-c", "safe.directory=$SafeRoot", "-c", "core.excludesFile=", "-C", $Root)
}

function Invoke-GitText {
    param([Parameter(Mandatory = $true)][string[]]$GitArgs)
    $Output = & git @GitArgs 2>&1
    if ($LASTEXITCODE -eq 0) {
        return ($Output | Out-String).TrimEnd()
    }
    return "MISSING: git command failed: git $($GitArgs -join ' ')`n$($Output | Out-String)"
}

$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$ProjectGitArgs = Get-SafeGitArgs -Root $ProjectRoot
$LoopDir = Join-Path $ProjectRoot ".ai-loop"
$StatusPath = Join-Path $LoopDir "status.json"
if (-not (Test-Path -LiteralPath $StatusPath)) {
    throw "Missing .ai-loop/status.json. Run init-loop.ps1 first."
}

$RunDir = Join-Path $LoopDir (Join-Path "runs" $PhaseId)
if ((Test-Path -LiteralPath $RunDir) -and -not $Force) {
    throw "Run directory already exists: $RunDir. Use -Force to overwrite start files."
}
New-Item -ItemType Directory -Force -Path $RunDir | Out-Null

$Git = Get-Command git -ErrorAction SilentlyContinue
if ($null -eq $Git) {
    "MISSING: git executable was not found." | Set-Content -LiteralPath (Join-Path $RunDir "base_commit.txt") -Encoding utf8
    "MISSING: git executable was not found." | Set-Content -LiteralPath (Join-Path $RunDir "status_before.txt") -Encoding utf8
} else {
    $Inside = & git @ProjectGitArgs rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -eq 0 -and $Inside -eq "true") {
        Invoke-GitText -GitArgs ($ProjectGitArgs + @("rev-parse", "HEAD")) |
            Set-Content -LiteralPath (Join-Path $RunDir "base_commit.txt") -Encoding utf8
        Invoke-GitText -GitArgs ($ProjectGitArgs + @("status", "--short")) |
            Set-Content -LiteralPath (Join-Path $RunDir "status_before.txt") -Encoding utf8
    } else {
        "MISSING: target project is not a git repository." | Set-Content -LiteralPath (Join-Path $RunDir "base_commit.txt") -Encoding utf8
        "MISSING: target project is not a git repository." | Set-Content -LiteralPath (Join-Path $RunDir "status_before.txt") -Encoding utf8
    }
}

$ScopeText = if ($Scope.Count -gt 0) { ($Scope | ForEach-Object { "- $_" }) -join [Environment]::NewLine } else { "- No additional scope supplied." }
$VerifyText = if ([string]::IsNullOrWhiteSpace($VerifyCommand)) { "MISSING: Supervisor did not provide a verification command." } else { $VerifyCommand }
$Prompt = @"
# Kimi Worker Prompt: $PhaseId

## Boundary

- Execute only this phase.
- Do not decide the total route.
- Do not approve or accept this phase.
- Write a report to `.ai-loop/runs/$PhaseId/report.md`.

## Phase

- Phase ID: $PhaseId
- Title: $Title
- Objective: $Objective

## Scope

$ScopeText

## Verification Command

```powershell
$VerifyText
```

Codex will audit the report, diff, verify log, status files, and relevant source
files before deciding `ACCEPTED`, `REWORK`, or `BLOCKED`.
"@
$Prompt | Set-Content -LiteralPath (Join-Path $RunDir "prompt.md") -Encoding utf8

$BaseCommit = Get-Content -LiteralPath (Join-Path $RunDir "base_commit.txt") -Raw
$PhaseMeta = [ordered]@{
    phase_id = $PhaseId
    title = $Title
    objective = $Objective
    status = "started"
    run_dir = ".ai-loop/runs/$PhaseId"
    audit_input = ".ai-loop/audits/$PhaseId-audit-input.md"
    audit_result = ".ai-loop/audits/$PhaseId-audit.md"
    base_commit = $BaseCommit.Trim()
    verify_command = $VerifyCommand
    started_at = (Get-Date).ToUniversalTime().ToString("o")
    evidence_collected_at = $null
    audit_prepared_at = $null
    accepted_at = $null
}
Write-JsonFile -Value ([pscustomobject]$PhaseMeta) -Path (Join-Path $RunDir "phase_meta.json")

$Status = Get-Content -LiteralPath $StatusPath -Raw | ConvertFrom-Json
$Status.current_phase = $PhaseMeta
$Status.phases = @($Status.phases) + @([pscustomobject]$PhaseMeta)
Write-JsonFile -Value $Status -Path $StatusPath

Write-Output "Started phase $PhaseId at $RunDir"

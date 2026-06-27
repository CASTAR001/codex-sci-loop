[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][string]$PhaseId,
    [string]$WorkerProfile = "kimi-code",
    [string]$PromptPath = "",
    [string]$WorkerStateRoot = "",
    [switch]$AllowExternalService,
    [switch]$AllowSensitivePrompt,
    [switch]$Yolo
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
    $Value | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $Path -Encoding utf8
}

function Add-EventLogEntry {
    param(
        [Parameter(Mandatory = $true)][string]$LoopDir,
        [Parameter(Mandatory = $true)]$Event
    )
    $EventDir = Join-Path $LoopDir "events"
    New-Item -ItemType Directory -Force -Path $EventDir | Out-Null
    ($Event | ConvertTo-Json -Depth 20 -Compress) |
        Add-Content -LiteralPath (Join-Path $EventDir "event-log.ndjson") -Encoding utf8
}

$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$KitRoot = Split-Path -Parent $PSScriptRoot
$ProfilePath = Join-Path $KitRoot (Join-Path "worker-profiles" "$WorkerProfile.json")
$LoopDir = Join-Path $ProjectRoot ".ai-loop"
$RunDir = Join-Path $LoopDir (Join-Path "runs" $PhaseId)
$ReviewJsonPath = Join-Path $RunDir "external-worker-preflight.json"
$ReviewMarkdownPath = Join-Path $RunDir "external-worker-preflight.md"

$Problems = New-Object System.Collections.Generic.List[string]
$ApprovalReasons = New-Object System.Collections.Generic.List[string]
$Warnings = New-Object System.Collections.Generic.List[string]

if (-not (Test-Path -LiteralPath $LoopDir -PathType Container)) {
    $Problems.Add("missing .ai-loop directory")
}
if (-not (Test-Path -LiteralPath $RunDir -PathType Container)) {
    $Problems.Add("missing phase run directory: .ai-loop/runs/$PhaseId")
}
if (-not (Test-Path -LiteralPath $ProfilePath -PathType Leaf)) {
    $Problems.Add("missing Worker profile: $ProfilePath")
}

$Profile = $null
if (Test-Path -LiteralPath $ProfilePath -PathType Leaf) {
    $Profile = Get-Content -LiteralPath $ProfilePath -Raw | ConvertFrom-Json
}

if ([string]::IsNullOrWhiteSpace($PromptPath)) {
    $PromptPath = Join-Path $RunDir "prompt.md"
}
$PromptPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($PromptPath)

$PromptHash = ""
$PromptSizeBytes = 0
$PromptText = ""
$PromptRiskHits = @()
if (-not (Test-Path -LiteralPath $PromptPath -PathType Leaf)) {
    $Problems.Add("missing Worker prompt: $PromptPath")
} else {
    $PromptHash = (Get-FileHash -LiteralPath $PromptPath -Algorithm SHA256).Hash
    $PromptSizeBytes = (Get-Item -LiteralPath $PromptPath).Length
    $PromptText = Get-Content -LiteralPath $PromptPath -Raw
    $RiskPatterns = @(
        "api[_-]?key",
        "secret",
        "password",
        "token",
        "BEGIN (RSA |OPENSSH |EC |)PRIVATE KEY",
        "\.env(\b|/|\\)",
        "credentials"
    )
    foreach ($Pattern in $RiskPatterns) {
        if ($PromptText -match $Pattern) {
            $PromptRiskHits += $Pattern
        }
    }
}

$SkillsDir = Join-Path $ProjectRoot ".agents\skills"
$SkillsDirStatus = if (Test-Path -LiteralPath $SkillsDir -PathType Container) { "present" } else { "missing" }
if ($SkillsDirStatus -eq "missing") {
    $Warnings.Add("project .agents/skills directory is missing")
}

if ($null -ne $Profile) {
    if ($Profile.external_service -and -not $AllowExternalService) {
        $ApprovalReasons.Add("Worker profile '$WorkerProfile' uses an external service; pass -AllowExternalService only after user confirmation.")
    }
    if ($PromptRiskHits.Count -gt 0 -and -not $AllowSensitivePrompt) {
        $ApprovalReasons.Add("prompt contains sensitive-looking patterns: $($PromptRiskHits -join ', ')")
    }
    if ([string]::IsNullOrWhiteSpace($Profile.command)) {
        $Problems.Add("Worker profile missing command")
    } elseif ($null -eq (Get-Command ([string]$Profile.command) -ErrorAction SilentlyContinue)) {
        $Problems.Add("Worker command not found on PATH: $($Profile.command)")
    }
}

if ([string]::IsNullOrWhiteSpace($WorkerStateRoot)) {
    if ($null -ne $Profile -and -not [string]::IsNullOrWhiteSpace($Profile.default_state_root)) {
        $WorkerStateRoot = Join-Path $ProjectRoot ([string]$Profile.default_state_root)
    } else {
        $WorkerStateRoot = Join-Path $LoopDir (Join-Path "runtime" $WorkerProfile)
    }
}
$WorkerStateRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($WorkerStateRoot)
$StateEnvVar = if ($null -ne $Profile -and -not [string]::IsNullOrWhiteSpace($Profile.state_env_var)) { [string]$Profile.state_env_var } else { "" }
$StateConfigPath = if ([string]::IsNullOrWhiteSpace($StateEnvVar)) { "" } else { Join-Path $WorkerStateRoot "config.toml" }
if (-not [string]::IsNullOrWhiteSpace($StateConfigPath) -and -not (Test-Path -LiteralPath $StateConfigPath -PathType Leaf)) {
    $Warnings.Add("Worker state config not found at $StateConfigPath; Worker may require login or configuration.")
}

$GitStatus = @()
$Git = Get-Command git -ErrorAction SilentlyContinue
if ($null -ne $Git) {
    $SafeRoot = $ProjectRoot.Replace("\", "/")
    $GitStatus = @(& git -c "safe.directory=$SafeRoot" -c "core.excludesFile=" -C $ProjectRoot status --short 2>&1)
    if ($LASTEXITCODE -ne 0) {
        $Warnings.Add("git status failed during preflight: $($GitStatus -join ' ')")
        $GitStatus = @()
    }
} else {
    $Warnings.Add("git executable not found")
}

$Decision = "SAFE_TO_INVOKE"
if ($Problems.Count -gt 0) {
    $Decision = "BLOCKED"
} elseif ($ApprovalReasons.Count -gt 0) {
    $Decision = "NEEDS_USER_APPROVAL"
}

New-Item -ItemType Directory -Force -Path $RunDir | Out-Null
$Review = [pscustomobject][ordered]@{
    schema_version = "1.0"
    phase_id = $PhaseId
    project_root = $ProjectRoot
    worker_profile = $WorkerProfile
    profile_path = ConvertTo-NormalizedPath -Path $ProfilePath
    prompt_path = ConvertTo-NormalizedPath -Path $PromptPath
    prompt_sha256 = $PromptHash
    prompt_size_bytes = $PromptSizeBytes
    external_service = if ($null -ne $Profile) { [bool]$Profile.external_service } else { $false }
    external_service_allowed = [bool]$AllowExternalService
    yolo_enabled = [bool]$Yolo
    sensitive_prompt_allowed = [bool]$AllowSensitivePrompt
    prompt_risk_hits = @($PromptRiskHits)
    skills_dir = ConvertTo-NormalizedPath -Path $SkillsDir
    skills_dir_status = $SkillsDirStatus
    worker_state_root = ConvertTo-NormalizedPath -Path $WorkerStateRoot
    state_env_var = $StateEnvVar
    git_status = @($GitStatus)
    decision = $Decision
    approval_reasons = @($ApprovalReasons)
    blockers = @($Problems)
    warnings = @($Warnings)
    reviewed_at = (Get-Date).ToUniversalTime().ToString("o")
}
Write-JsonFile -Value $Review -Path $ReviewJsonPath

$Lines = New-Object System.Collections.Generic.List[string]
$Lines.Add("# External Worker Preflight: $PhaseId")
$Lines.Add("")
$Lines.Add("Decision: $Decision")
$Lines.Add("")
$Lines.Add("## Invocation")
$Lines.Add("")
$Lines.Add("- Worker profile: $WorkerProfile")
$Lines.Add("- Prompt: $($Review.prompt_path)")
$Lines.Add("- Prompt SHA256: $PromptHash")
$Lines.Add("- External service: $($Review.external_service)")
$Lines.Add("- External service allowed: $($Review.external_service_allowed)")
$Lines.Add("- Yolo enabled: $($Review.yolo_enabled)")
$Lines.Add("- Skills dir: $($Review.skills_dir) ($SkillsDirStatus)")
$Lines.Add("- Worker state root: $($Review.worker_state_root)")
$Lines.Add("- State env var: $StateEnvVar")
$Lines.Add("")
$Lines.Add("## Approval Reasons")
if ($ApprovalReasons.Count -eq 0) { $Lines.Add("- none") } else { foreach ($Reason in $ApprovalReasons) { $Lines.Add("- $Reason") } }
$Lines.Add("")
$Lines.Add("## Blockers")
if ($Problems.Count -eq 0) { $Lines.Add("- none") } else { foreach ($Problem in $Problems) { $Lines.Add("- $Problem") } }
$Lines.Add("")
$Lines.Add("## Warnings")
if ($Warnings.Count -eq 0) { $Lines.Add("- none") } else { foreach ($Warning in $Warnings) { $Lines.Add("- $Warning") } }
$Lines.Add("")
$Lines.Add("## Git Status")
if ($GitStatus.Count -eq 0) { $Lines.Add("- clean or unavailable") } else { foreach ($Line in $GitStatus) { $Lines.Add("- $Line") } }
$Lines | Set-Content -LiteralPath $ReviewMarkdownPath -Encoding utf8

if (Test-Path -LiteralPath $LoopDir -PathType Container) {
    Add-EventLogEntry -LoopDir $LoopDir -Event ([ordered]@{
        ts = (Get-Date).ToUniversalTime().ToString("o")
        type = "worker_preflight"
        actor = "preflight-worker.ps1"
        phase = $PhaseId
        worker_profile = $WorkerProfile
        decision = $Decision
        yolo_enabled = [bool]$Yolo
        paths = @(".ai-loop/runs/$PhaseId/external-worker-preflight.json", ".ai-loop/runs/$PhaseId/external-worker-preflight.md")
    })
}

Write-Output "External Worker preflight: $Decision"
Write-Output "Review JSON: $ReviewJsonPath"
Write-Output "Review Markdown: $ReviewMarkdownPath"
if ($Decision -eq "BLOCKED") { exit 2 }
if ($Decision -eq "NEEDS_USER_APPROVAL") { exit 3 }

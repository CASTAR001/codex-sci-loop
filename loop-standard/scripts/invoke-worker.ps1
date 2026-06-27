[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][string]$PhaseId,
    [string]$WorkerProfile = "kimi-code",
    [string]$PromptPath = "",
    [string]$WorkerStateRoot = "",
    [switch]$AllowExternalService,
    [switch]$AllowSensitivePrompt,
    [switch]$Yolo,
    [switch]$DryRun
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
$LoopDir = Join-Path $ProjectRoot ".ai-loop"
$RunDir = Join-Path $LoopDir (Join-Path "runs" $PhaseId)
$ProfilePath = Join-Path $KitRoot (Join-Path "worker-profiles" "$WorkerProfile.json")
$ReviewJsonPath = Join-Path $RunDir "external-worker-preflight.json"
$InvocationJsonPath = Join-Path $RunDir "external-worker-invocation.json"
$InvocationLogPath = Join-Path $RunDir "external-worker-invocation.log"

if (-not (Test-Path -LiteralPath $ProfilePath -PathType Leaf)) {
    throw "Missing Worker profile: $ProfilePath"
}
$Profile = Get-Content -LiteralPath $ProfilePath -Raw | ConvertFrom-Json

$PreflightArgs = @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    (Join-Path $PSScriptRoot "preflight-worker.ps1"),
    "-ProjectRoot",
    $ProjectRoot,
    "-PhaseId",
    $PhaseId,
    "-WorkerProfile",
    $WorkerProfile
)
if (-not [string]::IsNullOrWhiteSpace($PromptPath)) { $PreflightArgs += @("-PromptPath", $PromptPath) }
if (-not [string]::IsNullOrWhiteSpace($WorkerStateRoot)) { $PreflightArgs += @("-WorkerStateRoot", $WorkerStateRoot) }
if ($AllowExternalService) { $PreflightArgs += "-AllowExternalService" }
if ($AllowSensitivePrompt) { $PreflightArgs += "-AllowSensitivePrompt" }
if ($Yolo) { $PreflightArgs += "-Yolo" }

$PreflightOutput = @(& powershell.exe @PreflightArgs 2>&1)
$PreflightExitCode = $LASTEXITCODE
if ($PreflightExitCode -ne 0) {
    $PreflightOutput | Set-Content -LiteralPath $InvocationLogPath -Encoding utf8
    Write-Output "External Worker invocation blocked by preflight."
    $PreflightOutput
    exit $PreflightExitCode
}

$Review = Get-Content -LiteralPath $ReviewJsonPath -Raw | ConvertFrom-Json
if ($Review.decision -ne "SAFE_TO_INVOKE") {
    Write-Output "External Worker invocation blocked: $($Review.decision)"
    exit 2
}

$PromptResolvedPath = $Review.prompt_path -replace "/", "\"
$PromptText = Get-Content -LiteralPath $PromptResolvedPath -Raw
$SkillsDir = $Review.skills_dir -replace "/", "\"
$WorkerStateRoot = $Review.worker_state_root -replace "/", "\"
if (-not [string]::IsNullOrWhiteSpace($Review.state_env_var)) {
    New-Item -ItemType Directory -Force -Path $WorkerStateRoot | Out-Null
}

$Command = [string]$Profile.command
$Arguments = New-Object System.Collections.Generic.List[string]
if ($Yolo -and $Profile.supports_yolo -and -not [string]::IsNullOrWhiteSpace($Profile.yolo_argument)) {
    $Arguments.Add([string]$Profile.yolo_argument)
}
if ($Profile.supports_skills_dir -and (Test-Path -LiteralPath $SkillsDir -PathType Container)) {
    $Arguments.Add([string]$Profile.skills_dir_argument)
    $Arguments.Add($SkillsDir)
}
$Arguments.Add([string]$Profile.prompt_argument)
$Arguments.Add($PromptText)

$DisplayArgs = @()
foreach ($Arg in @($Arguments)) {
    if ($Arg -eq $PromptText) {
        $DisplayArgs += "<prompt:$($Review.prompt_sha256.Substring(0, 12))>"
    } else {
        $DisplayArgs += $Arg
    }
}

$StartedAt = (Get-Date).ToUniversalTime().ToString("o")
$ExitCode = 0
$Output = @()
if ($DryRun) {
    $Output = @("DRY RUN: $Command $($DisplayArgs -join ' ')")
} else {
    $PreviousState = $null
    $HadState = $false
    if (-not [string]::IsNullOrWhiteSpace($Review.state_env_var)) {
        $StateName = [string]$Review.state_env_var
        if (Test-Path "Env:$StateName") {
            $HadState = $true
            $PreviousState = (Get-Item "Env:$StateName").Value
        }
        Set-Item -Path "Env:$StateName" -Value $WorkerStateRoot
    }
    try {
        $Output = @(& $Command @Arguments 2>&1)
        $ExitCode = $LASTEXITCODE
    } finally {
        if (-not [string]::IsNullOrWhiteSpace($Review.state_env_var)) {
            $StateName = [string]$Review.state_env_var
            if ($HadState) {
                Set-Item -Path "Env:$StateName" -Value $PreviousState
            } else {
                Remove-Item -Path "Env:$StateName" -ErrorAction SilentlyContinue
            }
        }
    }
}
$FinishedAt = (Get-Date).ToUniversalTime().ToString("o")

@(
    "command: $Command $($DisplayArgs -join ' ')",
    "started_at: $StartedAt",
    "finished_at: $FinishedAt",
    "exit_code: $ExitCode",
    "",
    "output:",
    ($Output | Out-String).TrimEnd()
) | Set-Content -LiteralPath $InvocationLogPath -Encoding utf8

$Invocation = [pscustomobject][ordered]@{
    schema_version = "1.0"
    phase_id = $PhaseId
    worker_profile = $WorkerProfile
    command = $Command
    display_arguments = @($DisplayArgs)
    prompt_path = $Review.prompt_path
    prompt_sha256 = $Review.prompt_sha256
    yolo_enabled = [bool]$Yolo
    dry_run = [bool]$DryRun
    worker_state_root = $Review.worker_state_root
    state_env_var = $Review.state_env_var
    started_at = $StartedAt
    finished_at = $FinishedAt
    exit_code = $ExitCode
    log_path = ".ai-loop/runs/$PhaseId/external-worker-invocation.log"
}
Write-JsonFile -Value $Invocation -Path $InvocationJsonPath

if (Test-Path -LiteralPath $LoopDir -PathType Container) {
    Add-EventLogEntry -LoopDir $LoopDir -Event ([ordered]@{
        ts = (Get-Date).ToUniversalTime().ToString("o")
        type = "worker_invocation"
        actor = "invoke-worker.ps1"
        phase = $PhaseId
        worker_profile = $WorkerProfile
        yolo_enabled = [bool]$Yolo
        dry_run = [bool]$DryRun
        exit_code = $ExitCode
        paths = @(".ai-loop/runs/$PhaseId/external-worker-invocation.json", ".ai-loop/runs/$PhaseId/external-worker-invocation.log")
    })
}

Write-Output "External Worker invocation finished with exit_code $ExitCode"
Write-Output "Invocation JSON: $InvocationJsonPath"
Write-Output "Invocation log: $InvocationLogPath"
if ($ExitCode -ne 0) { exit $ExitCode }

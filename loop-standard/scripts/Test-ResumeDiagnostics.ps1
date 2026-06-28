[CmdletBinding()]
param(
    [switch]$KeepTemp
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Add-Problem {
    param([Parameter(Mandatory = $true)][string]$Message)
    $script:Problems.Add($Message)
}

function Invoke-AiLoop {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $PreviousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $Output = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $AiLoopScript @Arguments 2>&1)
    $ErrorActionPreference = $PreviousErrorActionPreference
    return [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Text = ($Output | Out-String)
    }
}

function Expect-Text {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [Parameter(Mandatory = $true)][string]$Label
    )
    if ($Text -notmatch $Pattern) {
        Add-Problem "$Label missing pattern '$Pattern'. Output: $Text"
    }
}

function Save-Json {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Path
    )
    $Object | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $Path -Encoding utf8
}

$KitRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = Split-Path -Parent $KitRoot
$AiLoopScript = Join-Path $PSScriptRoot "ai-loop.ps1"
. (Join-Path $PSScriptRoot "test-temp-root.ps1")
$TempRoot = New-LoopTestTempRoot -RepoRoot $RepoRoot -Name "resume-diagnostics"
$ProjectRoot = Join-Path $TempRoot "project"
$Problems = New-Object System.Collections.Generic.List[string]

if ((Test-Path -LiteralPath $TempRoot) -and -not $KeepTemp) {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $ProjectRoot | Out-Null

Push-Location $ProjectRoot
try {
    git init | Out-Null
    Set-Content -LiteralPath "README.md" -Encoding utf8 -Value "# Resume diagnostics fixture"
    Set-Content -LiteralPath "verify.ps1" -Encoding utf8 -Value "Write-Output 'resume diagnostics: OK'`nexit 0"
    git add README.md verify.ps1 | Out-Null
    git commit -m "Initial fixture" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Add-Problem "fixture git commit failed."
    }
} finally {
    Pop-Location
}

$Init = Invoke-AiLoop -Arguments @("-Command", "init", "-ProjectRoot", $ProjectRoot)
if ($Init.ExitCode -ne 0) { Add-Problem "init failed: $($Init.Text)" }
$Start = Invoke-AiLoop -Arguments @(
    "-Command", "start",
    "-ProjectRoot", $ProjectRoot,
    "-PhaseId", "phase-001",
    "-TaskKind", "fullstack",
    "-Title", "Resume diagnostics",
    "-Objective", "Exercise resume diagnostics.",
    "-VerifyCommand", "powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\verify.ps1"
)
if ($Start.ExitCode -ne 0) { Add-Problem "start failed: $($Start.Text)" }

$Resume = Invoke-AiLoop -Arguments @("-Command", "resume", "-ProjectRoot", $ProjectRoot)
if ($Resume.ExitCode -ne 0) {
    Add-Problem "resume should pass for a freshly started phase: $($Resume.Text)"
}
Expect-Text -Text $Resume.Text -Pattern "Latest transition: .* -> started" -Label "started resume"
Expect-Text -Text $Resume.Text -Pattern "Transition consistency: OK" -Label "started resume"
Expect-Text -Text $Resume.Text -Pattern "Next safe command: .* -Command collect .* -PhaseId phase-001" -Label "started resume"
Expect-Text -Text $Resume.Text -Pattern "Recovery decision: RESUMABLE" -Label "started resume"

$StatusPath = Join-Path $ProjectRoot ".ai-loop\status.json"
$Status = Get-Content -LiteralPath $StatusPath -Raw | ConvertFrom-Json
$Status.current_phase.status = "audit_ready"
$Status.phases[0].status = "audit_ready"
Save-Json -Object $Status -Path $StatusPath

$TamperedResume = Invoke-AiLoop -Arguments @("-Command", "resume", "-ProjectRoot", $ProjectRoot)
if ($TamperedResume.ExitCode -eq 0) {
    Add-Problem "resume should return nonzero for transition/status mismatch."
}
Expect-Text -Text $TamperedResume.Text -Pattern "Transition consistency: MISMATCH latest=started status=audit_ready" -Label "tampered resume"
Expect-Text -Text $TamperedResume.Text -Pattern "Transition problems:" -Label "tampered resume"
Expect-Text -Text $TamperedResume.Text -Pattern "Recovery decision: BLOCKED" -Label "tampered resume"

if ($Problems.Count -gt 0) {
    Write-Output "Resume diagnostics test: FAILED"
    foreach ($Problem in $Problems) {
        Write-Output "- $Problem"
    }
    Write-Output "Fixture root: $TempRoot"
    exit 2
}

Write-Output "Resume diagnostics test: OK"
Write-Output "Fixture root: $TempRoot"
Write-Output "Cases checked: started phase resume, transition/status mismatch BLOCKED"

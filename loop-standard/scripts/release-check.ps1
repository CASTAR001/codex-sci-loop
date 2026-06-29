[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$Json,
    [switch]$SkipMatrix,
    [string]$MatrixScript = "Test-Phase023.ps1"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-CheckedCommand {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [string[]]$Arguments = @()
    )
    $Started = Get-Date
    $PreviousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $Output = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @Arguments 2>&1)
    $ExitCode = $LASTEXITCODE
    $ErrorActionPreference = $PreviousErrorActionPreference
    $Finished = Get-Date
    return [pscustomobject][ordered]@{
        label = $Label
        script = $ScriptPath
        arguments = @($Arguments)
        exit_code = $ExitCode
        duration_seconds = [math]::Round(($Finished - $Started).TotalSeconds, 3)
        output = ($Output | Out-String).Trim()
    }
}

function Resolve-MatrixScriptPath {
    param([Parameter(Mandatory = $true)][string]$NameOrPath)
    $Candidate = if ([System.IO.Path]::IsPathRooted($NameOrPath)) {
        $NameOrPath
    } else {
        Join-Path $PSScriptRoot $NameOrPath
    }
    $Resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Candidate)
    $ScriptsRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
    $Full = [System.IO.Path]::GetFullPath($Resolved)
    if (-not $Full.StartsWith($ScriptsRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "MatrixScript must resolve under loop-standard/scripts: $NameOrPath"
    }
    if (-not (Test-Path -LiteralPath $Full -PathType Leaf)) {
        throw "MatrixScript not found: $Full"
    }
    return $Full
}

$ProjectRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ProjectRoot)
$ReadinessScript = Join-Path $PSScriptRoot "check-readiness.ps1"
$ValidateLoopScript = Join-Path $PSScriptRoot "validate-loop.ps1"
$MatrixScriptPath = if ($SkipMatrix) { "" } else { Resolve-MatrixScriptPath -NameOrPath $MatrixScript }

$Readiness = Invoke-CheckedCommand -Label "readiness" -ScriptPath $ReadinessScript -Arguments @("-ProjectRoot", $ProjectRoot, "-Json")
$ReadinessObject = $null
$ReadinessParseError = ""
try {
    $ReadinessObject = $Readiness.output | ConvertFrom-Json
} catch {
    $ReadinessParseError = $_.Exception.Message
}

$ValidateLoop = Invoke-CheckedCommand -Label "validate-loop" -ScriptPath $ValidateLoopScript -Arguments @("-ProjectRoot", $ProjectRoot, "-Quiet")

$Matrix = [pscustomobject][ordered]@{
    label = "matrix"
    script = $MatrixScriptPath
    arguments = @()
    exit_code = 0
    duration_seconds = 0
    output = "skipped"
}
if (-not $SkipMatrix) {
    $Matrix = Invoke-CheckedCommand -Label "matrix" -ScriptPath $MatrixScriptPath -Arguments @()
}

$Checks = New-Object System.Collections.Generic.List[object]
$ReadinessStatus = if ($null -ne $ReadinessObject) { [string]$ReadinessObject.status } else { "unparseable" }
$ReadinessFail = if ($null -ne $ReadinessObject) { [int]$ReadinessObject.summary.fail } else { 1 }
$ReadinessWarn = if ($null -ne $ReadinessObject) { [int]$ReadinessObject.summary.warn } else { 0 }
$Checks.Add([pscustomobject][ordered]@{
    id = "RELEASE-READINESS"
    status = if ($Readiness.exit_code -eq 0 -and $ReadinessFail -eq 0) { "pass" } else { "fail" }
    evidence = "check-readiness.ps1 -Json"
    exit_code = $Readiness.exit_code
    notes = if ([string]::IsNullOrWhiteSpace($ReadinessParseError)) { "status=$ReadinessStatus warn=$ReadinessWarn fail=$ReadinessFail" } else { "JSON parse error: $ReadinessParseError" }
})
$Checks.Add([pscustomobject][ordered]@{
    id = "RELEASE-VALIDATE-LOOP"
    status = if ($ValidateLoop.exit_code -eq 0) { "pass" } else { "fail" }
    evidence = "validate-loop.ps1 -Quiet"
    exit_code = $ValidateLoop.exit_code
    notes = if ($ValidateLoop.exit_code -eq 0) { "loop validation passed" } else { $ValidateLoop.output }
})
$Checks.Add([pscustomobject][ordered]@{
    id = "RELEASE-MATRIX"
    status = if ($SkipMatrix) { "skipped" } elseif ($Matrix.exit_code -eq 0) { "pass" } else { "fail" }
    evidence = if ($SkipMatrix) { "matrix skipped by operator" } else { (Split-Path -Leaf $MatrixScriptPath) }
    exit_code = $Matrix.exit_code
    notes = if ($SkipMatrix) { "Use without -SkipMatrix for the full non-global verification matrix." } elseif ($Matrix.exit_code -eq 0) { "matrix passed" } else { $Matrix.output }
})

$FailCount = @($Checks | Where-Object { $_.status -eq "fail" }).Count
$SkippedCount = @($Checks | Where-Object { $_.status -eq "skipped" }).Count
$WarnCount = $ReadinessWarn
$OverallStatus = if ($FailCount -gt 0) {
    "blocked"
} elseif ($WarnCount -gt 0 -or $SkippedCount -gt 0) {
    "ready_with_warnings"
} else {
    "ready"
}

$Result = [pscustomobject][ordered]@{
    schema_version = "1.0"
    project_root = $ProjectRoot
    kit_root = (Split-Path -Parent $PSScriptRoot)
    status = $OverallStatus
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    summary = [ordered]@{
        pass = @($Checks | Where-Object { $_.status -eq "pass" }).Count
        warn = $WarnCount
        fail = $FailCount
        skipped = $SkippedCount
        total = $Checks.Count
    }
    checks = @($Checks.ToArray())
    readiness = $ReadinessObject
    commands = [ordered]@{
        readiness = $Readiness
        validate_loop = $ValidateLoop
        matrix = $Matrix
    }
    next_actions = @(
        if ($FailCount -gt 0) { "Fix failing release checks before claiming 1.0 delivery." }
        if ($SkippedCount -gt 0) { "Run release-check without -SkipMatrix before final release sign-off." }
        if ($WarnCount -gt 0) { "Resolve readiness warnings when policy allows; PLUGIN-GLOBAL requires explicit user approval." }
    )
}

if ($Json) {
    $Result | ConvertTo-Json -Depth 40
} else {
    Write-Output "# Loop Harness 1.0 Release Check"
    Write-Output ""
    Write-Output "Project root: $ProjectRoot"
    Write-Output "Status: $OverallStatus"
    Write-Output "Summary: pass=$($Result.summary.pass) warn=$($Result.summary.warn) fail=$($Result.summary.fail) skipped=$($Result.summary.skipped) total=$($Result.summary.total)"
    Write-Output ""
    foreach ($Check in @($Result.checks)) {
        Write-Output "[$($Check.status.ToUpperInvariant())] $($Check.id) - $($Check.evidence)"
        if (-not [string]::IsNullOrWhiteSpace([string]$Check.notes)) {
            Write-Output "  notes: $($Check.notes)"
        }
    }
}

if ($FailCount -gt 0) {
    exit 2
}

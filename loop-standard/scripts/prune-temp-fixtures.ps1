[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [ValidateRange(0, 87600)]
    [int]$MinAgeHours = 24,
    [ValidateRange(0, 10000)]
    [int]$KeepLatest = 2,
    [switch]$Force,
    [switch]$DryRun,
    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-FullPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [System.IO.Path]::GetFullPath($Path)
}

function Test-IsUnderRoot {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Path
    )
    $ResolvedRoot = (Resolve-FullPath -Path $Root).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
    $ResolvedPath = Resolve-FullPath -Path $Path
    $Prefix = $ResolvedRoot + [System.IO.Path]::DirectorySeparatorChar
    return $ResolvedPath.Equals($ResolvedRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
        $ResolvedPath.StartsWith($Prefix, [System.StringComparison]::OrdinalIgnoreCase)
}

$ProjectRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ProjectRoot)
if (-not (Test-Path -LiteralPath $ProjectRoot -PathType Container)) {
    throw "ProjectRoot does not exist: $ProjectRoot"
}

$ResolvedProjectRoot = Resolve-FullPath -Path $ProjectRoot
$Mode = if ($Force -and -not $DryRun) { "delete" } else { "dry-run" }
$CutoffUtc = (Get-Date).ToUniversalTime().AddHours(-1 * $MinAgeHours)
$Candidates = New-Object System.Collections.Generic.List[object]
$Skipped = New-Object System.Collections.Generic.List[object]
$Parents = @(Get-ChildItem -LiteralPath $ResolvedProjectRoot -Directory -Force |
    Where-Object { $_.Name -like ".tmp-ai-loop-*" })

foreach ($Parent in $Parents) {
    if (($Parent.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        $Skipped.Add([pscustomobject]@{
            path = $Parent.FullName
            type = "temp-parent"
            reason = "reparse-point"
        })
        continue
    }
    if (-not (Test-IsUnderRoot -Root $ResolvedProjectRoot -Path $Parent.FullName)) {
        throw "Refusing to inspect temp parent outside project root: $($Parent.FullName)"
    }

    $Runs = @(Get-ChildItem -LiteralPath $Parent.FullName -Directory -Force |
        Where-Object { $_.Name -like "run-*" } |
        Sort-Object LastWriteTimeUtc -Descending)
    $KeepSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($Run in @($Runs | Select-Object -First $KeepLatest)) {
        [void]$KeepSet.Add((Resolve-FullPath -Path $Run.FullName))
    }

    foreach ($Run in $Runs) {
        if (($Run.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            $Skipped.Add([pscustomobject]@{
                path = $Run.FullName
                type = "run-directory"
                reason = "reparse-point"
            })
            continue
        }
        $ResolvedRun = Resolve-FullPath -Path $Run.FullName
        if (-not (Test-IsUnderRoot -Root $ResolvedProjectRoot -Path $ResolvedRun)) {
            throw "Refusing to prune run directory outside project root: $ResolvedRun"
        }
        if ($Parent.Name -notlike ".tmp-ai-loop-*") {
            throw "Refusing to prune run directory under non ai-loop temp parent: $ResolvedRun"
        }
        if ($Run.Name -notlike "run-*") {
            continue
        }
        if ($KeepSet.Contains($ResolvedRun)) {
            continue
        }
        if ($Run.LastWriteTimeUtc -gt $CutoffUtc) {
            continue
        }

        $Candidates.Add([pscustomobject]@{
            path = $ResolvedRun
            parent = $Parent.Name
            last_write_utc = $Run.LastWriteTimeUtc.ToUniversalTime().ToString("o")
            age_hours = [math]::Round(((Get-Date).ToUniversalTime() - $Run.LastWriteTimeUtc.ToUniversalTime()).TotalHours, 2)
        })
    }
}

if ($Mode -eq "dry-run") {
    $Result = [pscustomobject][ordered]@{
        schema_version = "1.0"
        project_root = $ResolvedProjectRoot
        mode = $Mode
        min_age_hours = $MinAgeHours
        keep_latest = $KeepLatest
        cutoff_utc = $CutoffUtc.ToString("o")
        candidate_count = $Candidates.Count
        deleted_count = 0
        candidates = @($Candidates.ToArray())
        deleted = @()
        skipped = @($Skipped.ToArray())
        generated_at = (Get-Date).ToUniversalTime().ToString("o")
    }
    if ($Json) {
        $Result | ConvertTo-Json -Depth 30
    } else {
        Write-Output "AI Loop temp fixture prune"
        Write-Output "Project root: $ResolvedProjectRoot"
        Write-Output "Mode: $Mode"
        Write-Output "Min age hours: $MinAgeHours"
        Write-Output "Keep latest per parent: $KeepLatest"
        Write-Output "Candidate count: $($Candidates.Count)"
        foreach ($Candidate in $Candidates) {
            Write-Output "- $($Candidate.path) age_hours=$($Candidate.age_hours)"
        }
        foreach ($Skip in $Skipped) {
            Write-Output "Skipping $($Skip.reason) $($Skip.type): $($Skip.path)"
        }
        Write-Output "Dry run only. Re-run with -Force to delete candidates."
    }
    exit 0
}

$Deleted = 0
$DeletedPaths = New-Object System.Collections.Generic.List[object]
foreach ($Candidate in $Candidates) {
    if (-not (Test-IsUnderRoot -Root $ResolvedProjectRoot -Path $Candidate.path)) {
        throw "Refusing to delete outside project root: $($Candidate.path)"
    }
    if (Test-Path -LiteralPath $Candidate.path -PathType Container) {
        Remove-Item -LiteralPath $Candidate.path -Recurse -Force
        $Deleted++
        $DeletedPaths.Add([pscustomobject]@{
            path = $Candidate.path
            parent = $Candidate.parent
            age_hours = $Candidate.age_hours
        })
    }
}

$Result = [pscustomobject][ordered]@{
    schema_version = "1.0"
    project_root = $ResolvedProjectRoot
    mode = $Mode
    min_age_hours = $MinAgeHours
    keep_latest = $KeepLatest
    cutoff_utc = $CutoffUtc.ToString("o")
    candidate_count = $Candidates.Count
    deleted_count = $Deleted
    candidates = @($Candidates.ToArray())
    deleted = @($DeletedPaths.ToArray())
    skipped = @($Skipped.ToArray())
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
}
if ($Json) {
    $Result | ConvertTo-Json -Depth 30
} else {
    Write-Output "AI Loop temp fixture prune"
    Write-Output "Project root: $ResolvedProjectRoot"
    Write-Output "Mode: $Mode"
    Write-Output "Min age hours: $MinAgeHours"
    Write-Output "Keep latest per parent: $KeepLatest"
    Write-Output "Candidate count: $($Candidates.Count)"
    foreach ($Candidate in $Candidates) {
        Write-Output "- $($Candidate.path) age_hours=$($Candidate.age_hours)"
    }
    foreach ($Skip in $Skipped) {
        Write-Output "Skipping $($Skip.reason) $($Skip.type): $($Skip.path)"
    }
    Write-Output "Deleted count: $Deleted"
}

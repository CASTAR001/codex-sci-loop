Set-StrictMode -Version Latest

function New-LoopTestTempRoot {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $SafeName = (($Name -replace "[^A-Za-z0-9._-]", "-") -replace "-+", "-").Trim("-")
    if ([string]::IsNullOrWhiteSpace($SafeName)) {
        throw "Test temp root name cannot be empty."
    }

    $RunPrefix = $env:AI_LOOP_TEST_RUN_ID
    if ([string]::IsNullOrWhiteSpace($RunPrefix)) {
        $RunPrefix = (Get-Date).ToUniversalTime().ToString("yyyyMMddHHmmssfff")
    }
    $GuidPart = ([guid]::NewGuid().ToString("N")).Substring(0, 8)
    $RunId = "{0}-{1}-{2}" -f $RunPrefix, $PID, $GuidPart
    $SafeRunId = (($RunId -replace "[^A-Za-z0-9._-]", "-") -replace "-+", "-").Trim("-")
    if ([string]::IsNullOrWhiteSpace($SafeRunId)) {
        throw "Test temp run id cannot be empty."
    }

    $Parent = Join-Path $RepoRoot ".tmp-ai-loop-$SafeName"
    $Root = Join-Path $Parent "run-$SafeRunId"

    $ResolvedRepo = [System.IO.Path]::GetFullPath($RepoRoot)
    $ResolvedRoot = [System.IO.Path]::GetFullPath($Root)
    $RepoPrefix = $ResolvedRepo.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if (-not $ResolvedRoot.StartsWith($RepoPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to create test temp root outside repository: $ResolvedRoot"
    }

    New-Item -ItemType Directory -Force -Path $ResolvedRoot | Out-Null
    return $ResolvedRoot
}

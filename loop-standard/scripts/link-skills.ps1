[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [string]$SkillLibraryRoot = "E:\codexfiles\test\.agents\skills",
    [ValidateSet("none", "research-core", "physics-sim", "manuscript", "full-research")]
    [string]$Profile = "full-research",
    [ValidateSet("research-task-tree", "invariant-contract", "bounded-experiment-loop", "deterministic-verification", "independent-crosscheck", "result-provenance-audit", "manuscript-consistency-audit", "skill-compliance-audit")]
    [string[]]$Skills = @(),
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-SkillsForProfile {
    param([Parameter(Mandatory = $true)][string]$Name)
    switch ($Name) {
        "research-core" { return @("research-task-tree", "invariant-contract", "deterministic-verification", "skill-compliance-audit") }
        "physics-sim" { return @("research-task-tree", "invariant-contract", "bounded-experiment-loop", "deterministic-verification", "independent-crosscheck", "result-provenance-audit", "skill-compliance-audit") }
        "manuscript" { return @("research-task-tree", "deterministic-verification", "result-provenance-audit", "manuscript-consistency-audit", "skill-compliance-audit") }
        "full-research" { return @("research-task-tree", "invariant-contract", "bounded-experiment-loop", "deterministic-verification", "independent-crosscheck", "result-provenance-audit", "manuscript-consistency-audit", "skill-compliance-audit") }
        default { return @() }
    }
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

function New-SkillLink {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Target
    )
    try {
        New-Item -ItemType Junction -Path $Target -Target $Source -Force | Out-Null
        return "junction"
    } catch {
        try {
            New-Item -ItemType SymbolicLink -Path $Target -Target $Source -Force | Out-Null
            return "symbolic-link"
        } catch {
            return "mapped-only"
        }
    }
}

function ConvertTo-RowValue {
    param([AllowNull()][string]$Value)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace($Value)) { return "n/a" }
    return ($Value -replace "\|", "/").Trim()
}

$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$SkillLibraryRoot = (Resolve-Path -LiteralPath $SkillLibraryRoot).Path
$LoopDir = Join-Path $ProjectRoot ".ai-loop"
if (-not (Test-Path -LiteralPath (Join-Path $LoopDir "status.json") -PathType Leaf)) {
    throw "Missing .ai-loop/status.json. Run ai-loop init or init-loop.ps1 first."
}

$ProjectSkillsDir = Join-Path $ProjectRoot ".agents\skills"
New-Item -ItemType Directory -Force -Path $ProjectSkillsDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $LoopDir "skills") | Out-Null

$SelectedSkills = @((Get-SkillsForProfile -Name $Profile) + $Skills |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    Select-Object -Unique)
if ($SelectedSkills.Count -eq 0) {
    throw "No skills selected. Use -Profile or -Skills."
}

$Rows = New-Object System.Collections.Generic.List[string]
$Rows.Add("# Skill Source Map")
$Rows.Add("")
$Rows.Add("This file records project-visible skill links. Skill packages are not copied into `.ai-loop/`; they are exposed through `.agents/skills/` and audited here.")
$Rows.Add("")
$Rows.Add("| Skill | Source Path | Project Path | Link Type | Source Hash | Status | Notes |")
$Rows.Add("| --- | --- | --- | --- | --- | --- | --- |")

$Results = @()
foreach ($Skill in $SelectedSkills) {
    $Source = Join-Path $SkillLibraryRoot $Skill
    $SourceSkill = Join-Path $Source "SKILL.md"
    $Target = Join-Path $ProjectSkillsDir $Skill
    $RelativeTarget = ".agents/skills/$Skill"
    $LinkType = "missing"
    $Hash = "n/a"
    $Status = "unavailable"
    $Notes = ""

    if (-not (Test-Path -LiteralPath $SourceSkill -PathType Leaf)) {
        $Notes = "Missing source SKILL.md"
    } else {
        $Hash = (Get-FileHash -LiteralPath $SourceSkill -Algorithm SHA256).Hash
        if (Test-Path -LiteralPath $Target) {
            $Item = Get-Item -LiteralPath $Target -Force
            if (($Item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq [System.IO.FileAttributes]::ReparsePoint) {
                Remove-Item -LiteralPath $Target -Force
            } elseif ($Force) {
                throw "Refusing to replace non-link skill directory: $Target"
            } else {
                throw "Target already exists and is not a link: $Target"
            }
        }
        $LinkType = New-SkillLink -Source $Source -Target $Target
        if ($LinkType -eq "mapped-only") {
            $Status = "mapped-only"
            $Notes = "Could not create junction or symbolic link; source recorded only."
        } elseif (Test-Path -LiteralPath (Join-Path $Target "SKILL.md") -PathType Leaf) {
            $Status = "available"
            $Notes = "Linked from shared skill library."
        } else {
            $Status = "broken-link"
            $Notes = "Link was created but SKILL.md is not visible."
        }
    }

    $Rows.Add("| $(ConvertTo-RowValue $Skill) | $(ConvertTo-RowValue $Source) | $(ConvertTo-RowValue $RelativeTarget) | $(ConvertTo-RowValue $LinkType) | $(ConvertTo-RowValue $Hash) | $(ConvertTo-RowValue $Status) | $(ConvertTo-RowValue $Notes) |")
    $Results += [pscustomobject]@{
        skill = $Skill
        source = $Source
        project_path = $RelativeTarget
        link_type = $LinkType
        hash = $Hash
        status = $Status
        notes = $Notes
    }
}

$SourceMapPath = Join-Path $LoopDir "skills\skill-source-map.md"
$Rows | Set-Content -LiteralPath $SourceMapPath -Encoding utf8

Add-EventLogEntry -LoopDir $LoopDir -Event ([ordered]@{
    ts = (Get-Date).ToUniversalTime().ToString("o")
    type = "skill_trigger"
    actor = "ai-loop link-skills"
    summary = "Linked skills for profile $Profile"
    paths = @(".agents/skills", ".ai-loop/skills/skill-source-map.md")
    result = "recorded"
    profile = $Profile
    skills = @($Results)
})

Write-Output "Linked skill profile: $Profile"
Write-Output "Project skills: $ProjectSkillsDir"
Write-Output "Skill source map: $SourceMapPath"
foreach ($Result in $Results) {
    Write-Output "$($Result.skill): $($Result.status) ($($Result.link_type))"
}


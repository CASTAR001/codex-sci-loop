[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet("init", "start", "collect", "audit-pack", "validate", "validate-loop", "accept", "resume", "link-skills", "worker-preflight", "invoke-worker", "doctor")]
    [string]$Command,

    [Parameter(Position = 1)]
    [string]$ProjectRoot = (Get-Location).Path,

    [Parameter(Position = 2)]
    [string]$PhaseId = "",

    [string]$Title = "",
    [string]$Objective = "",
    [string[]]$Scope = @(),
    [string]$VerifyCommand = "",
    [string]$ReportPath = "",
    [string]$AuditPath = "",
    [ValidateSet("generic", "fullstack", "physics-research", "research-writing", "data-analysis")]
    [string]$TaskKind = "generic",
    [Alias("Profile")]
    [ValidateSet("none", "research-core", "physics-sim", "manuscript", "full-research")]
    [string]$SkillProfile = "none",
    [Alias("Skills")]
    [ValidateSet("research-task-tree", "invariant-contract", "bounded-experiment-loop", "deterministic-verification", "independent-crosscheck", "result-provenance-audit", "manuscript-consistency-audit", "skill-compliance-audit")]
    [string[]]$RequiredSkills = @(),
    [string[]]$ClaimIds = @(),
    [string]$SkillLibraryRoot = "E:\codexfiles\test\.agents\skills",
    [switch]$Commit,
    [string]$CommitMessage = "",
    [switch]$Force,
    [string]$OverrideReason = "",
    [switch]$CreateAgentsBootstrap,
    [ValidateSet("started", "evidence_collected", "audit_ready", "accepted")]
    [string]$TargetStatus = "audit_ready",
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

function Require-PhaseId {
    if ([string]::IsNullOrWhiteSpace($PhaseId)) {
        throw "PhaseId is required for '$Command'. Example: ai-loop $Command <project-root> phase-001"
    }
}

function Test-ResearchSkills {
    param([Parameter(Mandatory = $true)][string]$Root)
    $Required = @(
        "research-task-tree",
        "invariant-contract",
        "bounded-experiment-loop",
        "deterministic-verification",
        "independent-crosscheck",
        "result-provenance-audit",
        "manuscript-consistency-audit",
        "skill-compliance-audit"
    )
    $Problems = New-Object System.Collections.Generic.List[string]
    foreach ($Skill in $Required) {
        $Path = Join-Path $Root (Join-Path $Skill "SKILL.md")
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
            $Problems.Add($Skill)
        }
    }
    return $Problems
}

function Test-PluginSkillFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return "missing"
    }
    $Text = Get-Content -LiteralPath $Path -Raw
    if ($Text -notmatch "(?s)^---.*?name:\s*.+?description:\s*.+?---") {
        return "frontmatter-invalid"
    }
    return "ok"
}

function Test-NonEmptyFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return "missing" }
    $Item = Get-Item -LiteralPath $Path
    if ($Item.Length -le 0) { return "empty" }
    return "ok"
}

function ConvertTo-NormalizedArtifactPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return ($Path -replace "\\", "/").Trim()
}

function Exit-IfScriptFailed {
    param([Parameter(Mandatory = $true)][bool]$Succeeded)
    if (-not $Succeeded) {
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
        exit 1
    }
}

$KitRoot = Split-Path -Parent $PSScriptRoot
$ProjectRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ProjectRoot)

switch ($Command) {
    "init" {
        $ScriptParams = @{ ProjectRoot = $ProjectRoot }
        if ($Force) { $ScriptParams.Force = $true }
        $global:LASTEXITCODE = 0
        & (Join-Path $PSScriptRoot "init-loop.ps1") @ScriptParams
        Exit-IfScriptFailed -Succeeded $?
        $AgentSkillsDir = Join-Path $ProjectRoot ".agents\skills"
        try {
            New-Item -ItemType Directory -Force -Path $AgentSkillsDir | Out-Null
        } catch {
            Write-Warning "Could not initialize optional agent skill directory: $AgentSkillsDir. Reason: $($_.Exception.Message)"
        }
        if ($CreateAgentsBootstrap) {
            $AgentsPath = Join-Path $ProjectRoot "AGENTS.md"
            if ((Test-Path -LiteralPath $AgentsPath) -and -not $Force) {
                Write-Output "AGENTS.md already exists; leaving it unchanged: $AgentsPath"
            } else {
                @(
                    '# AGENTS.md'
                    ""
                    'This project uses `.ai-loop/` as the local Supervisor-Worker loop control plane.'
                    ""
                    'Before planning or modifying files, read:'
                    ""
                    '1. `.ai-loop/README.md`'
                    '2. `.ai-loop/memory/activeContext.md`'
                    '3. `.ai-loop/memory/constraint-ledger.md`'
                    '4. `.ai-loop/gates/pre-action-check.md`'
                    ""
                    'Do not accept work from prose alone; inspect evidence, diffs, verification logs, status, changed files, skill artifacts, and relevant source.'
                ) | Set-Content -LiteralPath $AgentsPath -Encoding utf8
                Write-Output "Created AGENTS.md bootstrap: $AgentsPath"
            }
        }
        Write-Output "Initialized agent skill directory if writable: $AgentSkillsDir"
    }
    "start" {
        Require-PhaseId
        $ScriptParams = @{
            ProjectRoot = $ProjectRoot
            PhaseId = $PhaseId
            Title = $Title
            Objective = $Objective
            VerifyCommand = $VerifyCommand
            TaskKind = $TaskKind
            SkillProfile = $SkillProfile
        }
        if ($Scope.Count -gt 0) { $ScriptParams.Scope = $Scope }
        if ($RequiredSkills.Count -gt 0) { $ScriptParams.RequiredSkills = $RequiredSkills }
        if ($ClaimIds.Count -gt 0) { $ScriptParams.ClaimIds = $ClaimIds }
        if ($Force) { $ScriptParams.Force = $true }
        $global:LASTEXITCODE = 0
        & (Join-Path $PSScriptRoot "start-phase.ps1") @ScriptParams
        Exit-IfScriptFailed -Succeeded $?
    }
    "collect" {
        Require-PhaseId
        $ScriptParams = @{
            ProjectRoot = $ProjectRoot
            PhaseId = $PhaseId
        }
        if (-not [string]::IsNullOrWhiteSpace($ReportPath)) { $ScriptParams.ReportPath = $ReportPath }
        if (-not [string]::IsNullOrWhiteSpace($VerifyCommand)) { $ScriptParams.VerifyCommand = $VerifyCommand }
        if ($Force) { $ScriptParams.Force = $true }
        $global:LASTEXITCODE = 0
        & (Join-Path $PSScriptRoot "collect-evidence.ps1") @ScriptParams
        Exit-IfScriptFailed -Succeeded $?
    }
    "audit-pack" {
        Require-PhaseId
        $ScriptParams = @{
            ProjectRoot = $ProjectRoot
            PhaseId = $PhaseId
        }
        $global:LASTEXITCODE = 0
        & (Join-Path $PSScriptRoot "prepare-audit-pack.ps1") @ScriptParams
        Exit-IfScriptFailed -Succeeded $?
    }
    "validate" {
        Require-PhaseId
        $ScriptParams = @{
            ProjectRoot = $ProjectRoot
            PhaseId = $PhaseId
            TargetStatus = $TargetStatus
        }
        $global:LASTEXITCODE = 0
        & (Join-Path $PSScriptRoot "validate-phase-gates.ps1") @ScriptParams
        Exit-IfScriptFailed -Succeeded $?
    }
    "validate-loop" {
        $ScriptParams = @{
            ProjectRoot = $ProjectRoot
        }
        $global:LASTEXITCODE = 0
        & (Join-Path $PSScriptRoot "validate-loop.ps1") @ScriptParams
        Exit-IfScriptFailed -Succeeded $?
    }
    "accept" {
        Require-PhaseId
        $ScriptParams = @{
            ProjectRoot = $ProjectRoot
            PhaseId = $PhaseId
        }
        if (-not [string]::IsNullOrWhiteSpace($AuditPath)) { $ScriptParams.AuditPath = $AuditPath }
        if (-not [string]::IsNullOrWhiteSpace($CommitMessage)) { $ScriptParams.CommitMessage = $CommitMessage }
        if (-not [string]::IsNullOrWhiteSpace($OverrideReason)) { $ScriptParams.OverrideReason = $OverrideReason }
        if ($Commit) { $ScriptParams.Commit = $true }
        if ($Force) { $ScriptParams.Force = $true }
        $global:LASTEXITCODE = 0
        & (Join-Path $PSScriptRoot "accept-phase.ps1") @ScriptParams
        Exit-IfScriptFailed -Succeeded $?
    }
    "resume" {
        $LoopDir = Join-Path $ProjectRoot ".ai-loop"
        $StatusPath = Join-Path $LoopDir "status.json"
        $Blocked = $false
        $Status = $null
        Write-Output "# AI Loop Resume Summary"
        Write-Output ""
        Write-Output "Project root: $ProjectRoot"
        if (-not (Test-Path -LiteralPath $StatusPath -PathType Leaf)) {
            Write-Output "Recovery decision: BLOCKED"
            Write-Output "Reason: missing .ai-loop/status.json"
            exit 2
        }
        try {
            $Status = Get-Content -LiteralPath $StatusPath -Raw | ConvertFrom-Json
        } catch {
            Write-Output "Recovery decision: BLOCKED"
            Write-Output "Reason: invalid .ai-loop/status.json :: $($_.Exception.Message)"
            exit 2
        }
        $CurrentPhase = $Status.current_phase
        if ($null -eq $CurrentPhase) {
            Write-Output "Current phase: none"
            Write-Output "Phase status: initialized"
            Write-Output "Last decision: $($Status.last_decision | ConvertTo-Json -Depth 10 -Compress)"
            Write-Output "Missing evidence: n/a"
            Write-Output "Required skills: none"
            Write-Output "Next safe action: start a bounded phase with ai-loop start."
        } else {
            $PhaseId = $CurrentPhase.phase_id
            $PhaseStatus = if ($null -ne $CurrentPhase.status) { $CurrentPhase.status } elseif ($null -ne $CurrentPhase.phase_status) { $CurrentPhase.phase_status } else { "unknown" }
            $RunDir = Join-Path $LoopDir (Join-Path "runs" $PhaseId)
            $RequirementsPath = Join-Path $RunDir "phase_requirements.json"
            $ArtifactManifestPath = Join-Path $LoopDir "evidence\artifact-manifest.json"
            $ArtifactManifestStatus = "missing"
            $ArtifactIntegrityProblemCount = 0
            $RequiredSkills = @()
            $MissingEvidence = New-Object System.Collections.Generic.List[string]
            $RequiredEvidencePaths = New-Object System.Collections.Generic.List[string]
            $RequiredFiles = @("prompt.md", "report.md", "status_after.txt", "diff.patch", "verify.log", "changed_files.txt", "changed_business_files.txt", "changed_evidence_files.txt", "phase_requirements.json")
            foreach ($Name in $RequiredFiles) {
                $RequiredEvidencePaths.Add(".ai-loop/runs/$PhaseId/$Name")
                $Check = Test-NonEmptyFile -Path (Join-Path $RunDir $Name)
                if ($Check -ne "ok") {
                    $MissingEvidence.Add("$Name ($Check)")
                }
            }
            if (Test-Path -LiteralPath $RequirementsPath -PathType Leaf) {
                try {
                    $Requirements = Get-Content -LiteralPath $RequirementsPath -Raw | ConvertFrom-Json
                    $RequiredSkills = @($Requirements.required_skills)
                    if ($null -ne $Requirements.PSObject.Properties["evidence_required"]) {
                        $RequiredEvidencePaths = New-Object System.Collections.Generic.List[string]
                        foreach ($EvidencePath in @($Requirements.evidence_required)) {
                            $RequiredEvidencePaths.Add([string]$EvidencePath)
                        }
                        $RequiredEvidencePaths.Add(".ai-loop/runs/$PhaseId/phase_requirements.json")
                    }
                    if ($null -ne $Requirements.PSObject.Properties["required_skill_artifacts"]) {
                        foreach ($Requirement in @($Requirements.required_skill_artifacts)) {
                            foreach ($Artifact in @($Requirement.artifacts)) {
                                $ArtifactCheck = Test-NonEmptyFile -Path (Join-Path $ProjectRoot $Artifact)
                                if ($ArtifactCheck -ne "ok") {
                                    $MissingEvidence.Add("$Artifact ($ArtifactCheck)")
                                }
                            }
                        }
                    }
                } catch {
                    $MissingEvidence.Add("phase_requirements.json (invalid json)")
                }
            }
            if (Test-Path -LiteralPath $ArtifactManifestPath -PathType Leaf) {
                try {
                    $ArtifactManifest = Get-Content -LiteralPath $ArtifactManifestPath -Raw | ConvertFrom-Json
                    $ArtifactManifestStatus = "present"
                    foreach ($EvidencePath in @($RequiredEvidencePaths)) {
                        $NormalizedPath = ConvertTo-NormalizedArtifactPath -Path $EvidencePath
                        $Record = @($ArtifactManifest.artifacts | Where-Object {
                            $_.phase -eq $PhaseId -and (ConvertTo-NormalizedArtifactPath -Path ([string]$_.path)) -eq $NormalizedPath
                        } | Select-Object -Last 1)
                        if ($Record.Count -eq 0) {
                            $ArtifactIntegrityProblemCount++
                            continue
                        }
                        $AbsolutePath = Join-Path $ProjectRoot ($NormalizedPath -replace "/", "\")
                        if (-not (Test-Path -LiteralPath $AbsolutePath -PathType Leaf)) {
                            $ArtifactIntegrityProblemCount++
                            continue
                        }
                        $CurrentHash = (Get-FileHash -LiteralPath $AbsolutePath -Algorithm SHA256).Hash
                        if ($Record[0].status -ne "recorded" -or $CurrentHash -ne $Record[0].sha256) {
                            $ArtifactIntegrityProblemCount++
                        }
                    }
                } catch {
                    $ArtifactManifestStatus = "invalid"
                    $ArtifactIntegrityProblemCount++
                }
            } else {
                $ArtifactIntegrityProblemCount = @($RequiredEvidencePaths).Count
            }
            $NextSafeAction = switch ($PhaseStatus) {
                "started" { "Give the Worker the phase prompt, then collect evidence after execution." }
                "phase_started" { "Give the Worker the phase prompt, then collect evidence after execution." }
                "evidence_collected" { "Run ai-loop audit-pack and inspect the generated audit input." }
                "audit_ready" { "Write a Codex audit decision after inspecting report, diff, verify log, ledgers, and source." }
                "accepted" { "Start the next bounded phase or update memory/handoff." }
                "rework" { "Start a rework phase using the audit findings as scope." }
                "blocked" { "Resolve the blocker before starting or accepting another phase." }
                default { "Run ai-loop validate; if state cannot be reconstructed, mark BLOCKED." }
            }
            if ($MissingEvidence.Count -gt 0 -and $PhaseStatus -notin @("started", "phase_started", "accepted")) {
                $Blocked = $true
            }
            if ($ArtifactIntegrityProblemCount -gt 0 -and $PhaseStatus -notin @("started", "phase_started", "accepted")) {
                $Blocked = $true
            }
            Write-Output "Current phase: $PhaseId"
            Write-Output "Phase status: $PhaseStatus"
            Write-Output "Last decision: $($Status.last_decision | ConvertTo-Json -Depth 10 -Compress)"
            Write-Output "Required skills: $(if ($RequiredSkills.Count -gt 0) { $RequiredSkills -join ', ' } else { 'none' })"
            Write-Output "Artifact manifest: $ArtifactManifestStatus"
            Write-Output "Artifact integrity problems: $ArtifactIntegrityProblemCount"
            Write-Output "Missing evidence:"
            if ($MissingEvidence.Count -eq 0) {
                Write-Output "- none"
            } else {
                foreach ($Item in $MissingEvidence) { Write-Output "- $Item" }
            }
            Write-Output "Next safe action: $NextSafeAction"
            if ($Blocked) {
                Write-Output "Recovery decision: BLOCKED"
            } else {
                Write-Output "Recovery decision: RESUMABLE"
            }
        }
        foreach ($Path in @(
            "memory\handoff-summary.md",
            "memory\activeContext.md",
            "memory\constraint-ledger.md",
            "evidence\evidence-ledger.md",
            "skills\skill-source-map.md",
            "status.json"
        )) {
            $FullPath = Join-Path $LoopDir $Path
            Write-Output ""
            Write-Output "===== .ai-loop/$($Path -replace '\\','/') ====="
            if (Test-Path -LiteralPath $FullPath -PathType Leaf) {
                Get-Content -LiteralPath $FullPath -Raw
            } else {
                Write-Output "MISSING: $FullPath"
            }
        }
        if ($Blocked) { exit 2 }
    }
    "link-skills" {
        $ScriptParams = @{
            ProjectRoot = $ProjectRoot
            SkillLibraryRoot = $SkillLibraryRoot
            Profile = $SkillProfile
        }
        if ($RequiredSkills.Count -gt 0) { $ScriptParams.Skills = $RequiredSkills }
        if ($Force) { $ScriptParams.Force = $true }
        $global:LASTEXITCODE = 0
        & (Join-Path $PSScriptRoot "link-skills.ps1") @ScriptParams
        Exit-IfScriptFailed -Succeeded $?
    }
    "worker-preflight" {
        Require-PhaseId
        $ScriptParams = @{
            ProjectRoot = $ProjectRoot
            PhaseId = $PhaseId
            WorkerProfile = $WorkerProfile
        }
        if (-not [string]::IsNullOrWhiteSpace($PromptPath)) { $ScriptParams.PromptPath = $PromptPath }
        if (-not [string]::IsNullOrWhiteSpace($WorkerStateRoot)) { $ScriptParams.WorkerStateRoot = $WorkerStateRoot }
        if ($AllowExternalService) { $ScriptParams.AllowExternalService = $true }
        if ($AllowSensitivePrompt) { $ScriptParams.AllowSensitivePrompt = $true }
        if ($Yolo) { $ScriptParams.Yolo = $true }
        $global:LASTEXITCODE = 0
        & (Join-Path $PSScriptRoot "preflight-worker.ps1") @ScriptParams
        Exit-IfScriptFailed -Succeeded $?
    }
    "invoke-worker" {
        Require-PhaseId
        $ScriptParams = @{
            ProjectRoot = $ProjectRoot
            PhaseId = $PhaseId
            WorkerProfile = $WorkerProfile
        }
        if (-not [string]::IsNullOrWhiteSpace($PromptPath)) { $ScriptParams.PromptPath = $PromptPath }
        if (-not [string]::IsNullOrWhiteSpace($WorkerStateRoot)) { $ScriptParams.WorkerStateRoot = $WorkerStateRoot }
        if ($AllowExternalService) { $ScriptParams.AllowExternalService = $true }
        if ($AllowSensitivePrompt) { $ScriptParams.AllowSensitivePrompt = $true }
        if ($Yolo) { $ScriptParams.Yolo = $true }
        if ($DryRun) { $ScriptParams.DryRun = $true }
        $global:LASTEXITCODE = 0
        & (Join-Path $PSScriptRoot "invoke-worker.ps1") @ScriptParams
        Exit-IfScriptFailed -Succeeded $?
    }
    "doctor" {
        $TemplateDir = Join-Path $KitRoot "templates\.ai-loop"
        $InstallRoot = Split-Path -Parent $KitRoot
        $PluginRoot = Join-Path $InstallRoot "plugins\codex-loop-harness"
        $PluginManifest = Join-Path $PluginRoot ".codex-plugin\plugin.json"
        $ShimPath = Join-Path $InstallRoot "bin\ai-loop.ps1"
        $SkillProblems = @(Test-ResearchSkills -Root $SkillLibraryRoot)
        Write-Output "ai-loop doctor"
        Write-Output "Kit root: $KitRoot"
        Write-Output "Template: $TemplateDir"
        Write-Output "Skill library: $SkillLibraryRoot"
        Write-Output "Plugin manifest: $PluginManifest"
        Write-Output "Shim: $ShimPath"
        if (-not (Test-Path -LiteralPath $TemplateDir -PathType Container)) { throw "Template directory missing: $TemplateDir" }
        $TemplateManifest = Join-Path $TemplateDir "evidence\artifact-manifest.json"
        if (-not (Test-Path -LiteralPath $TemplateManifest -PathType Leaf)) { throw "Template artifact manifest missing: $TemplateManifest" }
        $TemplateManifestJson = Get-Content -LiteralPath $TemplateManifest -Raw | ConvertFrom-Json
        if ($null -eq $TemplateManifestJson.PSObject.Properties["artifacts"]) { throw "Template artifact manifest missing artifacts array." }
        foreach ($WorkerPath in @(
            (Join-Path $KitRoot "worker-profiles\kimi-code.json"),
            (Join-Path $KitRoot "worker-profiles\kimi-code.md"),
            (Join-Path $PSScriptRoot "preflight-worker.ps1"),
            (Join-Path $PSScriptRoot "invoke-worker.ps1")
        )) {
            if (-not (Test-Path -LiteralPath $WorkerPath -PathType Leaf)) {
                throw "External Worker harness file missing: $WorkerPath"
            }
        }
        $WorkerProfileJson = Get-Content -LiteralPath (Join-Path $KitRoot "worker-profiles\kimi-code.json") -Raw | ConvertFrom-Json
        if ($WorkerProfileJson.profile -ne "kimi-code") { throw "Unexpected Worker profile name: $($WorkerProfileJson.profile)" }
        if (-not (Test-Path -LiteralPath $PluginManifest -PathType Leaf)) { throw "Plugin manifest missing: $PluginManifest" }
        $Plugin = Get-Content -LiteralPath $PluginManifest -Raw | ConvertFrom-Json
        if ($Plugin.name -ne "codex-loop-harness") { throw "Unexpected plugin name: $($Plugin.name)" }
        foreach ($SkillName in @("loop-supervisor", "loop-auditor", "loop-recovery", "research-loop-orchestrator")) {
            $SkillPath = Join-Path $PluginRoot (Join-Path "skills\$SkillName" "SKILL.md")
            $SkillCheck = Test-PluginSkillFile -Path $SkillPath
            if ($SkillCheck -ne "ok") {
                throw "Plugin skill check failed: $SkillName ($SkillCheck)"
            }
        }
        $PluginWrapper = Join-Path $PluginRoot "scripts\ai-loop.ps1"
        if (-not (Test-Path -LiteralPath $PluginWrapper -PathType Leaf)) {
            throw "Plugin wrapper missing: $PluginWrapper"
        }
        if ($SkillProblems.Count -gt 0) {
            throw "Missing required research skills: $($SkillProblems -join ', ')"
        }
        if (Test-Path -LiteralPath $ShimPath -PathType Leaf) {
            Write-Output "Shim status: OK"
        } else {
            Write-Output "Shim status: not installed in this layout"
        }
        Write-Output "Required research skills: OK"
        Write-Output "Plugin manifest JSON: OK"
        Write-Output "Plugin skill frontmatter: OK"
        Write-Output "Template artifact manifest: OK"
        Write-Output "External Worker harness: OK"
        Write-Output "Doctor: OK"
    }
}

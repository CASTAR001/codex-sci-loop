[CmdletBinding()]
param(
    [string]$KitRoot = "",
    [switch]$AllowPilotProject
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($KitRoot)) {
    $KitRoot = Split-Path -Parent $PSScriptRoot
}
$KitRoot = (Resolve-Path -LiteralPath $KitRoot).Path
$Problems = New-Object System.Collections.Generic.List[string]

function Add-Problem {
    param([Parameter(Mandatory = $true)][string]$Message)
    $script:Problems.Add($Message)
}

function Test-RequiredPath {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $Path = Join-Path $KitRoot $RelativePath
    if (-not (Test-Path -LiteralPath $Path)) {
        Add-Problem "Missing required path: $RelativePath"
    }
}

$RequiredPaths = @(
    "README.md",
    "PHASE_A_MANIFEST.md",
    "PHASE_A_VERIFICATION.md",
    "PHASE_B_PLAN.md",
    "templates\README.md",
    "templates\.ai-loop\README.md",
    "templates\.ai-loop\.gitignore",
    "templates\.ai-loop\loop.config.json",
    "templates\.ai-loop\status.json",
    "templates\.ai-loop\schema\schema-version.json",
    "templates\.ai-loop\schema\migration-log.md",
    "templates\.ai-loop\runs\README.md",
    "templates\.ai-loop\audits\README.md",
    "templates\.ai-loop\evidence\evidence-ledger.md",
    "templates\.ai-loop\evidence\artifact-manifest.json",
    "templates\.ai-loop\evidence\artifact-index.md",
    "templates\.ai-loop\evidence\command-log.md",
    "templates\.ai-loop\evidence\test-log.md",
    "templates\.ai-loop\evidence\provenance-map.md",
    "templates\.ai-loop\skills\skill-trigger-matrix.md",
    "templates\.ai-loop\skills\skill-usage-ledger.md",
    "templates\.ai-loop\skills\skill-artifact-map.md",
    "templates\.ai-loop\skills\skill-source-map.md",
    "templates\.ai-loop\evolution\project-loop-evolution.md",
    "templates\.ai-loop\workers\README.md",
    "docs\README.md",
    "docs\OPERATOR_RUNBOOK.md",
    "docs\GLOBAL_INSTALL_PLAN.md",
    "docs\CONTROL_PLANE_BUILD_PLAN.md",
    "docs\AGENTS_VS_AI_LOOP_BOUNDARY.md",
    "docs\EXTERNAL_WORKER_PROTOCOL.md",
    ".ai-loop\README.md",
    ".ai-loop\.gitignore",
    ".ai-loop\loop.config.json",
    ".ai-loop\status.json",
    ".ai-loop\schema\schema-version.json",
    ".ai-loop\schema\migration-log.md",
    ".ai-loop\evidence\README.md",
    ".ai-loop\evidence\evidence-ledger.md",
    ".ai-loop\evidence\artifact-manifest.json",
    ".ai-loop\evidence\artifact-index.md",
    ".ai-loop\evidence\command-log.md",
    ".ai-loop\evidence\test-log.md",
    ".ai-loop\evidence\provenance-map.md",
    ".ai-loop\skills\skill-trigger-matrix.md",
    ".ai-loop\skills\skill-usage-ledger.md",
    ".ai-loop\skills\skill-artifact-map.md",
    ".ai-loop\skills\skill-source-map.md",
    ".ai-loop\evolution\project-loop-evolution.md",
    ".ai-loop\workers\README.md",
    ".ai-loop\audits\README.md",
    ".ai-loop\logs\README.md",
    ".ai-loop\templates\phase-plan.md",
    ".ai-loop\templates\prompt.md",
    ".ai-loop\templates\report.md",
    ".ai-loop\templates\audit-input.md",
    ".ai-loop\templates\audit.md",
    "prompts\codex-supervisor.md",
    "prompts\kimi-worker.md",
    "prompts\codex-audit.md",
    "scripts\ai-loop.ps1",
    "scripts\init-loop.ps1",
    "scripts\migrate-loop.ps1",
    "scripts\link-skills.ps1",
    "scripts\preflight-worker.ps1",
    "scripts\invoke-worker.ps1",
    "scripts\record-state-transition.ps1",
    "scripts\extract-audit-findings.ps1",
    "scripts\scaffold-rework-phase.ps1",
    "scripts\start-phase.ps1",
    "scripts\collect-evidence.ps1",
    "scripts\prepare-audit-pack.ps1",
    "scripts\accept-phase.ps1",
    "scripts\decide-phase.ps1",
    "scripts\validate-phase-gates.ps1",
    "scripts\validate-loop.ps1",
    "scripts\Test-ValidateLoopFailures.ps1",
    "scripts\Test-CollectLedgerIdempotence.ps1",
    "scripts\Test-Phase004.ps1",
    "scripts\Test-SchemaVersioning.ps1",
    "scripts\Test-Phase005.ps1",
    "scripts\Test-MigrateLoop.ps1",
    "scripts\Test-PhaseDecisions.ps1",
    "scripts\Test-Phase006.ps1",
    "scripts\Test-StateTransitions.ps1",
    "scripts\Test-Phase007.ps1",
    "scripts\Test-Phase008.ps1",
    "scripts\Test-ReworkScaffold.ps1",
    "scripts\Test-Phase009.ps1",
    "scripts\Test-SkillArtifactManifest.ps1",
    "scripts\Test-Phase010.ps1",
    "scripts\test-temp-root.ps1",
    "scripts\Test-TempIsolation.ps1",
    "scripts\Test-Phase011.ps1",
    "scripts\Test-StartPhaseIdempotence.ps1",
    "scripts\Test-Phase012.ps1",
    "scripts\Test-ResumeDiagnostics.ps1",
    "scripts\Test-Phase013.ps1",
    "scripts\Test-ExternalWorkerEvidence.ps1",
    "scripts\Test-Phase014.ps1",
    "scripts\Test-AuditFindingExtraction.ps1",
    "scripts\Test-Phase015.ps1",
    "scripts\test-pilot-loop.ps1",
    "scripts\install-global.ps1",
    "scripts\Test-PluginInstall.ps1",
    "scripts\Initialize-AiLoop.ps1",
    "scripts\Start-LoopPhase.ps1",
    "scripts\Collect-LoopEvidence.ps1",
    "scripts\Prepare-LoopAuditPackage.ps1",
    "scripts\Accept-LoopPhase.ps1",
    "scripts\Test-LoopStandard.ps1",
    "worker-profiles\kimi-code.json",
    "worker-profiles\kimi-code.md",
    "..\README.md",
    "..\README_EN.md",
    "..\plugins\codex-loop-harness\.codex-plugin\plugin.json",
    "..\plugins\codex-loop-harness\skills\loop-supervisor\SKILL.md",
    "..\plugins\codex-loop-harness\skills\loop-auditor\SKILL.md",
    "..\plugins\codex-loop-harness\skills\loop-recovery\SKILL.md",
    "..\plugins\codex-loop-harness\skills\research-loop-orchestrator\SKILL.md",
    "..\plugins\codex-loop-harness\scripts\ai-loop.ps1"
)

foreach ($RelativePath in $RequiredPaths) {
    Test-RequiredPath -RelativePath $RelativePath
}

foreach ($JsonRelativePath in @(".ai-loop\loop.config.json", ".ai-loop\status.json", ".ai-loop\evidence\artifact-manifest.json", ".ai-loop\schema\schema-version.json", "templates\.ai-loop\loop.config.json", "templates\.ai-loop\status.json", "templates\.ai-loop\evidence\artifact-manifest.json", "templates\.ai-loop\schema\schema-version.json")) {
    $JsonPath = Join-Path $KitRoot $JsonRelativePath
    if (Test-Path -LiteralPath $JsonPath) {
        try {
            $null = Get-Content -LiteralPath $JsonPath -Raw | ConvertFrom-Json
        } catch {
            Add-Problem "Invalid JSON: $JsonRelativePath :: $($_.Exception.Message)"
        }
    }
}

$PluginJsonPath = Join-Path (Split-Path -Parent $KitRoot) "plugins\codex-loop-harness\.codex-plugin\plugin.json"
if (Test-Path -LiteralPath $PluginJsonPath) {
    try {
        $Plugin = Get-Content -LiteralPath $PluginJsonPath -Raw | ConvertFrom-Json
        if ($Plugin.name -ne "codex-loop-harness") {
            Add-Problem "Plugin manifest has unexpected name: $($Plugin.name)"
        }
        if ([string]::IsNullOrWhiteSpace($Plugin.skills)) {
            Add-Problem "Plugin manifest does not point to skills directory."
        }
    } catch {
        Add-Problem "Invalid plugin JSON: $($_.Exception.Message)"
    }
}

$WorkerProfilePath = Join-Path $KitRoot "worker-profiles\kimi-code.json"
if (Test-Path -LiteralPath $WorkerProfilePath) {
    try {
        $WorkerProfile = Get-Content -LiteralPath $WorkerProfilePath -Raw | ConvertFrom-Json
        if ($WorkerProfile.profile -ne "kimi-code") {
            Add-Problem "Worker profile has unexpected name: $($WorkerProfile.profile)"
        }
        foreach ($Field in @("command", "prompt_argument", "default_state_root", "state_env_var")) {
            if ([string]::IsNullOrWhiteSpace([string]$WorkerProfile.$Field)) {
                Add-Problem "Worker profile missing required field: $Field"
            }
        }
    } catch {
        Add-Problem "Invalid Worker profile JSON: $($_.Exception.Message)"
    }
}

foreach ($SkillFile in @(
    "..\plugins\codex-loop-harness\skills\loop-supervisor\SKILL.md",
    "..\plugins\codex-loop-harness\skills\loop-auditor\SKILL.md",
    "..\plugins\codex-loop-harness\skills\loop-recovery\SKILL.md",
    "..\plugins\codex-loop-harness\skills\research-loop-orchestrator\SKILL.md"
)) {
    $Path = Join-Path $KitRoot $SkillFile
    if (Test-Path -LiteralPath $Path) {
        $Text = Get-Content -LiteralPath $Path -Raw
        if ($Text -notmatch "(?s)^---.*?name:\s*.+?description:\s*.+?---") {
            Add-Problem "Plugin skill missing frontmatter name/description: $SkillFile"
        }
    }
}

$ConfigPath = Join-Path $KitRoot ".ai-loop\loop.config.json"
if (Test-Path -LiteralPath $ConfigPath) {
    $Config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
    $SchemaPath = Join-Path $KitRoot ".ai-loop\schema\schema-version.json"
    if (Test-Path -LiteralPath $SchemaPath) {
        $Schema = Get-Content -LiteralPath $SchemaPath -Raw | ConvertFrom-Json
        if ($Config.schema_version -ne $Schema.schema_version) {
            Add-Problem "loop.config.json schema_version must match schema-version.json."
        }
        if ($Schema.schema_name -ne "ai-loop-control-plane") {
            Add-Problem "schema-version.json has unexpected schema_name: $($Schema.schema_name)"
        }
    }
    $RequiredEvidence = @("prompt.md", "report.md", "diff.patch", "verify.log", "phase_requirements.json")
    foreach ($EvidenceName in $RequiredEvidence) {
        if ($Config.phase_evidence_required -notcontains $EvidenceName) {
            Add-Problem "loop.config.json missing phase evidence: $EvidenceName"
        }
    }
    foreach ($Decision in @("ACCEPTED", "REWORK", "BLOCKED")) {
        if ($Config.decisions -notcontains $Decision) {
            Add-Problem "loop.config.json missing decision: $Decision"
        }
    }
    if ($Config.evidence_ledgers -notcontains ".ai-loop/evidence/artifact-manifest.json") {
        Add-Problem "loop.config.json missing artifact manifest ledger entry."
    }
}

Get-ChildItem -LiteralPath (Join-Path $KitRoot "scripts") -Filter "*.ps1" | ForEach-Object {
    $Tokens = $null
    $Errors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$Tokens, [ref]$Errors)
    if ($Errors.Count -gt 0) {
        foreach ($ParseError in $Errors) {
            Add-Problem "PowerShell parse error in scripts\$($_.Name): $($ParseError.Message)"
        }
    }
}

$PluginScriptsDir = Join-Path (Split-Path -Parent $KitRoot) "plugins\codex-loop-harness\scripts"
if (Test-Path -LiteralPath $PluginScriptsDir -PathType Container) {
    Get-ChildItem -LiteralPath $PluginScriptsDir -Filter "*.ps1" | ForEach-Object {
        $Tokens = $null
        $Errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$Tokens, [ref]$Errors)
        if ($Errors.Count -gt 0) {
            foreach ($ParseError in $Errors) {
                Add-Problem "PowerShell parse error in plugin scripts\$($_.Name): $($ParseError.Message)"
            }
        }
    }
}

$InstallScriptPath = Join-Path $KitRoot "scripts\install-global.ps1"
if (Test-Path -LiteralPath $InstallScriptPath -PathType Leaf) {
    $InstallText = Get-Content -LiteralPath $InstallScriptPath -Raw
    foreach ($Needle in @("InstallRoot", "CodexHome", "SkillLibraryRoot", "InstallPlugin", "CreateShim", "CreateMarketplace", "MarketplaceName", "validate-loop", "migrate", "decide", "scaffold-rework", "worker-preflight", "invoke-worker", "ShimPath", "ai-loop.ps1")) {
        if ($InstallText -notmatch [regex]::Escape($Needle)) {
            Add-Problem "install-global.ps1 missing expected interface text: $Needle"
        }
    }
}

$AiLoopScriptPath = Join-Path $KitRoot "scripts\ai-loop.ps1"
if (Test-Path -LiteralPath $AiLoopScriptPath -PathType Leaf) {
    $AiLoopText = Get-Content -LiteralPath $AiLoopScriptPath -Raw
    foreach ($Needle in @("TargetStatus", "validate-phase-gates.ps1", "validate-loop.ps1", "migrate-loop.ps1", "decide-phase.ps1", "extract-audit-findings.ps1", "scaffold-rework-phase.ps1", "worker-preflight", "invoke-worker")) {
        if ($AiLoopText -notmatch [regex]::Escape($Needle)) {
            Add-Problem "ai-loop.ps1 missing expected interface text: $Needle"
        }
    }
}

$RecordTransitionScriptPath = Join-Path $KitRoot "scripts\record-state-transition.ps1"
if (Test-Path -LiteralPath $RecordTransitionScriptPath -PathType Leaf) {
    $RecordTransitionText = Get-Content -LiteralPath $RecordTransitionScriptPath -Raw
    foreach ($Needle in @("state-transitions.ndjson", "from_status", "to_status", "phase_id")) {
        if ($RecordTransitionText -notmatch [regex]::Escape($Needle)) {
            Add-Problem "record-state-transition.ps1 missing expected transition text: $Needle"
        }
    }
}

$MigrateScriptPath = Join-Path $KitRoot "scripts\migrate-loop.ps1"
if (Test-Path -LiteralPath $MigrateScriptPath -PathType Leaf) {
    $MigrateText = Get-Content -LiteralPath $MigrateScriptPath -Raw
    foreach ($Needle in @("migration-record.json", "schema_version", "Merge-TemplateDirectory", "event-log.ndjson", "Cannot migrate future schema")) {
        if ($MigrateText -notmatch [regex]::Escape($Needle)) {
            Add-Problem "migrate-loop.ps1 missing expected migration text: $Needle"
        }
    }
}

$ScaffoldReworkScriptPath = Join-Path $KitRoot "scripts\scaffold-rework-phase.ps1"
if (Test-Path -LiteralPath $ScaffoldReworkScriptPath -PathType Leaf) {
    $ScaffoldReworkText = Get-Content -LiteralPath $ScaffoldReworkScriptPath -Raw
    foreach ($Needle in @("Decision: REWORK", "rework_source.json", "scaffolded_phase_id", "Do not broaden beyond the audit findings", "structured_findings")) {
        if ($ScaffoldReworkText -notmatch [regex]::Escape($Needle)) {
            Add-Problem "scaffold-rework-phase.ps1 missing expected rework text: $Needle"
        }
    }
}

$DecideScriptPath = Join-Path $KitRoot "scripts\decide-phase.ps1"
if (Test-Path -LiteralPath $DecideScriptPath -PathType Leaf) {
    $DecideText = Get-Content -LiteralPath $DecideScriptPath -Raw
    foreach ($Needle in @("REWORK", "BLOCKED", "phase_decision", "rework.txt", "blocked.txt", "last_decision", "audit_findings")) {
        if ($DecideText -notmatch [regex]::Escape($Needle)) {
            Add-Problem "decide-phase.ps1 missing expected decision text: $Needle"
        }
    }
}

$ExtractFindingsScriptPath = Join-Path $KitRoot "scripts\extract-audit-findings.ps1"
if (Test-Path -LiteralPath $ExtractFindingsScriptPath -PathType Leaf) {
    $ExtractFindingsText = Get-Content -LiteralPath $ExtractFindingsScriptPath -Raw
    foreach ($Needle in @("Finding:", "finding_id", "finding_count", "findings_path")) {
        if ($ExtractFindingsText -notmatch [regex]::Escape($Needle)) {
            Add-Problem "extract-audit-findings.ps1 missing expected extraction text: $Needle"
        }
    }
}

$CollectEvidenceScriptPath = Join-Path $KitRoot "scripts\collect-evidence.ps1"
if (Test-Path -LiteralPath $CollectEvidenceScriptPath -PathType Leaf) {
    $CollectEvidenceText = Get-Content -LiteralPath $CollectEvidenceScriptPath -Raw
    foreach ($Needle in @("ConvertTo-ProjectRelativeGitPath", "ConvertFrom-GitStatusLine", "Remove-MarkdownRowsForPhase", "PreviousErrorActionPreference", "rev-parse --show-prefix", "status --porcelain", "changed_business_files.txt", "changed_evidence_files.txt", "skill-artifact", "required_skill_artifacts")) {
        if ($CollectEvidenceText -notmatch [regex]::Escape($Needle)) {
            Add-Problem "collect-evidence.ps1 missing expected classification text: $Needle"
        }
    }
    if ($CollectEvidenceText -notmatch "Set-Content\s+-LiteralPath\s+\`$Path\s+-Encoding\s+utf8\s+-Value\s+\`$Filtered") {
        Add-Problem "collect-evidence.ps1 should rewrite filtered ledger rows with Set-Content -Value to avoid read/write stream conflicts."
    }
}

$StartPhaseScriptPath = Join-Path $KitRoot "scripts\start-phase.ps1"
if (Test-Path -LiteralPath $StartPhaseScriptPath -PathType Leaf) {
    $StartPhaseText = Get-Content -LiteralPath $StartPhaseScriptPath -Raw
    foreach ($Needle in @("Remove-MarkdownRowsForPhase", "ExistingPhases", "SkillUsageLedger")) {
        if ($StartPhaseText -notmatch [regex]::Escape($Needle)) {
            Add-Problem "start-phase.ps1 missing expected idempotence text: $Needle"
        }
    }
}

$AiLoopScriptPath = Join-Path $KitRoot "scripts\ai-loop.ps1"
if (Test-Path -LiteralPath $AiLoopScriptPath -PathType Leaf) {
    $AiLoopText = Get-Content -LiteralPath $AiLoopScriptPath -Raw
    foreach ($Needle in @("Read-StateTransitions", "Latest transition:", "Transition consistency:", "Next safe command:")) {
        if ($AiLoopText -notmatch [regex]::Escape($Needle)) {
            Add-Problem "ai-loop.ps1 missing expected resume diagnostic text: $Needle"
        }
    }
}

foreach ($WrapperName in @("Initialize-AiLoop.ps1", "Start-LoopPhase.ps1", "Collect-LoopEvidence.ps1", "Prepare-LoopAuditPackage.ps1", "Accept-LoopPhase.ps1")) {
    $WrapperPath = Join-Path $KitRoot (Join-Path "scripts" $WrapperName)
    if (Test-Path -LiteralPath $WrapperPath -PathType Leaf) {
        $WrapperText = Get-Content -LiteralPath $WrapperPath -Raw
        if ($WrapperText -notmatch "ai-loop\.ps1") {
            Add-Problem "Compatibility wrapper does not call ai-loop.ps1: $WrapperName"
        }
        if ($WrapperText -match "Write-JsonFile") {
            Add-Problem "Compatibility wrapper still contains legacy state logic: $WrapperName"
        }
    }
}

$RootReadme = Join-Path (Split-Path -Parent $KitRoot) "README.md"
if (Test-Path -LiteralPath $RootReadme -PathType Leaf) {
    $ReadmeText = Get-Content -LiteralPath $RootReadme -Encoding utf8 -Raw
    foreach ($Needle in @("README_EN.md", "AGENTS.md", "ai-loop.ps1", "loop-standard")) {
        if ($ReadmeText -notmatch [regex]::Escape($Needle)) {
            Add-Problem "Root README.md missing expected UTF-8 text: $Needle"
        }
    }
}

$OldEvidenceName = "worker" + "-report.md"
$OldNameHits = @(Get-ChildItem -LiteralPath $KitRoot -Recurse -Force -File |
    Select-String -Pattern $OldEvidenceName -SimpleMatch)
if ($OldNameHits.Count -gt 0) {
    foreach ($Hit in $OldNameHits) {
        Add-Problem "Old evidence name found: $($Hit.Path):$($Hit.LineNumber)"
    }
}

$WorkspaceRoot = Split-Path -Parent $KitRoot
$PilotPath = Join-Path $WorkspaceRoot "pilot-project"
if (Test-Path -LiteralPath $PilotPath) {
    if (-not $AllowPilotProject) {
        Add-Problem "pilot-project exists; Phase A self-check expects no pilot project yet: $PilotPath"
    }
}

if ($Problems.Count -gt 0) {
    Write-Output "Loop standard self-check: FAILED"
    foreach ($Problem in $Problems) {
        Write-Output "- $Problem"
    }
    exit 1
}

Write-Output "Loop standard self-check: OK"
Write-Output "Kit root: $KitRoot"
Write-Output "Checked paths: $($RequiredPaths.Count)"

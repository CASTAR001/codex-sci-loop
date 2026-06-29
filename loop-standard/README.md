# Supervisor-Worker Loop Standard Kit

This kit defines a reusable coding loop where Codex acts as Supervisor and
Kimi Code acts as Worker. The Worker executes only the current phase. Codex
owns route planning, evidence review, audit decisions, and phase acceptance.

## Directory Layout

- `templates/` - canonical project templates, including `.ai-loop/`.
- `.ai-loop/` - compatibility copy of the project loop template retained from
  the first draft.
- `scripts/` - Windows PowerShell scripts for loop operations.
- `prompts/` - reusable prompts for Supervisor, Worker, and Audit.
- `docs/` - operational documentation.
- `PHASE_A_MANIFEST.md` - durable Phase A file inventory and verification
  summary.
- `PHASE_A_VERIFICATION.md` - latest recorded Phase A verification result.
- `PHASE_B_PLAN.md` - next-phase pilot plan; it documents Phase B without
  starting it.

The `.ai-loop/templates/` directory includes human-readable templates for
`prompt.md`, `report.md`, `audit-input.md`, `audit.md`, and phase planning.

Phase A of this kit creates the reusable framework only. It does not run the
pilot project.

Check the standard kit without creating a project:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-LoopStandard.ps1
```

After `pilot-project/` exists, add `-AllowPilotProject`.

For global migration planning, read `docs/GLOBAL_INSTALL_PLAN.md`.
For 1.0 delivery notes and the operator checklist, read
`docs/RELEASE_NOTES_1.0.md` and `docs/OPERATOR_CHECKLIST_1.0.md`.

## Unified Command

Use `scripts/ai-loop.ps1` as the canonical command surface:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\ai-loop.ps1 doctor
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\ai-loop.ps1 init "C:\path\to\project"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\ai-loop.ps1 link-skills "C:\path\to\project" -SkillProfile full-research
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\ai-loop.ps1 start "C:\path\to\project" phase-001 -TaskKind physics-research -SkillProfile physics-sim
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\ai-loop.ps1 worker-preflight "C:\path\to\project" phase-001 -WorkerProfile kimi-code -Yolo
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\ai-loop.ps1 invoke-worker "C:\path\to\project" phase-001 -WorkerProfile kimi-code -AllowExternalService -Yolo
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\ai-loop.ps1 readiness "C:\path\to\project" -Json
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\ai-loop.ps1 release-check "C:\path\to\project" -Json
```

The lower-level scripts remain available for compatibility, but new workflows
should call `ai-loop.ps1`.

External Worker invocation is Worker-agnostic. `worker-preflight` records the
prompt hash, state directory, external service status, yolo mode, and approval
requirements. `invoke-worker` refuses to run unless preflight returns
`SAFE_TO_INVOKE`. The first thin Worker profile is `worker-profiles/kimi-code`.
When a phase is expected to use an external Worker, start it with
`-RequireExternalWorkerEvidence -WorkerProfile <profile>`. The phase then
requires `external-worker-preflight.json/.md` and
`external-worker-invocation.json/.log`; collect records them as
`external-worker-evidence`, and validate/audit block if they are missing or
stale.

To install a temporary global layout with a shim:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-global.ps1 `
  -InstallRoot "C:\path\to\loop-install" `
  -InstallPlugin `
  -CreateShim `
  -CreateMarketplace `
  -SkillLibraryRoot "E:\codexfiles\test\.agents\skills" `
  -Force
```

Then call:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\path\to\loop-install\bin\ai-loop.ps1" -Command doctor
```

`-CreateMarketplace` creates a local Codex marketplace file at
`<install-root>\.agents\plugins\marketplace.json` for discovery smoke tests. It
does not modify real global Codex configuration or run `codex plugin add`.

Run the plugin install/discovery smoke test from this repository:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-PluginInstall.ps1
```

## Required Phase Evidence

Every phase must produce these files under `.ai-loop/runs/<phase-id>/`:

- `prompt.md` - Codex-generated Worker prompt for the current phase.
- `report.md` - Kimi Worker report after executing the phase.
- `diff.patch` - project diff captured by the evidence script.
- `verify.log` - verification command output and exit code.
- `status_after.txt` - git status after Worker execution.
- `phase_requirements.json` - task kind, claim IDs, required evidence, and
  required skill artifacts for gate validation.

The audit input is created under `.ai-loop/audits/<phase-id>-audit-input.md`.
The final audit result is written to `.ai-loop/audits/<phase-id>-audit.md` with
exactly one decision:

- `ACCEPTED`
- `REWORK`
- `BLOCKED`

Codex must not accept a phase by reading only the Worker report. It must inspect
the report, diff, verification log, status, phase requirements, evidence
ledgers, skill ledgers, and relevant source files.

Required evidence file names are canonical:
`prompt.md`, `report.md`, `diff.patch`, `verify.log`, `status_after.txt`,
`phase_requirements.json`, `changed_files.txt`, `changed_business_files.txt`,
and `changed_evidence_files.txt`.

## Evidence, Skills, And Gates

Initialized projects include:

- `.ai-loop/evidence/` - evidence ledger, artifact index, artifact manifest,
  command log, test log, and provenance map.
- `.ai-loop/skills/` - skill trigger matrix, skill usage ledger, and skill
  artifact map.
- `.ai-loop/evolution/project-loop-evolution.md` - append-only project-local
  loop improvement proposals.

The 8 scientific workflow skills are referenced by name. They are not copied
into every project. Use `-TaskKind physics-research`, `research-writing`, or
`data-analysis` to trigger default required skill artifacts. Use
`-RequiredSkills` when the Supervisor needs a specific skill gate. Use
`link-skills.ps1` or `ai-loop.ps1 link-skills` to expose skills through
project-local `.agents/skills/`.

Research profiles:

- `research-core`
- `physics-sim`
- `manuscript`
- `full-research`

Validate a phase gate directly:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-phase-gates.ps1 `
  -ProjectRoot "C:\path\to\project" `
  -PhaseId "phase-001" `
  -TargetStatus audit_ready
```

Validate the whole `.ai-loop` control plane during recovery or preflight:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\ai-loop.ps1 `
  -Command validate-loop `
  -ProjectRoot "C:\path\to\project"
```

Evidence integrity uses a dual-track model. Markdown ledgers are for human
audit. `.ai-loop/evidence/artifact-manifest.json` is machine-readable and
records SHA256, file size, modified time, phase, and path. `collect` records
both required evidence and required skill artifacts for the current phase.
Required skill artifacts use the `skill-artifact` type. `validate` blocks them
when they are missing, empty, contain a `MISSING:` placeholder, or no longer
match the recorded SHA256.

If `phase_requirements.json` declares required external Worker evidence,
`collect` also records the preflight and invocation artifacts in the manifest.

Use the readiness command when deciding whether a project and this kit are close
to a 1.0 delivery claim:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\ai-loop.ps1 `
  -Command readiness `
  -ProjectRoot "C:\path\to\project"
```

Add `-Json` for scripts, hooks, CI, and plugin checks. The command is read-only:
it reports blocking gaps and warnings across kit files, templates, project
`.ai-loop`, evidence/state support, plugin scaffold, tests, and loop-wide
validation. Real global Codex plugin discovery remains a warning unless the user
explicitly approves modifying global Codex configuration.

Use the release-check command for final 1.0 sign-off:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\ai-loop.ps1 `
  -Command release-check `
  -ProjectRoot "C:\path\to\project"
```

`release-check` aggregates readiness, loop-wide validation, and the current
non-global verification matrix. Add `-Json` for automation. Use `-SkipMatrix`
only for quick diagnostics before a full release run.

Test fixtures use ignored `.tmp-ai-loop-*` parent directories, but default test
runs create unique `run-<timestamp>-<pid>-<id>` children. This keeps smoke and
fixture tests from deleting or sharing the same install root when two test
matrices run concurrently. Pass each test's `-KeepTemp` switch when you need to
inspect the generated fixture directory after a run.

## Schema And Migration Versioning

Initialized projects include `.ai-loop/schema/schema-version.json` and
`.ai-loop/schema/migration-log.md`. The schema manifest records the current
control-plane schema, minimum supported schema, latest schema, and the
`status.json` state-file schema. `validate-loop` blocks missing schema files,
unsupported old projects, future schema versions, and config/status schema
mismatches so upgrades are explicit rather than guessed from chat history.

Upgrade an existing project non-destructively with:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\ai-loop.ps1 `
  -Command migrate `
  -ProjectRoot "C:\path\to\project" `
  -DryRun
```

Use `-Json` with `-DryRun` when a script, plugin, or hook needs a
machine-readable migration plan:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\ai-loop.ps1 `
  -Command migrate `
  -ProjectRoot "C:\path\to\project" `
  -DryRun `
  -Json
```

Apply the migration after reviewing the plan:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\ai-loop.ps1 `
  -Command migrate `
  -ProjectRoot "C:\path\to\project"
```

`migrate` copies missing template files, applies declared semantic transforms
from `.ai-loop/schema/migration-transforms.json`, merges missing top-level JSON
properties, upgrades schema markers, writes `.ai-loop/schema/migration-records/`,
and appends `.ai-loop/schema/migration-log.md`. It preserves project memory,
evidence ledgers, and business files. A future schema version is blocked unless
the Supervisor explicitly passes `-Force`.
`migrate -DryRun` performs the same compatibility checks but does not create
records, modify JSON, append event logs, or copy template files.

State changes are recorded in `.ai-loop/events/state-transitions.ndjson`. For
new phases that declare `transition_log`, `validate-loop` checks that the latest
transition entry matches the phase status in `status.json`.

## Quick Start In A Project

From this kit directory:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\ai-loop.ps1 -Command init -ProjectRoot "C:\path\to\project" -CreateAgentsBootstrap
```

Start a phase:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\ai-loop.ps1 `
  -Command start `
  -ProjectRoot "C:\path\to\project" `
  -PhaseId "phase-001" `
  -Title "Implement minimal feature" `
  -Objective "Make the smallest scoped code change and verify it." `
  -TaskKind "fullstack"
```

If a Supervisor intentionally restarts the same unfinished phase, pass `-Force`
to `start`. The command refreshes the phase metadata, prompt, requirements, and
start-time Markdown ledger rows, and replaces the same phase entry in
`status.json` instead of appending a duplicate. It does not bypass audit or
acceptance gates.

After Kimi executes the generated prompt, collect evidence:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\ai-loop.ps1 `
  -Command collect `
  -ProjectRoot "C:\path\to\project" `
  -PhaseId "phase-001" `
  -ReportPath "C:\path\to\report.md" `
  -VerifyCommand "npm test"
```

Prepare the audit package:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\ai-loop.ps1 `
  -Command audit-pack `
  -ProjectRoot "C:\path\to\project" `
  -PhaseId "phase-001"
```

After Codex writes `.ai-loop/audits/phase-001-audit.md`, record the decision:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\ai-loop.ps1 `
  -Command accept `
  -ProjectRoot "C:\path\to\project" `
  -PhaseId "phase-001"
```

If a Supervisor intentionally overrides a failed gate, the command must include
both `-Force` and `-OverrideReason`; the override is appended to
`.ai-loop/events/event-log.ndjson`.

Use `REWORK` or `BLOCKED` instead of `ACCEPTED` when evidence is incomplete,
verification fails, the diff does not match the phase objective, or source
inspection reveals unresolved issues.

Record non-accepted decisions with `decide`, not `accept`:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\ai-loop.ps1 `
  -Command decide `
  -ProjectRoot "C:\path\to\project" `
  -PhaseId "phase-001" `
  -Decision REWORK `
  -Reason "Audit found a scoped fix is required."

powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\ai-loop.ps1 `
  -Command decide `
  -ProjectRoot "C:\path\to\project" `
  -PhaseId "phase-001" `
  -Decision BLOCKED `
  -Reason "Required evidence is missing."
```

The decision command writes `rework.txt` or `blocked.txt`, generates
`.ai-loop/audits/<phase>-findings.json`, updates `status.json` and
`phase_meta.json`, appends an event-log row, and lets `resume` reconstruct the
next safe action from files.

Use `resume` after interruption or when entering a project in a new session:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\ai-loop.ps1 `
  -Command resume `
  -ProjectRoot "C:\path\to\project"
```

The resume summary includes latest transition, recent transitions, transition
consistency, missing evidence, next safe action, and a copyable next safe
command. A transition/status mismatch is reported as `Recovery decision:
BLOCKED`.

For scripts, plugins, or hooks, add `-Json` to emit only machine-readable
recovery state:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\ai-loop.ps1 `
  -Command resume `
  -ProjectRoot "C:\path\to\project" `
  -Json
```

The JSON includes current phase, required skills, missing evidence, artifact
manifest status, transition consistency, next safe action, next safe command,
and recovery decision.

Prune ignored test fixture runs after heavy dogfood or smoke testing:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\ai-loop.ps1 `
  -Command prune-temp `
  -ProjectRoot "C:\path\to\project" `
  -MinAgeHours 24 `
  -KeepLatest 2
```

`prune-temp` is dry-run by default. It only considers `run-*` child directories
under `.tmp-ai-loop-*` parents, keeps the newest runs per parent, and requires
`-Force` before deletion:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\ai-loop.ps1 `
  -Command prune-temp `
  -ProjectRoot "C:\path\to\project" `
  -MinAgeHours 24 `
  -KeepLatest 2 `
  -Force
```

Add `-Json` when automation needs a machine-readable summary:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\ai-loop.ps1 `
  -Command prune-temp `
  -ProjectRoot "C:\path\to\project" `
  -MinAgeHours 24 `
  -KeepLatest 2 `
  -Json
```

The JSON includes the cleanup mode, candidate count, deleted count, candidate
rows, deleted rows, skipped reparse-point paths, and generation timestamp.

For `REWORK`, scaffold a bounded follow-up phase from the durable decision:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\ai-loop.ps1 `
  -Command scaffold-rework `
  -ProjectRoot "C:\path\to\project" `
  -PhaseId "phase-001" `
  -ReworkPhaseId "phase-002"
```

`scaffold-rework` refuses non-REWORK source phases. It uses the source audit,
structured findings JSON, and `rework.txt` as fixed scope inputs, creates the
follow-up phase prompt and requirements, and writes
`.ai-loop/runs/<rework-phase>/rework_source.json`. Audit authors can write
`Finding:`, `Severity:`, `Required fix:`, `Evidence:`, and `Files:` lines; the
extractor records them as machine-readable rework scope.

## Next Phase

Phase B should create `pilot-project/`, initialize `.ai-loop` inside it, run one
minimal Worker phase, collect evidence, prepare an audit package, and make a
Codex audit decision.

See `PHASE_B_PLAN.md` for the file-based checklist.

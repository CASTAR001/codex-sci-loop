# Handoff Summary

## Current Phase

External Worker invocation hardening is implemented; dogfood phase-001,
loop-standard self-loop phases 002-003, and root self-loop phases 001-016 have
been accepted. Root phase-016 added machine-readable resume output.

## Last Verified State

`loop-standard/` exists with scripts, docs, prompts, templates, pilot fixture,
and e2e validation. `pilot-project/` is a root-tracked fixture, not a nested git
repository. The latest self-check reports 95 required paths.

Dogfood setup succeeded: the temporary project has its own git repo, `.ai-loop/`
control plane, project-local `AGENTS.md`, `.agents/skills/` junctions for all 8
research workflow skills, and phase-001 evidence files.

Dogfood phase-001 was completed after the user ran Kimi Code externally. Codex
then collected evidence, validated gates, prepared an audit pack, wrote
`Decision: ACCEPTED`, and ran `accept` successfully.

The harness now has a generic external Worker layer: `worker-preflight` records
safety/feasibility review, and `invoke-worker` only runs after a safe preflight.
Kimi Code is represented as a thin Worker profile, not as a hard-coded route.
`-Yolo` is allowed without a separate stop, but external service invocation,
sensitive prompt content, and long-term memory/governance upgrades still require
explicit user confirmation.

Self-loop phase-002 used `loop-standard/.ai-loop` as the project control plane
and accepted a narrow improvement: `ai-loop validate` now supports
`-TargetStatus`, including `accepted`, through the unified entrypoint.
Self-loop phase-003 accepted changed-file classification normalization: git
paths are made relative to `ProjectRoot` before business/evidence splitting.
Root self-loop phase-001 made the repository root `.ai-loop` directly runnable:
`init` now merges missing templates into existing control planes without
overwriting memory, optional `.agents/skills` creation is recoverable, runtime
templates/state exist at root, collect includes untracked files in changed-file
evidence, and collect-time Markdown ledgers are idempotent per phase.
Root self-loop phase-002 added a repository-local plugin install/discovery smoke
test: `install-global.ps1 -CreateMarketplace` creates a temporary Codex-style
local marketplace, `Test-PluginInstall.ps1` validates the installed
`codex-loop-harness` manifest, four plugin skills, shim `doctor`, and plugin
wrapper `doctor`, and plugin skill docs no longer hardcode the development repo
script path.
Root self-loop phase-003 added `validate-loop.ps1` and exposed it through
`ai-loop -Command validate-loop`. It checks `.ai-loop` structure, recovery
critical files, `status.json`, duplicate phase IDs, current phase consistency,
accepted audit decisions, accepted phase `accepted.txt`, and accepted phase
gates.
Root self-loop phase-004 added `Test-ValidateLoopFailures.ps1`, a fixture test
suite that copies the root `.ai-loop/` into ignored temp projects and mutates
the copied state to prove `validate-loop.ps1` rejects duplicate phase IDs,
broken `current_phase`, illegal statuses, missing accepted audits, stale
artifact hashes, and missing recovery-critical files. `Test-Phase004.ps1`
aggregates the main self-check, plugin install smoke test, failure fixtures,
collect idempotence, and root loop validation. The same phase fixed
`collect-evidence.ps1` so ledger row refreshes do not fail on same-file
read/write streams and non-fatal verification stderr is captured as log evidence
instead of aborting collection.
Root self-loop phase-005 added `.ai-loop/schema/schema-version.json` and
`.ai-loop/schema/migration-log.md` to root, template, and compatibility control
planes. `validate-loop.ps1` now checks schema manifests, required schema
properties, config schema compatibility, future schemas, config/manifest
mismatches, and status schema compatibility. `Test-SchemaVersioning.ps1` covers
valid init plus six blocking schema cases, and `Test-Phase005.ps1` aggregates
the current non-global verification matrix.
Root self-loop phase-006 added `decide-phase.ps1` and exposed it as
`ai-loop -Command decide`. `ACCEPTED` still uses `accept`; `REWORK` and
`BLOCKED` now require matching audit decisions and are recorded into
`status.json`, `phase_meta.json`, `rework.txt` or `blocked.txt`, and
`event-log.ndjson`. `validate-loop.ps1` validates those non-accepted terminal
states, and `Test-PhaseDecisions.ps1` proves REWORK, BLOCKED, resume recovery,
and decision mismatch rejection.
Root self-loop phase-007 added `migrate-loop.ps1` and exposed it as
`ai-loop -Command migrate`. Existing `.ai-loop` projects can now be repaired
without overwriting project memory or evidence: missing template files are
copied, missing top-level JSON properties are merged, schema markers are
upgraded, migration backups and records are written under
`.ai-loop/schema/migration-records/`, and `event-log.ndjson` gets a migration
event. `Test-MigrateLoop.ps1` proves old-project repair, project memory
preservation, missing-template restoration, future-schema blocking, and missing
`.ai-loop` rejection. `Test-Phase007.ps1` is the current non-global verification
matrix.
Root self-loop phase-008 added `.ai-loop/events/state-transitions.ndjson`,
`record-state-transition.ps1`, and schema `1.3`. Canonical scripts now record
phase status transitions for start, collect, audit-pack, accept, and
REWORK/BLOCKED decisions. `validate-loop.ps1` validates transition log JSON and
checks that phases declaring `transition_log` have a latest transition matching
their current status. `Test-StateTransitions.ps1` proves a normal lifecycle and
tampered latest-transition rejection. `Test-Phase008.ps1` is now the current
non-global verification matrix.
Root self-loop phase-009 added `scaffold-rework-phase.ps1` and exposed it as
`ai-loop -Command scaffold-rework`. A durable source phase in `rework` status
can now create a bounded follow-up phase whose prompt scope is derived from the
source audit and `rework.txt`; the command writes `rework_source.json`, updates
status, and refuses BLOCKED/non-REWORK sources. `Test-ReworkScaffold.ps1`
proves REWORK scaffold creation and BLOCKED refusal.
Root self-loop phase-010 added required skill artifact hashing. Declared
required skill artifacts are now written as `skill-artifact` rows in the human
artifact index and machine artifact manifest during collection. The new
`Test-SkillArtifactManifest.ps1` fixture proves recorded skill artifacts pass,
post-collection mutations fail with hash mismatch, and missing required skill
artifacts are still visible in the manifest as missing evidence.
Root self-loop phase-011 added `test-temp-root.ps1` and
`Test-TempIsolation.ps1`. Fixture and smoke tests now keep the ignored
`.tmp-ai-loop-*` parent naming convention but create per-run children with
timestamp or external prefix plus PID and GUID. The temp isolation test runs two
plugin install smoke tests concurrently and verifies distinct install roots.
Root self-loop phase-012 made `start-phase.ps1 -Force` idempotent for
intentional same-phase restarts. It refreshes prompt, requirements, metadata,
`status.json.phases`, and start-time evidence/artifact/skill ledger rows
instead of appending duplicate phase or ledger entries. `Test-StartPhaseIdempotence.ps1`
proves status replacement, prompt refresh, ledger row counts, and loop-wide
validation after forced restart.
Root self-loop phase-013 enhanced `ai-loop resume`. It now reads
`.ai-loop/events/state-transitions.ndjson`, reports latest transition, recent
transitions, transition consistency, transition problems, missing evidence, next
safe action, and a copyable next safe command. Transition/status mismatch is
reported as `Recovery decision: BLOCKED`. `Test-ResumeDiagnostics.ps1` covers a
normal started-phase resume and a tampered mismatch.
Root self-loop phase-014 added `-RequireExternalWorkerEvidence` to phase start.
When a Supervisor declares external Worker use, `phase_requirements.json`
requires `external-worker-preflight.json/.md` and
`external-worker-invocation.json/.log`. `collect-evidence.ps1` records those
additional required evidence files in Markdown ledgers, `artifact-index.md`,
and `artifact-manifest.json`; `prepare-audit-pack.ps1` lists the Worker
evidence requirements and now preserves Markdown code fences in gate output.
`Test-ExternalWorkerEvidence.ps1` proves missing Worker evidence blocks and
complete local evidence passes without calling an external Worker service.
Root self-loop phase-015 added structured audit finding extraction. `decide`
now writes `.ai-loop/audits/<phase>-findings.json` for durable `REWORK` and
`BLOCKED` decisions, `scaffold-rework` uses that JSON to preserve bounded
finding IDs, required fixes, evidence, and file scope in follow-up prompts, and
`validate-loop` blocks terminal non-accepted phases when findings JSON is
missing or inconsistent.
Root self-loop phase-016 added `ai-loop resume -Json`. JSON resume output is a
single parseable object for normal, BLOCKED, and missing-status cases and
contains current phase, missing evidence, artifact manifest state, transition
diagnostics, next safe action, next safe command, blocked flag, and recovery
decision. Default text resume still expands memory/handoff files for humans.
Root self-loop phase-017 added `ai-loop -Command prune-temp` and
`prune-temp-fixtures.ps1`. The command is dry-run by default, requires `-Force`
for deletion, only prunes old `run-*` children under `.tmp-ai-loop-*` parents,
keeps the latest runs per parent, skips reparse-point directories, and is
covered by `Test-PruneTempFixtures.ps1` plus `Test-Phase017.ps1`.
Root self-loop phase-018 added `ai-loop -Command migrate -DryRun` and
`-DryRun -Json`. Supervisors and automation can now inspect planned
schema/template repair actions before modifying a project. Dry-run performs the
same future-schema compatibility block but writes no migration records, JSON,
template files, or event logs. `Test-MigrateDryRun.ps1` covers JSON/text plans,
no-write behavior, real migration after planning, and future-schema blocking.
Root self-loop phase-019 added `ai-loop -Command prune-temp -Json`. The command
now emits parseable cleanup summaries for dry-run and forced delete modes,
including candidates, deleted rows, skipped paths, retention settings, counts,
and timestamp. `Test-PruneTempJson.ps1` verifies JSON output remains pure and
that `-Force -Json` deletes only the old run while retaining the newest run.
Root self-loop phase-020 added `ai-loop -Command readiness`. The read-only
command emits text or JSON readiness reports for kit/project evidence, including
core scripts, templates, project `.ai-loop`, evidence/state support, plugin
scaffold, docs, test matrix files, and loop-wide validation. It reports real
global Codex plugin discovery as a warning unless the user explicitly approves
modifying global config. `Test-Readiness.ps1` covers root readiness, parseable
JSON, and blocked JSON when `.ai-loop` is missing.
Root self-loop phase-021 added 1.0 release notes and an operator checklist.
`loop-standard/docs/RELEASE_NOTES_1.0.md` records the current
`ready_with_warnings` release posture, verified matrix, non-goals, and the
remaining `PLUGIN-GLOBAL` warning. `loop-standard/docs/OPERATOR_CHECKLIST_1.0.md`
gives operators copyable commands and confirmation checks for initialization,
skill linking, phase start, external Worker evidence, collection, audit,
recovery, and readiness. `Test-ReleaseDocs.ps1` and `Test-Phase021.ps1` cover
the release-facing docs and aggregate the current non-global verification
matrix.
Root self-loop phase-022 added semantic migration transforms. The registry lives
at `.ai-loop/schema/migration-transforms.json` and is mirrored in
`loop-standard/.ai-loop/` plus `loop-standard/templates/.ai-loop/`.
`migrate-loop.ps1` now reports transform IDs in dry-run JSON, applies transforms
before top-level JSON merge, and records applied IDs in migration records.
`Test-MigrateSemanticTransforms.ps1` covers legacy evidence-field repair,
current-phase hydration, completed-to-accepted status mapping, dry-run no-write
behavior, real migration, and no-op behavior for current projects.
Root self-loop phase-023 added task-kind skill trigger fixtures.
`Test-TaskKindSkillTriggers.ps1` proves `fullstack` starts without scientific
skill requirements by default, while `physics-research`, `data-analysis`,
`research-writing`, the `physics-sim` profile, and manual full-stack skill
overrides produce the expected required skills and prompt content.
Root self-loop phase-024 added `release-check.ps1` and
`ai-loop -Command release-check`. The command is read-only and aggregates
`readiness`, `validate-loop`, and a bounded matrix script into text or JSON.
`Test-ReleaseCheck.ps1` covers JSON purity, skipped matrix diagnostics, focused
matrix execution, text output, and blocked JSON for a project missing
`.ai-loop`.

Root `AGENTS.md` is the only bootstrap file. Former `agent.md` content was
merged into `.ai-loop/` memory and the file was removed.

## Current Focus

Use the root `.ai-loop/` control plane before further changes. New required
files include `.ai-loop/evidence/*`, `.ai-loop/skills/*`,
`.ai-loop/skills/skill-source-map.md`, and
`.ai-loop/evolution/project-loop-evolution.md`.

Reusable control-plane templates under `loop-standard/templates/.ai-loop/` now
include evidence ledgers, skill ledgers, the skill source map, schema manifests,
the migration log, and the project-local evolution file.
`loop-standard/scripts/ai-loop.ps1` is the recommended user-facing command.
`install-global.ps1` can create
`<InstallRoot>/bin/ai-loop.ps1`, copy `loop-standard/`, and optionally copy
`plugins/codex-loop-harness/`. The plugin scaffold stores no project-local
`.ai-loop` state.

Evidence now uses a dual-track model: Markdown ledgers are the human-readable
surface, while `.ai-loop/evidence/artifact-manifest.json` is the gate-validated
integrity source for required phase evidence and declared required skill
artifacts.

## Must Preserve

- Worker must not own the global route.
- Evidence beats prose.
- Governance files are read-mostly unless in harness maintenance.
- Scientific correctness skills must not be skipped for correctness-sensitive
  work.
- Required skill artifacts block acceptance unless a Supervisor override reason
  is recorded.
- Required skill availability is checked through project `.agents/skills/` and
  `.ai-loop/skills/skill-source-map.md`.
- Root entrypoint is `AGENTS.md`; detailed rules live in `.ai-loop/`.
- `.agents/` is for agent runtime assets, not durable project memory.
- Uppercase compatibility scripts must remain thin wrappers and must not contain
  independent legacy state logic.
- Required phase evidence must have a matching artifact manifest row and current
  SHA256 hash before audit/accept can pass.
- Do not use this MVP repository's `.ai-loop/evolution/` for dogfood-specific
  project evolution content. Project evolution files belong to the target
  project using the harness.
- Classify reusable lessons before writing: durable governance goes to memory,
  project-local proposals go to evolution, reusable procedures go to skills.

## Next Safe Action

Repo-local plugin install/discovery smoke testing, validate-loop negative
fixtures, schema compatibility checks, explicit non-destructive migration,
append-only state transition logs, durable REWORK/BLOCKED outcomes, external
Worker evidence requirements, structured audit finding extraction,
machine-readable resume output, safe temp fixture pruning, migration dry-run
planning, machine-readable temp cleanup output, and a read-only 1.0 readiness
command are now in place.
The remaining
plugin-form stability step is a live global Codex plugin install/discovery
test, which must wait for explicit user approval because it modifies real
Codex/plugin configuration. Good non-global next candidates are richer recovery
explanations from the append-only transition log, or adding a user-approved
live global plugin discovery test when real Codex configuration changes are
allowed.

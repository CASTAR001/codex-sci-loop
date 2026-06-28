# Active Context

## Current Phase

Self-loop optimization of the loop harness MVP.

## Current Objective

Root-level `.ai-loop/` control plane now includes memory, constraints, evidence
ledgers, artifact integrity manifest, skill trigger records, phase gate checks,
project-local loop evolution notes, and skill source maps.
`loop-standard/scripts/ai-loop.ps1` is the recommended command entrypoint.

## Active Plan

The next build plan is:

```text
loop-standard/docs/CONTROL_PLANE_BUILD_PLAN.md
```

The near-term build order is now:

1. Memory + constraints.
2. Evidence ledger + skill dispatcher.
3. Phase gate automation.
4. Global entrypoint + Codex plugin distribution.
5. Recovery summary and state validation.
6. Broader validation CLI.

## Current Work Boundary

The memory/constraint layer, evidence/skills/gate layer, artifact manifest,
unified wrapper, skill linker, plugin scaffold, install shim, compatibility
wrappers, and recovery summary are now in place. Required phase evidence must be
present, non-empty, recorded in `.ai-loop/evidence/artifact-manifest.json`, and
hash-matched before validation passes.

The dogfood project initialized successfully, linked all 8 research workflow
skills via `.agents/skills/`, generated a phase-001 Worker prompt, collected
evidence, and accepted phase-001 after the user ran Kimi Code externally.

The harness now includes a Worker-agnostic external invocation layer:
`worker-preflight` records safety and feasibility evidence before any external
Worker call, and `invoke-worker` refuses to run unless preflight is safe or the
user has explicitly approved the external service invocation. `-Yolo` is
recorded but does not require a separate confirmation.

Self-loop phases now run against both `loop-standard/.ai-loop` and the root
`.ai-loop`. Phase-002 exposed `-TargetStatus` on the unified `ai-loop validate`
command. Phase-003 fixed changed-file classification so `.ai-loop/*` evidence
files are no longer listed as business files when the project root is a
subdirectory inside a larger git repository. Root phase-001 made the repository
root control plane directly runnable without overwriting existing memory. Root
phase-002 added a repository-local Codex plugin install/discovery smoke test
using a temporary install root and local marketplace file.
Root phase-003 added loop-wide state validation through `validate-loop.ps1` and
`ai-loop -Command validate-loop`, covering control-plane structure,
`status.json` consistency, phase references, accepted audits, accepted phase
gates, and recovery-critical files.
Root phase-004 added negative fixture tests for `validate-loop.ps1` through
`Test-ValidateLoopFailures.ps1`, proving the loop-wide validator rejects
duplicate phase IDs, broken `current_phase` references, illegal statuses,
missing accepted audits, stale artifact hashes, and missing recovery-critical
files. The same phase also fixed collect-time Markdown ledger refreshes and
verification stderr capture, then added `Test-CollectLedgerIdempotence.ps1` to
prove repeated collect refreshes do not duplicate evidence/command/test/
provenance ledger rows. `Test-Phase004.ps1` now runs the main self-check,
plugin install smoke test, negative fixtures, collect idempotence, and root
loop validation.
Root phase-005 added schema/migration versioning for `.ai-loop`: schema
manifests and migration logs now exist in the root control plane,
`loop-standard/templates/.ai-loop/`, and `loop-standard/.ai-loop/`.
`validate-loop.ps1` now blocks missing schema manifests, missing required schema
properties, unsupported old config schemas, future config schemas,
config/manifest mismatches, and status schema mismatches.
`Test-SchemaVersioning.ps1` covers these cases, and `Test-Phase005.ps1`
aggregates the current full non-global verification matrix.
Root phase-006 added durable non-accepted phase decisions. `ai-loop -Command
decide` now records `REWORK` and `BLOCKED` audit outcomes into `status.json`,
`phase_meta.json`, `rework.txt` or `blocked.txt`, and the event log.
`validate-loop.ps1` now requires matching audit decisions and decision files for
terminal `rework` and `blocked` states. `Test-PhaseDecisions.ps1` covers
REWORK, BLOCKED, resume reconstruction, loop validation, and decision/audit
mismatch rejection.
Root phase-007 added explicit non-destructive migration for existing `.ai-loop`
projects. `ai-loop -Command migrate` now fills missing template files, merges
missing top-level JSON properties, upgrades schema markers, writes migration
records and backups under `.ai-loop/schema/migration-records/`, appends
`migration-log.md`, records an event-log entry, and blocks future schemas unless
`-Force` is explicit. `Test-MigrateLoop.ps1` covers old-project repair,
project memory preservation, missing-template restoration, future-schema
blocking, and missing `.ai-loop` rejection. `Test-Phase007.ps1` is the current
non-global verification matrix.
Root phase-008 added append-only state transition logging. Canonical scripts now
append phase status changes to `.ai-loop/events/state-transitions.ndjson`, and
schema `1.3` makes that log part of the control plane. `validate-loop.ps1`
parses the transition log and, for phases declaring `transition_log`, verifies
that the latest transition status matches `status.json`. `Test-StateTransitions.ps1`
covers a normal lifecycle plus tampered latest-transition rejection.
Root phase-009 added bounded `REWORK` follow-up scaffolding. `ai-loop -Command
scaffold-rework` now turns a durable `REWORK` decision into a new bounded phase
using the source audit and `rework.txt` as fixed scope inputs, writes
`rework_source.json`, and refuses non-REWORK sources. `Test-ReworkScaffold.ps1`
covers REWORK scaffold creation and BLOCKED refusal.
Root phase-010 added required skill artifact hashing. `collect-evidence.ps1`
now records declared required skill artifacts as `skill-artifact` entries in
the artifact index and artifact manifest. Validation has fixture coverage for
recorded, tampered, and missing skill artifacts through
`Test-SkillArtifactManifest.ps1` and `Test-Phase010.ps1`.
Root phase-011 added per-run test temp isolation. Fixture and smoke tests now
use `test-temp-root.ps1` to create ignored `.tmp-ai-loop-*` parent directories
with unique `run-<prefix>-<pid>-<guid>` children, and `Test-TempIsolation.ps1`
proves concurrent plugin install smoke tests use distinct install roots.
Root phase-012 added start-time idempotence. `start-phase.ps1 -Force` for the
same phase now refreshes prompt, requirements, metadata, `status.json.phases`,
and start-time Markdown ledger rows instead of duplicating phase records or
ledger entries. `Test-StartPhaseIdempotence.ps1` covers status replacement,
prompt refresh, evidence/artifact/skill ledger row counts, and loop validation.
Root phase-013 enhanced recovery diagnostics. `ai-loop resume` now reads
`state-transitions.ndjson`, reports latest transition, recent transitions,
transition consistency, transition problems, missing evidence, next safe action,
and a copyable next safe command. Transition/status mismatch is reported as
`Recovery decision: BLOCKED` and covered by `Test-ResumeDiagnostics.ps1`.
Root phase-014 added explicit external Worker evidence requirements. Phases
started with `-RequireExternalWorkerEvidence -WorkerProfile <profile>` now add
Worker preflight and invocation records to `phase_requirements.json`,
`evidence_required`, audit input, Markdown ledgers, and
`artifact-manifest.json`. `Test-ExternalWorkerEvidence.ps1` proves missing
preflight/invocation evidence blocks validation and complete local evidence
validates without calling an external Worker service. `prepare-audit-pack.ps1`
also now emits valid Markdown code fences for phase gate output.
Root phase-015 added structured audit finding extraction. `decide-phase.ps1`
now generates `.ai-loop/audits/<phase>-findings.json` for durable `REWORK` and
`BLOCKED` decisions, `scaffold-rework-phase.ps1` uses structured findings for
bounded follow-up scope, and `validate-loop.ps1` requires findings JSON for
terminal non-accepted phases. `Test-AuditFindingExtraction.ps1` covers
extraction, durable decision state, structured rework scaffolding, and missing
findings validation.
Root phase-016 added machine-readable recovery output. `ai-loop resume -Json`
now emits a single JSON object for normal, BLOCKED, and missing-status recovery
states, while default `resume` remains human-readable and still expands the
memory/handoff files. `Test-ResumeJson.ps1` covers text compatibility, started
JSON, transition/status mismatch JSON, and missing status JSON.
Root phase-017 added safe temp fixture pruning. `ai-loop -Command prune-temp`
and `prune-temp-fixtures.ps1` now provide dry-run-first cleanup for ignored
`.tmp-ai-loop-*` fixture run directories. Deletion requires `-Force`, candidates
are limited to `run-*` children under `.tmp-ai-loop-*` parents, latest runs are
retained, reparse-point directories are skipped, and
`Test-PruneTempFixtures.ps1` covers dry-run, forced cleanup, namespace
protection, and idempotence.
Root phase-018 added migration dry-run planning. `ai-loop -Command migrate`
now supports `-DryRun` and `-DryRun -Json`, allowing Supervisors and automation
to inspect planned schema/template repairs before project files are modified.
Dry-run performs compatibility checks but does not write migration records,
modify JSON, copy template files, or append event logs. `Test-MigrateDryRun.ps1`
covers parseable JSON plans, human-readable plans, no-write behavior, real
migration after planning, and future schema blocking.
Root phase-019 added machine-readable temp cleanup output. `ai-loop -Command
prune-temp -Json` now emits parseable cleanup summaries for dry-run and forced
delete modes, including candidates, deleted rows, skipped paths, counts,
retention settings, cutoff, and generated timestamp. Existing text output is
preserved, and `Test-PruneTempJson.ps1` covers JSON purity and delete results.

Do not install external memory dependencies.
Do not delete or rewrite existing `loop-standard/` or `pilot-project/` evidence.
Keep reusable framework code under `loop-standard/` and pilot fixture work under
`pilot-project/`.

## Next Safe Action

The next best optimization is a 1.0 readiness audit/checklist command, or
deeper semantic migration steps for future schema versions that require more
than template repair and top-level JSON merging.
Real global Codex plugin installation validation still requires explicit user
approval. Before further harness changes, review:

- `.ai-loop/memory/handoff-summary.md`
- `.ai-loop/memory/constraint-ledger.md`
- `.ai-loop/gates/pre-action-check.md`
- `.ai-loop/evidence/evidence-ledger.md`
- `.ai-loop/evidence/artifact-manifest.json`
- `.ai-loop/skills/skill-trigger-matrix.md`
- `.ai-loop/skills/skill-source-map.md`

## Open Questions

- What final global install root should be used outside temporary tests?
- Should real Codex global plugin configuration be modified for a live install
  test, and what path should be used?
- Should `migrate` eventually support deep semantic transforms for future schema
  versions instead of only top-level JSON merge plus template repair?

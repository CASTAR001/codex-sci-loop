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

Do not install external memory dependencies.
Do not delete or rewrite existing `loop-standard/` or `pilot-project/` evidence.
Keep reusable framework code under `loop-standard/` and pilot fixture work under
`pilot-project/`.

## Next Safe Action

The next best optimization is stricter state transition logs, explicit migration
commands for old `.ai-loop` projects, or deciding whether start-time Markdown
ledger rows should become idempotent like collect-time evidence rows.
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
- Should required skill artifacts become mandatory manifest entries before
  broader skill trigger expansion?
- Should external Worker invocation records become required phase evidence in
  `phase_requirements.json` for phases that use an external Worker?
- Should Markdown evidence ledgers become fully idempotent for `start-phase.ps1`
  as well as `collect-evidence.ps1`?
- Should a future phase implement explicit in-place migration commands for old
  `.ai-loop` projects, or keep first 1.0 migration handling as detect-and-block?

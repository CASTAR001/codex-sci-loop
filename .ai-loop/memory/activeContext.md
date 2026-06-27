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

Do not install external memory dependencies.
Do not delete or rewrite existing `loop-standard/` or `pilot-project/` evidence.
Keep reusable framework code under `loop-standard/` and pilot fixture work under
`pilot-project/`.

## Next Safe Action

The next best optimization is schema/migration versioning or deeper
state/recovery transition tests inside the already runnable root `.ai-loop`.
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
- Should `validate-loop.ps1` grow fixture tests for duplicate phases, broken
  current phase references, missing accepted audits, and stale artifact
  manifests?

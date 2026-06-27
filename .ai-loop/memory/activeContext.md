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

Self-loop phases now run against `loop-standard/.ai-loop` and are accepted
through evidence gates. Phase-002 exposed `-TargetStatus` on the unified
`ai-loop validate` command. Phase-003 fixed changed-file classification so
`.ai-loop/*` evidence files are no longer listed as business files when the
project root is a subdirectory inside a larger git repository.

Do not install external memory dependencies.
Do not delete or rewrite existing `loop-standard/` or `pilot-project/` evidence.
Keep reusable framework code under `loop-standard/` and pilot fixture work under
`pilot-project/`.

## Next Safe Action

The next best optimization is either to make the root `.ai-loop/` directly
runnable without overwriting existing memory, or to validate plugin discovery
inside an actual Codex plugin install path. Before further harness changes,
review:

- `.ai-loop/memory/handoff-summary.md`
- `.ai-loop/memory/constraint-ledger.md`
- `.ai-loop/gates/pre-action-check.md`
- `.ai-loop/evidence/evidence-ledger.md`
- `.ai-loop/evidence/artifact-manifest.json`
- `.ai-loop/skills/skill-trigger-matrix.md`
- `.ai-loop/skills/skill-source-map.md`

## Open Questions

- What final global install root should be used outside temporary tests?
- Should required skill artifacts become mandatory manifest entries before
  broader skill trigger expansion?
- Should external Worker invocation records become required phase evidence in
  `phase_requirements.json` for phases that use an external Worker?
- Should root `.ai-loop/` be given a minimal `status.json`/`loop.config.json`
  without overwriting its memory, so the repository root itself can run phases?

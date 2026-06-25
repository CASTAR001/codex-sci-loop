# Active Context

## Current Phase

Artifact hashing and evidence ledger automation implemented on top of the
global-callable harness.

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

Do not install external memory dependencies.
Do not delete or rewrite existing `loop-standard/` or `pilot-project/` evidence.
Keep reusable framework code under `loop-standard/` and pilot fixture work under
`pilot-project/`.

## Next Safe Action

Proceed to deeper state-machine enforcement, skill artifact manifest coverage,
or global install promotion only after reviewing:

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

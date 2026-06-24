# Active Context

## Current Phase

Evidence ledger, skill trigger matrix, and phase gate automation implemented.

## Current Objective

Root-level `.ai-loop/` control plane now includes memory, constraints, evidence
ledgers, skill trigger records, phase gate checks, and project-local loop
evolution notes. The reusable templates under `loop-standard/templates/.ai-loop/`
mirror the new control plane.

## Active Plan

The next build plan is:

```text
loop-standard/docs/CONTROL_PLANE_BUILD_PLAN.md
```

The near-term build order is now:

1. Memory + constraints.
2. Evidence ledger + skill dispatcher.
3. Phase gate automation.
4. Recovery protocol + change control.
5. Global entrypoint + broader validation CLI.

## Current Work Boundary

The memory/constraint layer and the evidence/skills/gate layer are now in place.
The harness references the 8 scientific workflow skills by name and records
required artifacts per phase; it does not vendor-copy skills into each project.

Do not install external memory dependencies.
Do not delete or rewrite existing `loop-standard/` or `pilot-project/` evidence.
Keep reusable framework code under `loop-standard/` and pilot fixture work under
`pilot-project/`.

## Next Safe Action

Proceed to recovery enforcement or global entrypoint work only after reviewing:

- `.ai-loop/memory/handoff-summary.md`
- `.ai-loop/memory/constraint-ledger.md`
- `.ai-loop/gates/pre-action-check.md`
- `.ai-loop/evidence/evidence-ledger.md`
- `.ai-loop/skills/skill-trigger-matrix.md`

## Open Questions

- Should future global installation write an `ai-loop.ps1` wrapper into a PATH
  directory, or keep absolute script invocation?
- Should uppercase compatibility scripts be fully aligned with the newer
  lowercase scripts, or retained as legacy wrappers?

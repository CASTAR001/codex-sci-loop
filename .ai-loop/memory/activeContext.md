# Active Context

## Current Phase

Unified script entrypoint and Codex plugin distribution scaffold implemented on
top of the evidence, skill, and phase-gate layer.

## Current Objective

Root-level `.ai-loop/` control plane now includes memory, constraints, evidence
ledgers, skill trigger records, phase gate checks, project-local loop evolution
notes, and skill source maps. `loop-standard/scripts/ai-loop.ps1` is the
recommended command entrypoint, while `plugins/codex-loop-harness/` provides the
first Codex plugin distribution scaffold.

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
5. Recovery protocol + change control.
6. Broader validation CLI.

## Current Work Boundary

The memory/constraint layer, evidence/skills/gate layer, unified wrapper, skill
linker, and plugin scaffold are now in place. The harness references the 8
scientific workflow skills by name, links them into project `.agents/skills/`
via junctions when available, and records availability in
`.ai-loop/skills/skill-source-map.md`; it does not vendor-copy skills into each
project.

Do not install external memory dependencies.
Do not delete or rewrite existing `loop-standard/` or `pilot-project/` evidence.
Keep reusable framework code under `loop-standard/` and pilot fixture work under
`pilot-project/`.

## Next Safe Action

Proceed to recovery enforcement, global install polishing, or plugin install
packaging only after reviewing:

- `.ai-loop/memory/handoff-summary.md`
- `.ai-loop/memory/constraint-ledger.md`
- `.ai-loop/gates/pre-action-check.md`
- `.ai-loop/evidence/evidence-ledger.md`
- `.ai-loop/skills/skill-trigger-matrix.md`
- `.ai-loop/skills/skill-source-map.md`

## Open Questions

- Should future global installation write a stable `ai-loop.ps1` shim into a
  PATH directory, or rely on plugin wrapper discovery first?
- Should uppercase compatibility scripts be fully aligned with the newer
  lowercase scripts, or retained as legacy wrappers?

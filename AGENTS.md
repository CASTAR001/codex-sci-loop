# AGENTS.md

This repository uses a local `.ai-loop/` control plane. Keep this file short:
it is only the bootstrap entrypoint.

Before planning or modifying files, read:

1. `.ai-loop/README.md`
2. `.ai-loop/memory/activeContext.md`
3. `.ai-loop/memory/constraint-ledger.md`
4. `.ai-loop/gates/pre-action-check.md`

After meaningful work, update:

- `.ai-loop/memory/activeContext.md`
- `.ai-loop/memory/progress.md`
- `.ai-loop/memory/handoff-summary.md`

Governance files are read-only by default. Do not modify `.ai-loop/memory/`,
`.ai-loop/roles/`, `.ai-loop/gates/`, `.ai-loop/events/`, `.ai-loop/evidence/`,
`.ai-loop/skills/`, `.ai-loop/evolution/`, `.ai-loop/prompts/`, or
`.ai-loop/templates/` unless the user explicitly declares a harness maintenance
phase.

Do not accept work from prose alone. Inspect evidence, diffs, verification logs,
status, changed files, and relevant source.

For `.agents/` vs `.ai-loop/` boundaries, read
`loop-standard/docs/AGENTS_VS_AI_LOOP_BOUNDARY.md` when changing structure.

# .ai-loop Compatibility Template

This directory is retained as a compatibility copy from the first draft.
The canonical copyable template is now `loop-standard/templates/.ai-loop/`.

This directory is the source of truth for loop state. Do not rely on chat
history for phase status, evidence, decisions, or audit results.

## Contract

- Codex is Supervisor and owns the route.
- Kimi Code is Worker and executes only the current phase prompt.
- Kimi must not approve, expand, or redefine the overall route.
- Codex must audit evidence before phase acceptance.
- Missing evidence blocks phase progression.

## Evidence Contract

Each phase must have:

- `evidence/<phase-id>/prompt.md`
- `evidence/<phase-id>/report.md`
- `evidence/<phase-id>/diff.patch`
- `evidence/<phase-id>/verify.log`
- `audits/<phase-id>/audit.md`

If any required evidence is missing or only contains a `MISSING:` placeholder,
Codex must return `BLOCKED` or `REWORK`, not `ACCEPTED`.

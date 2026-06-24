# Recovery Contract

Recovery mode is used after interruption, compaction, tool switch, or new chat.

## Recovery Must

- Read handoff summary, active context, constraints, decisions, evidence, and
  phase gates before editing.
- State current phase, last verified evidence, open blockers, next safe action,
  and files to inspect.
- Avoid modifying files until the next safe action is clear.

## Recovery Must Not

- Continue from memory alone.
- Assume a previous chat summary is authoritative.
- Skip pre-action checks.

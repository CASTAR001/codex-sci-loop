---
name: loop-auditor
description: "Audit a Supervisor-Worker loop phase by inspecting Worker report, diff, verify log, ledgers, skill artifacts, status, and source."
---

# Loop Auditor

Use this skill when deciding whether a phase is `ACCEPTED`, `REWORK`, or
`BLOCKED`.

## Audit Inputs

Read the audit input and inspect:

- Worker report
- diff patch
- verify log
- changed files
- status files
- phase requirements
- evidence ledger
- skill usage ledger
- skill source map
- required skill artifacts
- relevant source files

## Decision Rules

- `ACCEPTED`: evidence complete, verification passed, scope followed, required
  skill artifacts present, and source inspection supports the result.
- `REWORK`: concrete fix is needed and evidence is sufficient to describe it.
- `BLOCKED`: evidence, access, state, verification, skill artifacts, or source
  inspection are missing.

Do not accept based on the Worker report alone.


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

## Recording The Decision

After writing `.ai-loop/audits/<phase-id>-audit.md`:

- For `ACCEPTED`, use `ai-loop accept`.
- For `REWORK` or `BLOCKED`, use `ai-loop decide -Decision REWORK` or
  `ai-loop decide -Decision BLOCKED` with a concise `-Reason`.

This keeps non-accepted outcomes in `status.json`, `phase_meta.json`,
`rework.txt` or `blocked.txt`, and the event log.

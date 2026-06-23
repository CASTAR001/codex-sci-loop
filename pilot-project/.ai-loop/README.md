# .ai-loop

This directory is the project-local source of truth for the Supervisor-Worker
loop. Do not rely on chat history for phase status, evidence, decisions, or
audit results.

## Roles

- Codex is Supervisor and owns phase planning, audit, and acceptance.
- Kimi Code is Worker and may execute only the current phase prompt.

## Standard Layout

```text
.ai-loop/
  loop.config.json
  status.json
  runs/
    <phase-id>/
      base_commit.txt
      status_before.txt
      phase_meta.json
      prompt.md
      report.md
      status_after.txt
      diff.patch
      verify.log
      changed_files.txt
  audits/
    <phase-id>-audit-input.md
    <phase-id>-audit.md
```

Codex must not accept a phase unless required evidence exists and the audit
checks the report, diff, verify log, status files, and relevant source files.

---
name: loop-recovery
description: "Resume a local .ai-loop harness after compaction, interruption, or agent handoff without relying on chat history."
---

# Loop Recovery

Use this skill when recovering a project loop from files.

## Recovery Order

Use the installed shim `<install-root>\bin\ai-loop.ps1` when available. If the
plugin wrapper is used directly, set `LOOP_STANDARD_ROOT` to the installed
`loop-standard` directory when automatic discovery fails.

Run or emulate:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File <ai-loop-entrypoint> -Command resume -ProjectRoot <project-root>
```

Then identify:

- current phase
- last verified evidence
- current blockers
- required skills and artifact status
- next safe action
- files to inspect before edits

If current state cannot be reconstructed from files, mark the loop `BLOCKED`.

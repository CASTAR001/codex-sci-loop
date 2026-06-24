---
name: loop-recovery
description: "Resume a local .ai-loop harness after compaction, interruption, or agent handoff without relying on chat history."
---

# Loop Recovery

Use this skill when recovering a project loop from files.

## Recovery Order

Run or emulate:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 resume <project-root>
```

Then identify:

- current phase
- last verified evidence
- current blockers
- required skills and artifact status
- next safe action
- files to inspect before edits

If current state cannot be reconstructed from files, mark the loop `BLOCKED`.


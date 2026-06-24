---
name: loop-supervisor
description: "Start and manage a local Supervisor-Worker loop phase using .ai-loop evidence, state, constraints, and skill gates."
---

# Loop Supervisor

Use this skill when a project should be run through the reusable
Supervisor-Worker loop harness.

## Required Reading

Before planning or editing, read:

- `AGENTS.md`
- `.ai-loop/README.md`
- `.ai-loop/memory/activeContext.md`
- `.ai-loop/memory/constraint-ledger.md`
- `.ai-loop/gates/pre-action-check.md`

## Workflow

1. If `.ai-loop/status.json` is missing, run:

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 init <project-root>
   ```

2. For research projects, link skills before starting:

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 link-skills <project-root> -SkillProfile full-research
   ```

3. Start one bounded phase:

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 start <project-root> <phase-id> -TaskKind fullstack
   ```

4. Do not let the Worker define the overall route or approve the phase.

## Stop Rules

Stop and report `BLOCKED` or `REWORK` if evidence, diff, verify log, source
inspection, required skill artifacts, or phase state are missing.


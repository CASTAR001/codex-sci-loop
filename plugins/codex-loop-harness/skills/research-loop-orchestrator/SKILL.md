---
name: research-loop-orchestrator
description: "Choose and enforce research skill profiles for physics, simulation, data-analysis, manuscript, and full research loop phases."
---

# Research Loop Orchestrator

Use this skill for physics research, numerical simulation, data analysis,
manuscript work, result provenance, or other correctness-sensitive research
tasks.

## Skill Profiles

- `research-core`: `research-task-tree`, `invariant-contract`,
  `deterministic-verification`, `skill-compliance-audit`
- `physics-sim`: `research-task-tree`, `invariant-contract`,
  `bounded-experiment-loop`, `deterministic-verification`,
  `independent-crosscheck`, `result-provenance-audit`,
  `skill-compliance-audit`
- `manuscript`: `research-task-tree`, `deterministic-verification`,
  `result-provenance-audit`, `manuscript-consistency-audit`,
  `skill-compliance-audit`
- `full-research`: all eight research workflow skills

## Required Action

Before a research phase starts, ensure the selected profile is linked:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 link-skills <project-root> -SkillProfile physics-sim
```

Then start the phase with the matching `-TaskKind` and `-SkillProfile`.

If a required scientific claim lacks its skill artifact, the phase must be
`BLOCKED` or `REWORK`, not `ACCEPTED`.


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

5. Before invoking an external Worker service, run preflight:

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 worker-preflight <project-root> <phase-id> -WorkerProfile kimi-code -Yolo
   ```

   If the decision is `NEEDS_USER_APPROVAL`, stop and ask before passing project
   prompt content to the external service. `-Yolo` may be used without a
   separate confirmation, but external service use and sensitive prompt content
   still require explicit approval.

6. After approval, invoke through the generic Worker path, not a Kimi-specific
   ad hoc command:

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 invoke-worker <project-root> <phase-id> -WorkerProfile kimi-code -AllowExternalService -Yolo
   ```

   Treat Kimi Code as a thin Worker profile. Do not make the harness route
   depend on Kimi specifically.

## Knowledge Placement

Before preserving lessons learned from a loop, classify them:

- Long-term memory: durable harness governance, architectural decisions, and
  operator preferences.
- Project evolution: target-project-local improvement proposals. Do not pollute
  this MVP harness repository with dogfood-specific project evolution notes.
- Skills: reusable procedures, tool practices, and distilled patterns that
  future agents should invoke on demand.

When project evolution produces a repeated stable pattern, distill it into a
skill and replace the evolution note with skill trigger guidance.

## Stop Rules

Stop and report `BLOCKED` or `REWORK` if evidence, diff, verify log, source
inspection, required skill artifacts, or phase state are missing.

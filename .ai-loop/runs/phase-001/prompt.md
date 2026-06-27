# Worker Prompt: phase-001

## Boundary

- Execute only this phase.
- Do not decide the total route.
- Do not approve or accept this phase.
- Write a report to .ai-loop/runs/phase-001/report.md.

## Phase

- Phase ID: phase-001
- Title: Make root control plane runnable
- Objective: Make the repository root .ai-loop usable with ai-loop start, collect, validate, audit-pack, and accept without overwriting existing memory.
- Task kind: fullstack
- Skill profile: none

## Scope

- No additional scope supplied.

## Claim IDs

- CLAIM-phase-001

## Verification Command

`powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-LoopStandard.ps1 -AllowPilotProject
`

## Evidence Requirements

- Write a report to .ai-loop/runs/phase-001/report.md.
- Run or preserve the verification command output in .ai-loop/runs/phase-001/verify.log.
- Do not claim completion unless durable evidence exists.

## Required Skill Triggers

- None required by task kind. If you introduce correctness-sensitive, scientific, numerical, provenance, or manuscript claims, report the trigger and required skill artifacts.

Codex will audit the report, diff, verify log, status files, and relevant source
files before deciding ACCEPTED, REWORK, or BLOCKED.

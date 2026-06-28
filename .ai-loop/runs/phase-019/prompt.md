# Worker Prompt: phase-019

## Boundary

- Execute only this phase.
- Do not decide the total route.
- Do not approve or accept this phase.
- Write a report to .ai-loop/runs/phase-019/report.md.

## Phase

- Phase ID: phase-019
- Title: Add prune-temp JSON output
- Objective: Add ai-loop prune-temp -Json so maintenance cleanup candidates and delete results can be consumed by scripts, hooks, CI, and plugins while preserving existing text output.
- Task kind: fullstack
- Skill profile: none

## Scope

- No additional scope supplied.

## Claim IDs

- CLAIM-phase-019

## Verification Command

`powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-Phase019.ps1
`

## Evidence Requirements

- Write a report to .ai-loop/runs/phase-019/report.md.
- Run or preserve the verification command output in .ai-loop/runs/phase-019/verify.log.
- Do not claim completion unless durable evidence exists.

## Required Skill Triggers

- None required by task kind. If you introduce correctness-sensitive, scientific, numerical, provenance, or manuscript claims, report the trigger and required skill artifacts.

## Required External Worker Evidence

- None required. If you invoke an external Worker, stop and ask the Supervisor to start or update the phase with external Worker evidence requirements.

Codex will audit the report, diff, verify log, status files, and relevant source
files before deciding ACCEPTED, REWORK, or BLOCKED.

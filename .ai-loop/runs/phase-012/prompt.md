# Worker Prompt: phase-012

## Boundary

- Execute only this phase.
- Do not decide the total route.
- Do not approve or accept this phase.
- Write a report to .ai-loop/runs/phase-012/report.md.

## Phase

- Phase ID: phase-012
- Title: Make phase start idempotent
- Objective: Make start-phase -Force refresh existing phase metadata and start-time Markdown ledger rows without duplicating status phases or ledger entries.
- Task kind: fullstack
- Skill profile: none

## Scope

- No additional scope supplied.

## Claim IDs

- CLAIM-phase-012

## Verification Command

`powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-Phase012.ps1
`

## Evidence Requirements

- Write a report to .ai-loop/runs/phase-012/report.md.
- Run or preserve the verification command output in .ai-loop/runs/phase-012/verify.log.
- Do not claim completion unless durable evidence exists.

## Required Skill Triggers

- None required by task kind. If you introduce correctness-sensitive, scientific, numerical, provenance, or manuscript claims, report the trigger and required skill artifacts.

Codex will audit the report, diff, verify log, status files, and relevant source
files before deciding ACCEPTED, REWORK, or BLOCKED.

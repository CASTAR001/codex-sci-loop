# Worker Prompt: phase-004

## Boundary

- Execute only this phase.
- Do not decide the total route.
- Do not approve or accept this phase.
- Write a report to .ai-loop/runs/phase-004/report.md.

## Phase

- Phase ID: phase-004
- Title: Validate loop failure fixtures
- Objective: Add negative fixture coverage proving validate-loop rejects broken control-plane states.
- Task kind: fullstack
- Skill profile: none

## Scope

- No additional scope supplied.

## Claim IDs

- CLAIM-phase-004

## Verification Command

`powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-Phase004.ps1
`

## Evidence Requirements

- Write a report to .ai-loop/runs/phase-004/report.md.
- Run or preserve the verification command output in .ai-loop/runs/phase-004/verify.log.
- Do not claim completion unless durable evidence exists.

## Required Skill Triggers

- None required by task kind. If you introduce correctness-sensitive, scientific, numerical, provenance, or manuscript claims, report the trigger and required skill artifacts.

Codex will audit the report, diff, verify log, status files, and relevant source
files before deciding ACCEPTED, REWORK, or BLOCKED.

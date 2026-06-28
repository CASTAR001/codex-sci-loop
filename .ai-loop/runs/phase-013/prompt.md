# Worker Prompt: phase-013

## Boundary

- Execute only this phase.
- Do not decide the total route.
- Do not approve or accept this phase.
- Write a report to .ai-loop/runs/phase-013/report.md.

## Phase

- Phase ID: phase-013
- Title: Enhance resume diagnostics
- Objective: Use the state transition log in ai-loop resume to report latest transition, transition consistency, status-specific safe command, and stale-state diagnostics with fixture coverage.
- Task kind: fullstack
- Skill profile: none

## Scope

- No additional scope supplied.

## Claim IDs

- CLAIM-phase-013

## Verification Command

`powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-Phase013.ps1
`

## Evidence Requirements

- Write a report to .ai-loop/runs/phase-013/report.md.
- Run or preserve the verification command output in .ai-loop/runs/phase-013/verify.log.
- Do not claim completion unless durable evidence exists.

## Required Skill Triggers

- None required by task kind. If you introduce correctness-sensitive, scientific, numerical, provenance, or manuscript claims, report the trigger and required skill artifacts.

Codex will audit the report, diff, verify log, status files, and relevant source
files before deciding ACCEPTED, REWORK, or BLOCKED.

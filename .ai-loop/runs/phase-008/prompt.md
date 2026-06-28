# Worker Prompt: phase-008

## Boundary

- Execute only this phase.
- Do not decide the total route.
- Do not approve or accept this phase.
- Write a report to .ai-loop/runs/phase-008/report.md.

## Phase

- Phase ID: phase-008
- Title: Add append-only state transition log
- Objective: Record phase state transitions in a durable append-only log whenever canonical scripts change phase status, and validate transition-log consistency in recovery tests.
- Task kind: fullstack
- Skill profile: none

## Scope

- No additional scope supplied.

## Claim IDs

- CLAIM-phase-008

## Verification Command

`powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-Phase008.ps1
`

## Evidence Requirements

- Write a report to .ai-loop/runs/phase-008/report.md.
- Run or preserve the verification command output in .ai-loop/runs/phase-008/verify.log.
- Do not claim completion unless durable evidence exists.

## Required Skill Triggers

- None required by task kind. If you introduce correctness-sensitive, scientific, numerical, provenance, or manuscript claims, report the trigger and required skill artifacts.

Codex will audit the report, diff, verify log, status files, and relevant source
files before deciding ACCEPTED, REWORK, or BLOCKED.

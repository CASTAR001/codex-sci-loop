# Worker Prompt: phase-007

## Boundary

- Execute only this phase.
- Do not decide the total route.
- Do not approve or accept this phase.
- Write a report to .ai-loop/runs/phase-007/report.md.

## Phase

- Phase ID: phase-007
- Title: Add non-destructive loop migration
- Objective: Add a migrate command that upgrades existing .ai-loop projects to the current schema without overwriting project memory or evidence, with fixture tests proving before/after validation.
- Task kind: fullstack
- Skill profile: none

## Scope

- No additional scope supplied.

## Claim IDs

- CLAIM-phase-007

## Verification Command

`powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-Phase007.ps1
`

## Evidence Requirements

- Write a report to .ai-loop/runs/phase-007/report.md.
- Run or preserve the verification command output in .ai-loop/runs/phase-007/verify.log.
- Do not claim completion unless durable evidence exists.

## Required Skill Triggers

- None required by task kind. If you introduce correctness-sensitive, scientific, numerical, provenance, or manuscript claims, report the trigger and required skill artifacts.

Codex will audit the report, diff, verify log, status files, and relevant source
files before deciding ACCEPTED, REWORK, or BLOCKED.

# Worker Prompt: phase-024

## Boundary

- Execute only this phase.
- Do not decide the total route.
- Do not approve or accept this phase.
- Write a report to .ai-loop/runs/phase-024/report.md.

## Phase

- Phase ID: phase-024
- Title: Add release check command
- Objective: Add a compact read-only release-check command that aggregates readiness, loop validation, and the current non-global verification matrix for 1.0 delivery checks.
- Task kind: fullstack
- Skill profile: none

## Scope

- No additional scope supplied.

## Claim IDs

- CLAIM-phase-024

## Verification Command

`powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-Phase024.ps1
`

## Evidence Requirements

- Write a report to .ai-loop/runs/phase-024/report.md.
- Run or preserve the verification command output in .ai-loop/runs/phase-024/verify.log.
- Do not claim completion unless durable evidence exists.

## Required Skill Triggers

- None required by task kind. If you introduce correctness-sensitive, scientific, numerical, provenance, or manuscript claims, report the trigger and required skill artifacts.

## Required External Worker Evidence

- None required. If you invoke an external Worker, stop and ask the Supervisor to start or update the phase with external Worker evidence requirements.

Codex will audit the report, diff, verify log, status files, and relevant source
files before deciding ACCEPTED, REWORK, or BLOCKED.

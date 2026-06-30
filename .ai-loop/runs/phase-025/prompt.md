# Worker Prompt: phase-025

## Boundary

- Execute only this phase.
- Do not decide the total route.
- Do not approve or accept this phase.
- Write a report to .ai-loop/runs/phase-025/report.md.

## Phase

- Phase ID: phase-025
- Title: Richer recovery explanations
- Objective: Enhance ai-loop resume so text and JSON outputs explain why a phase is resumable or blocked, list concrete transition/status/evidence causes, and expose compact recovery_reason and recovery_causes fields for automation.
- Task kind: fullstack
- Skill profile: none

## Scope

- No additional scope supplied.

## Claim IDs

- CLAIM-phase-025

## Verification Command

`powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-Phase025.ps1
`

## Evidence Requirements

- Write a report to .ai-loop/runs/phase-025/report.md.
- Run or preserve the verification command output in .ai-loop/runs/phase-025/verify.log.
- Do not claim completion unless durable evidence exists.

## Required Skill Triggers

- None required by task kind. If you introduce correctness-sensitive, scientific, numerical, provenance, or manuscript claims, report the trigger and required skill artifacts.

## Required External Worker Evidence

- None required. If you invoke an external Worker, stop and ask the Supervisor to start or update the phase with external Worker evidence requirements.

Codex will audit the report, diff, verify log, status files, and relevant source
files before deciding ACCEPTED, REWORK, or BLOCKED.

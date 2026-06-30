# Worker Prompt: phase-026

## Boundary

- Execute only this phase.
- Do not decide the total route.
- Do not approve or accept this phase.
- Write a report to .ai-loop/runs/phase-026/report.md.

## Phase

- Phase ID: phase-026
- Title: Discover latest release matrix
- Objective: Make release-check and readiness discover the latest Test-PhaseNNN.ps1 non-global matrix by default so final 1.0 sign-off cannot silently run a stale phase matrix after new accepted phases.
- Task kind: fullstack
- Skill profile: none

## Scope

- No additional scope supplied.

## Claim IDs

- CLAIM-phase-026

## Verification Command

`powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-Phase026.ps1
`

## Evidence Requirements

- Write a report to .ai-loop/runs/phase-026/report.md.
- Run or preserve the verification command output in .ai-loop/runs/phase-026/verify.log.
- Do not claim completion unless durable evidence exists.

## Required Skill Triggers

- None required by task kind. If you introduce correctness-sensitive, scientific, numerical, provenance, or manuscript claims, report the trigger and required skill artifacts.

## Required External Worker Evidence

- None required. If you invoke an external Worker, stop and ask the Supervisor to start or update the phase with external Worker evidence requirements.

Codex will audit the report, diff, verify log, status files, and relevant source
files before deciding ACCEPTED, REWORK, or BLOCKED.

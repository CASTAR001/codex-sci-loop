# Worker Prompt: phase-028

## Boundary

- Execute only this phase.
- Do not decide the total route.
- Do not approve or accept this phase.
- Write a report to .ai-loop/runs/phase-028/report.md.

## Phase

- Phase ID: phase-028
- Title: Validate approved global plugin discovery
- Objective: Perform and record a user-approved live global Codex plugin install/discovery validation for codex-loop-harness, make PLUGIN-GLOBAL pass only when recorded evidence exists, preserve rollback/safety evidence, and keep the latest phase matrix chained to the full verification suite.
- Task kind: fullstack
- Skill profile: none

## Scope

- No additional scope supplied.

## Claim IDs

- CLAIM-phase-028

## Verification Command

`powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-Phase028.ps1
`

## Evidence Requirements

- Write a report to .ai-loop/runs/phase-028/report.md.
- Run or preserve the verification command output in .ai-loop/runs/phase-028/verify.log.
- Do not claim completion unless durable evidence exists.

## Required Skill Triggers

- None required by task kind. If you introduce correctness-sensitive, scientific, numerical, provenance, or manuscript claims, report the trigger and required skill artifacts.

## Required External Worker Evidence

- None required. If you invoke an external Worker, stop and ask the Supervisor to start or update the phase with external Worker evidence requirements.

Codex will audit the report, diff, verify log, status files, and relevant source
files before deciding ACCEPTED, REWORK, or BLOCKED.

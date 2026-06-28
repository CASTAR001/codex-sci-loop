# Worker Prompt: phase-022

## Boundary

- Execute only this phase.
- Do not decide the total route.
- Do not approve or accept this phase.
- Write a report to .ai-loop/runs/phase-022/report.md.

## Phase

- Phase ID: phase-022
- Title: Add semantic migration transform registry
- Objective: Add a declarative semantic migration transform registry and test coverage so ai-loop migrate can repair known legacy fields and status values beyond template copying and top-level JSON merging.
- Task kind: fullstack
- Skill profile: none

## Scope

- No additional scope supplied.

## Claim IDs

- CLAIM-phase-022

## Verification Command

`powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-Phase022.ps1
`

## Evidence Requirements

- Write a report to .ai-loop/runs/phase-022/report.md.
- Run or preserve the verification command output in .ai-loop/runs/phase-022/verify.log.
- Do not claim completion unless durable evidence exists.

## Required Skill Triggers

- None required by task kind. If you introduce correctness-sensitive, scientific, numerical, provenance, or manuscript claims, report the trigger and required skill artifacts.

## Required External Worker Evidence

- None required. If you invoke an external Worker, stop and ask the Supervisor to start or update the phase with external Worker evidence requirements.

Codex will audit the report, diff, verify log, status files, and relevant source
files before deciding ACCEPTED, REWORK, or BLOCKED.

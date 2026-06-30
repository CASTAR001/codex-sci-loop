# Worker Prompt: phase-027

## Boundary

- Execute only this phase.
- Do not decide the total route.
- Do not approve or accept this phase.
- Write a report to .ai-loop/runs/phase-027/report.md.

## Phase

- Phase ID: phase-027
- Title: Add 1.0 delivery evidence audit
- Objective: Add a release-facing delivery audit that maps Codex Loop Harness 1.0 objective requirements to current files, tests, phase evidence, and approval-gated warnings, and update release docs so the verified matrix references the current dynamic release-check flow.
- Task kind: fullstack
- Skill profile: none

## Scope

- No additional scope supplied.

## Claim IDs

- CLAIM-phase-027

## Verification Command

`powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-Phase027.ps1
`

## Evidence Requirements

- Write a report to .ai-loop/runs/phase-027/report.md.
- Run or preserve the verification command output in .ai-loop/runs/phase-027/verify.log.
- Do not claim completion unless durable evidence exists.

## Required Skill Triggers

- None required by task kind. If you introduce correctness-sensitive, scientific, numerical, provenance, or manuscript claims, report the trigger and required skill artifacts.

## Required External Worker Evidence

- None required. If you invoke an external Worker, stop and ask the Supervisor to start or update the phase with external Worker evidence requirements.

Codex will audit the report, diff, verify log, status files, and relevant source
files before deciding ACCEPTED, REWORK, or BLOCKED.

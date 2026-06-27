# Worker Prompt: phase-003

## Boundary

- Execute only this phase.
- Do not decide the total route.
- Do not approve or accept this phase.
- Write a report to .ai-loop/runs/phase-003/report.md.

## Phase

- Phase ID: phase-003
- Title: Normalize changed file classification
- Objective: Make collect-evidence classify changed files relative to ProjectRoot so .ai-loop evidence files are not reported as business files when ProjectRoot is a subdirectory inside a larger git repository.
- Task kind: fullstack
- Skill profile: none

## Scope

- No additional scope supplied.

## Claim IDs

- CLAIM-phase-003

## Verification Command

`powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-LoopStandard.ps1 -AllowPilotProject
`

## Evidence Requirements

- Write a report to .ai-loop/runs/phase-003/report.md.
- Run or preserve the verification command output in .ai-loop/runs/phase-003/verify.log.
- Do not claim completion unless durable evidence exists.

## Required Skill Triggers

- None required by task kind. If you introduce correctness-sensitive, scientific, numerical, provenance, or manuscript claims, report the trigger and required skill artifacts.

Codex will audit the report, diff, verify log, status files, and relevant source
files before deciding ACCEPTED, REWORK, or BLOCKED.

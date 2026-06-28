# Worker Prompt: phase-010

## Boundary

- Execute only this phase.
- Do not decide the total route.
- Do not approve or accept this phase.
- Write a report to .ai-loop/runs/phase-010/report.md.

## Phase

- Phase ID: phase-010
- Title: Hash required skill artifacts
- Objective: Record required skill artifacts into the artifact manifest during evidence collection and validate their hashes when present, with fixture coverage for missing and stale skill artifacts.
- Task kind: fullstack
- Skill profile: none

## Scope

- No additional scope supplied.

## Claim IDs

- CLAIM-phase-010

## Verification Command

`powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-Phase010.ps1
`

## Evidence Requirements

- Write a report to .ai-loop/runs/phase-010/report.md.
- Run or preserve the verification command output in .ai-loop/runs/phase-010/verify.log.
- Do not claim completion unless durable evidence exists.

## Required Skill Triggers

- None required by task kind. If you introduce correctness-sensitive, scientific, numerical, provenance, or manuscript claims, report the trigger and required skill artifacts.

Codex will audit the report, diff, verify log, status files, and relevant source
files before deciding ACCEPTED, REWORK, or BLOCKED.

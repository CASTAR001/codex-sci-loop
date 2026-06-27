# Worker Prompt: phase-002

## Boundary

- Execute only this phase.
- Do not decide the total route.
- Do not approve or accept this phase.
- Write a report to .ai-loop/runs/phase-002/report.md.

## Phase

- Phase ID: phase-002
- Title: Smoke test Codex plugin install layout
- Objective: Validate codex-loop-harness plugin packaging, temporary installation layout, manifest discovery, plugin skills, and installed shim without modifying real global Codex configuration.
- Task kind: fullstack
- Skill profile: none

## Scope

- No additional scope supplied.

## Claim IDs

- CLAIM-phase-002

## Verification Command

`powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-LoopStandard.ps1 -AllowPilotProject
`

## Evidence Requirements

- Write a report to .ai-loop/runs/phase-002/report.md.
- Run or preserve the verification command output in .ai-loop/runs/phase-002/verify.log.
- Do not claim completion unless durable evidence exists.

## Required Skill Triggers

- None required by task kind. If you introduce correctness-sensitive, scientific, numerical, provenance, or manuscript claims, report the trigger and required skill artifacts.

Codex will audit the report, diff, verify log, status files, and relevant source
files before deciding ACCEPTED, REWORK, or BLOCKED.

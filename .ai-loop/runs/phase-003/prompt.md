# Worker Prompt: phase-003

## Boundary

- Execute only this phase.
- Do not decide the total route.
- Do not approve or accept this phase.
- Write a report to .ai-loop/runs/phase-003/report.md.

## Phase

- Phase ID: phase-003
- Title: Add loop-wide state validation
- Objective: Add a loop-wide validation command that checks .ai-loop control-plane structure, status consistency, phase references, accepted audits, and recovery-critical files before broader 1.0 hardening.
- Task kind: fullstack
- Skill profile: none

## Scope

- No additional scope supplied.

## Claim IDs

- CLAIM-phase-003

## Verification Command

`powershell
& '.\loop-standard\scripts\Test-LoopStandard.ps1' -AllowPilotProject; if (-not $?) { exit 1 }; & '.\loop-standard\scripts\Test-PluginInstall.ps1'; if (-not $?) { exit 1 }; & '.\loop-standard\scripts\validate-loop.ps1' -ProjectRoot .; if (-not $?) { exit 1 }; exit 0
`

## Evidence Requirements

- Write a report to .ai-loop/runs/phase-003/report.md.
- Run or preserve the verification command output in .ai-loop/runs/phase-003/verify.log.
- Do not claim completion unless durable evidence exists.

## Required Skill Triggers

- None required by task kind. If you introduce correctness-sensitive, scientific, numerical, provenance, or manuscript claims, report the trigger and required skill artifacts.

Codex will audit the report, diff, verify log, status files, and relevant source
files before deciding ACCEPTED, REWORK, or BLOCKED.

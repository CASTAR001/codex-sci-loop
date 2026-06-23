# Kimi Worker Prompt: phase-001

## Boundary

- Execute only this phase.
- Do not decide the total route.
- Do not approve or accept this phase.
- Write a report to .ai-loop/runs/phase-001/report.md.

## Phase

- Phase ID: phase-001
- Title: Mark pilot phase complete
- Objective: Change only src/greeting.txt so phase=baseline becomes phase=worker-complete, then verify with PowerShell.

## Scope

- src/greeting.txt

## Verification Command

`powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\verify.ps1 -ExpectedPhase worker-complete
`

Codex will audit the report, diff, verify log, status files, and relevant source
files before deciding ACCEPTED, REWORK, or BLOCKED.

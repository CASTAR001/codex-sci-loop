# Phase B Plan

Phase B starts the pilot project and runs the smallest end-to-end
Supervisor-Worker loop. Do not start this phase during Phase A.

## Objective

Create `E:\codexfiles\loop\pilot-project`, initialize `.ai-loop`, generate one
Kimi Worker phase prompt, simulate or run the Worker phase, collect evidence,
prepare an audit package, and have Codex decide exactly one of:

- `ACCEPTED`
- `REWORK`
- `BLOCKED`

## Pilot Project Shape

Use a tiny local project with one source file and one verification command. A
minimal example is:

- `pilot-project/src/hello.txt` or `pilot-project/src/hello.ps1`
- `pilot-project/README.md`
- git repository initialized inside `pilot-project/`

The pilot must remain inside `E:\codexfiles\loop`.

## Required Phase Evidence

For phase `phase-001`, the pilot must produce:

- `pilot-project/.ai-loop/evidence/phase-001/prompt.md`
- `pilot-project/.ai-loop/evidence/phase-001/report.md`
- `pilot-project/.ai-loop/evidence/phase-001/diff.patch`
- `pilot-project/.ai-loop/evidence/phase-001/verify.log`
- `pilot-project/.ai-loop/evidence/phase-001/status.txt`
- `pilot-project/.ai-loop/audits/phase-001/audit-input.md`
- `pilot-project/.ai-loop/audits/phase-001/audit.md`

## Commands To Start

```powershell
New-Item -ItemType Directory -Force -Path E:\codexfiles\loop\pilot-project
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\init-loop.ps1 -ProjectRoot E:\codexfiles\loop\pilot-project
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\start-phase.ps1 -ProjectRoot E:\codexfiles\loop\pilot-project -PhaseId phase-001 -Title "Minimal pilot change" -Objective "Make one tiny verified change inside the pilot project."
```

## Worker Boundary For Pilot

Kimi may only execute `.ai-loop/evidence/phase-001/prompt.md`. Kimi must write
the report to `.ai-loop/evidence/phase-001/report.md` and must not approve the
phase or decide the route.

## Codex Audit Requirement

Codex must inspect:

- `.ai-loop/status.json`
- `.ai-loop/evidence/phase-001/prompt.md`
- `.ai-loop/evidence/phase-001/report.md`
- `.ai-loop/evidence/phase-001/diff.patch`
- `.ai-loop/evidence/phase-001/verify.log`
- `.ai-loop/evidence/phase-001/status.txt`
- changed source files in `pilot-project/`

Codex must return `BLOCKED` or `REWORK` if any required evidence is missing or
contains a `MISSING:` placeholder.

# Tech Context

## Platform

- Workspace: `E:\codexfiles\loop`
- Primary shell: Windows PowerShell.
- Repository style: local git repository with root-tracked pilot fixture.

## Implementation Constraints

- Markdown-first.
- NDJSON for event log.
- No cloud service.
- No database.
- No heavy memory dependencies.
- Files must be human-readable and git-trackable.

## Existing Harness Components

- `loop-standard/scripts/init-loop.ps1`
- `loop-standard/scripts/start-phase.ps1`
- `loop-standard/scripts/collect-evidence.ps1`
- `loop-standard/scripts/prepare-audit-pack.ps1`
- `loop-standard/scripts/accept-phase.ps1`
- `loop-standard/scripts/test-pilot-loop.ps1`

## Verification Commands

Current standard package self-check:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-LoopStandard.ps1 -AllowPilotProject
```

Pilot verification:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\verify.ps1 -ExpectedPhase worker-complete
```

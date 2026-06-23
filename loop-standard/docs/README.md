# Loop Standard Docs

The canonical Phase A structure is:

```text
loop-standard/
  templates/
  prompts/
  scripts/
  docs/
```

Use the lowercase PowerShell scripts in `scripts/` as the standard interface.
The earlier PascalCase scripts are retained as compatibility helpers.

## Standard Script Flow

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\init-loop.ps1 -ProjectRoot "E:\some-project"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\start-phase.ps1 -ProjectRoot "E:\some-project" -PhaseId "phase-001"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\collect-evidence.ps1 -ProjectRoot "E:\some-project" -PhaseId "phase-001" -VerifyCommand "<verification command>"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\prepare-audit-pack.ps1 -ProjectRoot "E:\some-project" -PhaseId "phase-001"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\accept-phase.ps1 -ProjectRoot "E:\some-project" -PhaseId "phase-001"
```

## Evidence Gate

Codex must return `BLOCKED` or `REWORK` instead of accepting when required
evidence is missing, contains `MISSING:`, or cannot be inspected.

## Self-Check After Pilot Creation

After `pilot-project/` exists, run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-LoopStandard.ps1 -AllowPilotProject
```

# Phase 017 Report: Safe Temp Fixture Pruning

## Summary

Added a canonical dry-run-first temp fixture pruning command for ignored
`.tmp-ai-loop-*` test output. The command is Worker-agnostic harness
maintenance tooling and does not touch ordinary project folders.

## Changes

- Added `loop-standard/scripts/prune-temp-fixtures.ps1`.
- Added `ai-loop -Command prune-temp` forwarding with `-MinAgeHours`,
  `-KeepLatest`, `-DryRun`, and `-Force`.
- Added `loop-standard/scripts/Test-PruneTempFixtures.ps1`.
- Added `loop-standard/scripts/Test-Phase017.ps1`.
- Added prune files to `Test-LoopStandard.ps1` required path coverage.
- Documented prune behavior in `README.md`, `README_EN.md`, and
  `loop-standard/README.md`.

## Safety Behavior

- Default mode is dry-run.
- Deletion requires explicit `-Force`.
- Only `run-*` child directories under `.tmp-ai-loop-*` parents are candidates.
- Paths are resolved and checked against the project root before deletion.
- The newest run directories per temp parent are retained by `-KeepLatest`.
- Reparse-point parents or run directories are skipped instead of deleted.

## Verification

Ran:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-PruneTempFixtures.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-Phase017.ps1
```

Result: both passed.

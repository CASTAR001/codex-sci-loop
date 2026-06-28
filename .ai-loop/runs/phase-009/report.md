# Phase 009 Worker Report

## Summary

Implemented gate-aware `REWORK` follow-up scaffolding.

## Changes

- Added `loop-standard/scripts/scaffold-rework-phase.ps1`.
- Added `ai-loop -Command scaffold-rework`.
- Added installed shim support for `scaffold-rework`.
- Added `Test-ReworkScaffold.ps1`.
- Added `Test-Phase009.ps1` as the current verification matrix.
- Updated root README, English README, loop-standard README, and plugin workflow skills.

## Behavior

- `scaffold-rework` requires a durable source phase with status `rework`.
- It requires the source audit to contain `Decision: REWORK`.
- It requires `.ai-loop/runs/<source>/rework.txt`.
- It starts a bounded follow-up phase with scope derived from the source audit and rework decision.
- It writes `.ai-loop/runs/<rework-phase>/rework_source.json`.
- It refuses `BLOCKED` or otherwise non-REWORK source phases.

## Verification

Command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-Phase009.ps1
```

Result: passed.

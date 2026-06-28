# Phase 007 Worker Report

## Summary

Implemented non-destructive migration support for existing `.ai-loop` projects.

## Changes

- Added `loop-standard/scripts/migrate-loop.ps1`.
- Added `ai-loop migrate` routing in `loop-standard/scripts/ai-loop.ps1`.
- Added installed shim support for `migrate` in `install-global.ps1`.
- Added migration fixture tests in `Test-MigrateLoop.ps1`.
- Added `Test-Phase007.ps1` as the phase verification matrix.
- Extended `Test-LoopStandard.ps1` static checks for migration files and command exposure.
- Updated `README.md`, `README_EN.md`, and `loop-standard/README.md` with migration usage.

## Behavior

- Existing `.ai-loop` projects can be upgraded without overwriting project memory, evidence ledgers, or business files.
- Missing template files/directories are copied from `loop-standard/templates/.ai-loop/`.
- Missing top-level JSON properties are merged into `loop.config.json` and `status.json`.
- Schema markers are upgraded to the current template schema.
- Migration records are written under `.ai-loop/schema/migration-records/`.
- Human-readable migration notes are appended to `.ai-loop/schema/migration-log.md`.
- Future schema versions are blocked unless `-Force` is explicitly used.

## Verification

Command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-Phase007.ps1
```

Result: passed.

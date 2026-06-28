# Phase 021 Report: 1.0 Release Notes And Operator Checklist

## Summary

Added release-facing documentation for the 1.0 delivery surface. The new docs
make the current scope, verification matrix, known warning, non-goals, and
operator checklist explicit and git-trackable.

## Changes

- Added `loop-standard/docs/RELEASE_NOTES_1.0.md`.
- Added `loop-standard/docs/OPERATOR_CHECKLIST_1.0.md`.
- Added `loop-standard/scripts/Test-ReleaseDocs.ps1`.
- Added `loop-standard/scripts/Test-Phase021.ps1`.
- Updated `Test-LoopStandard.ps1` required path coverage.
- Updated `check-readiness.ps1` to require the new release docs.
- Linked the new docs from `README.md`, `README_EN.md`, and
  `loop-standard/README.md`.

## Verification

Ran:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-ReleaseDocs.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-Phase021.ps1
```

Result: both passed.

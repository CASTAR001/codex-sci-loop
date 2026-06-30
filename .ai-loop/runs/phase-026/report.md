# Worker Report: phase-026

## Summary

Made release sign-off matrix selection dynamic so `release-check` and
readiness do not silently point at stale `Test-PhaseNNN.ps1` files after new
accepted phases are added.

## Changes

- Changed `ai-loop.ps1` and `release-check.ps1` so an omitted `-MatrixScript`
  means "discover the highest numbered `Test-PhaseNNN.ps1` under
  `loop-standard/scripts/`."
- Kept explicit `-MatrixScript` overrides for focused or custom release checks.
- Made `release-check -SkipMatrix` still resolve and report the matrix script
  that would have run, while preserving skipped execution.
- Updated readiness `TEST-LATEST` to check the discovered latest phase matrix
  instead of a hard-coded phase file.
- Extended `Test-ReleaseCheck.ps1` and `Test-LoopStandard.ps1` to catch stale
  matrix defaults.
- Added `Test-Phase026.ps1` as the current non-global matrix wrapper.

## Verification

Ran:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-ReleaseCheck.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-Phase026.ps1
```

Result: passed.

# Phase 004 Worker Report

## Summary

Added negative fixture coverage for `validate-loop.ps1` and a phase-level
verification wrapper.

## Changes

- Added `loop-standard/scripts/Test-ValidateLoopFailures.ps1`.
- Added `loop-standard/scripts/Test-Phase004.ps1`.
- Updated `loop-standard/scripts/Test-LoopStandard.ps1` so the canonical
  self-check requires the new validation scripts.

## Verification

Ran:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-Phase004.ps1
```

Result: passed.

## Notes

The failure fixtures copy the repository root `.ai-loop/` into an ignored
temporary project and mutate only the copied control plane. They assert that
`validate-loop.ps1` rejects duplicate phases, broken current phase references,
illegal statuses, missing accepted audits, stale artifact hashes, and missing
recovery-critical files.

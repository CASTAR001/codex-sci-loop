# Phase 006 Worker Report

## Summary

Added durable `REWORK` and `BLOCKED` phase decision handling.

## Changes

- Added `loop-standard/scripts/decide-phase.ps1`.
- Added `ai-loop.ps1 -Command decide`.
- Updated installed shim generation in `install-global.ps1` to include
  `decide`.
- Updated `validate-loop.ps1` so `rework` and `blocked` phases require matching
  audit decisions and `rework.txt` / `blocked.txt`.
- Added `Test-PhaseDecisions.ps1` for REWORK, BLOCKED, and decision mismatch
  fixtures.
- Added `Test-Phase006.ps1` as the current verification matrix.
- Updated README and plugin skills to document durable non-accepted decisions.

## Verification

Ran:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-Phase006.ps1
```

Result: passed.

## Notes

`ACCEPTED` continues to use `accept` and phase gates. `REWORK` and `BLOCKED`
now use `decide`, which records the audit result into status, phase metadata,
decision files, and the event log so `resume` can reconstruct the next safe
action from files.

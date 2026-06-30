# Worker Report: phase-025

## Summary

Enhanced `ai-loop resume` recovery diagnostics so both text and JSON output
explain why a phase is resumable or blocked.

## Changes

- Added `recovery_reason` and `recovery_causes` to missing-status,
  invalid-status, initialized, and active-phase resume JSON outputs.
- Added matching human-readable `Recovery reason:` and `Recovery causes:`
  lines to text resume output.
- Derived recovery causes from existing status, transition, missing evidence,
  and artifact manifest checks instead of adding a second recovery state
  machine.
- Updated resume text and JSON fixture tests to assert started, blocked
  transition mismatch, missing evidence, artifact manifest, and missing status
  causes.
- Added `Test-Phase025.ps1` to run the new recovery tests plus the accepted
  phase-024 non-global matrix.

## Verification

Ran:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-Phase025.ps1
```

Result: passed.

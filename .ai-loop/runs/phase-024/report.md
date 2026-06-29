# Phase 024 Report

## Summary

Added a compact read-only `release-check` command for 1.0 delivery validation.
It aggregates readiness, loop-wide validation, and a verification matrix into
one human-readable or JSON report.

## Changes

- Added `loop-standard/scripts/release-check.ps1`.
- Added `ai-loop -Command release-check`.
- Added `-SkipMatrix` for quick diagnostics and `-MatrixScript` for controlled
  fixture testing.
- Added `Test-ReleaseCheck.ps1` and `Test-Phase024.ps1`.
- Updated readiness and kit self-checks to include release-check.
- Updated Chinese/English README files, `loop-standard/README.md`, release
  notes, and the 1.0 operator checklist.

## Verification

Ran:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-Phase024.ps1
```

Result: `Phase-024 verification: OK`.

Focused coverage:

- `release-check -Json -SkipMatrix` emits parseable JSON with one skipped
  matrix check.
- `release-check -Json -MatrixScript Test-TaskKindSkillTriggers.ps1` runs the
  requested matrix script and reports `RELEASE-MATRIX` as pass.
- Text output includes the `Loop Harness 1.0 Release Check` heading.
- A project missing `.ai-loop` returns nonzero while still emitting parseable
  blocked JSON.

## Notes

`release-check` is read-only. It does not modify real global Codex
configuration and does not call an external Worker service.

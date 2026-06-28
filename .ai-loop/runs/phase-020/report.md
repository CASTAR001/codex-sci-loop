# Phase 020 Report: 1.0 Readiness Audit Command

## Summary

Added a local read-only readiness audit command for the loop harness. The new
command maps the 1.0 delivery goal to current kit and project evidence, reports
blocking gaps versus warnings, and supports both human-readable and JSON output.

## Changes

- Added `loop-standard/scripts/check-readiness.ps1`.
- Added `ai-loop -Command readiness` with optional `-Json`.
- Readiness checks cover kit scripts, templates, project `.ai-loop`, evidence
  and state support, plugin scaffold, documentation, test matrix files, and
  loop-wide validation.
- Real global Codex plugin discovery is reported as a warning because it
  requires explicit user approval before modifying global Codex configuration.
- Added `Test-Readiness.ps1` and `Test-Phase020.ps1`.
- Updated `README.md`, `README_EN.md`, and `loop-standard/README.md`.

## Verification

Ran:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-Readiness.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-Phase020.ps1
```

Result: both passed.

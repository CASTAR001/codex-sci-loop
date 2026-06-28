# Phase 016 Report

## Summary

Added machine-readable resume output through `ai-loop resume -Json` while
preserving the default human-readable resume behavior.

## Changes

- Added a `-Json` switch to `ai-loop.ps1`.
- `resume -Json` now emits a single JSON object with current phase, phase
  status, required skills, required evidence, missing evidence, artifact
  manifest status, transition diagnostics, next safe action, next safe command,
  recovery decision, and blocked flag.
- Missing or invalid `.ai-loop/status.json` now returns parseable BLOCKED JSON
  when `-Json` is used.
- Default `resume` text output still includes the human summary and governance
  file dumps.
- Added `Test-ResumeJson.ps1` and `Test-Phase016.ps1`.
- Updated README files and the recovery plugin skill with the `-Json` usage.

## Verification

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-Phase016.ps1
```

Result: passed.

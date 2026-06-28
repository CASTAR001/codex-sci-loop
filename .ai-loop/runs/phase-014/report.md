# Phase 014 Report

## Summary

Implemented external Worker evidence requirements without invoking an external
Worker service.

## Changes

- Added `-RequireExternalWorkerEvidence` to phase start through
  `start-phase.ps1` and the unified `ai-loop.ps1` entrypoint.
- When the switch is used, `phase_requirements.json` now records
  `required_worker_evidence` and adds preflight/invocation artifacts to
  `evidence_required`.
- Extended `collect-evidence.ps1` so additional required evidence paths from
  phase requirements are written to the evidence ledger, artifact index, and
  artifact manifest.
- Added an explicit External Worker Evidence Requirements section to audit
  input.
- Added fixture coverage that proves missing external Worker evidence blocks
  validation and complete local evidence passes with manifest/audit coverage.
- Updated Chinese and English README files plus `loop-standard/README.md`.

## Verification

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-Phase014.ps1
```

Result: passed.

## Notes

No external Worker service was called. The fixture uses local files to exercise
the evidence requirements and gate behavior.

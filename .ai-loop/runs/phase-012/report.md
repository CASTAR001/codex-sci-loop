# Phase phase-012 Report

## Summary

Made `start-phase.ps1` idempotent for intentional forced restarts of the same
phase. A repeated `start -Force` now refreshes start-time files and ledgers
without duplicating the phase entry in `status.json`.

## Changes

- Added `Remove-MarkdownRowsForPhase` to `start-phase.ps1`.
- Refreshed start-time rows in `evidence-ledger.md`, `artifact-index.md`, and
  `skill-usage-ledger.md` before writing replacement rows.
- Replaced matching existing phase entries in `status.json.phases` instead of
  appending duplicates.
- Added `Test-StartPhaseIdempotence.ps1` to verify forced restart behavior.
- Added `Test-Phase012.ps1` as the current verification matrix.
- Updated README files to document the bounded `start -Force` semantics.

## Verification

- `Test-StartPhaseIdempotence.ps1`: passed.
- `Test-LoopStandard.ps1 -AllowPilotProject`: passed.
- `Test-Phase012.ps1`: passed.

## Notes

This phase does not change normal `start` behavior. Without `-Force`, existing
run directories still block accidental restarts.

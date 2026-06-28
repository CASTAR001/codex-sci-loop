# Phase 022 Report

## Summary

Added a declarative semantic migration transform layer for `.ai-loop`
migration. The migration path now supports template repair, semantic legacy
field repair, top-level JSON merge, schema marker upgrades, migration records,
and migration logs.

## Changes

- Added `.ai-loop/schema/migration-transforms.json` to the root control plane,
  `loop-standard/.ai-loop/`, and `loop-standard/templates/.ai-loop/`.
- Added migration transform support to `loop-standard/scripts/migrate-loop.ps1`.
- Added `semantic_transforms` to dry-run JSON plans and migration records.
- Added `Test-MigrateSemanticTransforms.ps1` and `Test-Phase022.ps1`.
- Updated `Test-LoopStandard.ps1` to require and parse the transform registry.
- Updated release/operator documentation to mention semantic migrations.

## Verification

Ran:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-Phase022.ps1
```

Result: `Phase-022 verification: OK`.

Focused semantic migration coverage:

- Dry-run reports semantic transform IDs.
- Dry-run does not mutate config or status files.
- Real migration repairs legacy `required_evidence`,
  `current_phase_id`, and `completed` status values.
- Migration records include applied semantic transform IDs.
- Current projects do not apply legacy transforms.

## Notes

Warnings about local Git ignore permissions and CRLF normalization were observed
during the verification matrix. They do not affect harness behavior.

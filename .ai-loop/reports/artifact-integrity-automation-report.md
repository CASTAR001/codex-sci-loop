# Artifact Integrity Automation Report

Date: 2026-06-25

## Scope

This phase added artifact hashing and evidence ledger automation to the loop
harness. Markdown ledgers remain the human-readable audit surface, and
`.ai-loop/evidence/artifact-manifest.json` is now the machine-readable
integrity source for gate validation.

## Implemented

- Added `artifact-manifest.json` to root, reusable template, and compatibility
  `.ai-loop` evidence directories.
- Added the manifest to `loop.config.json` evidence ledgers.
- `collect-evidence.ps1` now records SHA256, size, mtime, phase, type, path,
  producer, status, and recorded time for required phase evidence.
- `artifact-index.md` rows now include short hash and size summaries in Notes.
- `validate-phase-gates.ps1` blocks missing manifests, missing manifest rows,
  invalid manifest statuses, hash mismatches, and size mismatches.
- `prepare-audit-pack.ps1` adds an Artifact Integrity Summary to audit input.
- `ai-loop resume` reports artifact manifest status and integrity problem count.
- `ai-loop doctor` checks the template manifest exists and parses.

## Verification

Passed:

- PowerShell parse check.
- `Test-LoopStandard.ps1 -AllowPilotProject`, now checking 75 paths.
- `ai-loop doctor`.
- Fullstack phase generates manifest and passes validation.
- Audit input contains Artifact Integrity Summary.
- Hash mismatch blocks validation.
- Missing manifest row blocks validation.
- Missing required evidence file blocks validation.
- Empty required evidence file blocks validation.
- Missing artifact manifest blocks validation.
- Installed shim doctor/init/collect/validate still work.
- Physics-research missing skill artifacts still block audit readiness.
- Uppercase compatibility wrapper smoke flow still validates through canonical
  gates.
- README UTF-8 check and `git diff --check`.

## Remaining Work

- Decide whether required skill artifacts should be mandatory manifest entries.
- Add transition-log validation for stricter state-machine enforcement.
- Expand full-stack and physics skill trigger matrix.

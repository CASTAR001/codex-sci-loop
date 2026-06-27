# Codex Audit: phase-004

Decision: ACCEPTED

## Scope Inspected

- Worker report: `.ai-loop/runs/phase-004/report.md`
- Diff: `.ai-loop/runs/phase-004/diff.patch`
- Verification log: `.ai-loop/runs/phase-004/verify.log`
- Changed files: `.ai-loop/runs/phase-004/changed_files.txt`
- Artifact manifest: `.ai-loop/evidence/artifact-manifest.json`
- Audit input: `.ai-loop/audits/phase-004-audit-input.md`
- Source files:
  - `loop-standard/scripts/Test-ValidateLoopFailures.ps1`
  - `loop-standard/scripts/Test-CollectLedgerIdempotence.ps1`
  - `loop-standard/scripts/Test-Phase004.ps1`
  - `loop-standard/scripts/Test-LoopStandard.ps1`
  - `loop-standard/scripts/collect-evidence.ps1`

## Findings

No blocking findings.

## Evidence Review

The phase added negative fixture tests for `validate-loop.ps1`. The fixtures copy
the root `.ai-loop/` control plane into an ignored temporary directory and
mutate the copied state to prove validation rejects duplicate phase IDs, broken
`current_phase`, illegal statuses, missing accepted audits, stale artifact
hashes, and missing recovery-critical files.

The phase also fixed two collect-time issues discovered while refreshing final
evidence: Markdown ledger row refreshes now rewrite via `Set-Content -Value`,
and verification command stderr is captured into `verify.log` without aborting
collection when the command exits successfully.

`Test-CollectLedgerIdempotence.ps1` initializes an ignored temporary project,
runs `collect` twice for the same phase, validates the phase gate, and confirms
evidence/command/test/provenance ledgers do not duplicate phase rows.

`Test-Phase004.ps1` ran the main loop-standard self-check, plugin install smoke
test, validate-loop failure fixtures, collect ledger idempotence fixture, and
root `validate-loop.ps1`.

Verification passed with `exit_code: 0`. The audit input reports required
evidence as present and artifact integrity checks as `OK`. The verify log
contains non-fatal git permission warnings from the host user config; these were
captured as log evidence and did not affect the command exit code.

## Residual Risk

The new coverage validates current control-plane invariants, but schema
migration/version compatibility remains a separate future phase.

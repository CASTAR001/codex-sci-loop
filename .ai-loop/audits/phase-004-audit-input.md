# Codex Audit Input: phase-004

## Project Root

    E:\codexfiles\loop

## Required Evidence Files

- status: E:\codexfiles\loop\.ai-loop\status.json
- base commit: E:\codexfiles\loop\.ai-loop\runs\phase-004\base_commit.txt
- status before: E:\codexfiles\loop\.ai-loop\runs\phase-004\status_before.txt
- phase metadata: E:\codexfiles\loop\.ai-loop\runs\phase-004\phase_meta.json
- phase requirements: E:\codexfiles\loop\.ai-loop\runs\phase-004\phase_requirements.json
- prompt: E:\codexfiles\loop\.ai-loop\runs\phase-004\prompt.md
- Worker report: E:\codexfiles\loop\.ai-loop\runs\phase-004\report.md
- status after: E:\codexfiles\loop\.ai-loop\runs\phase-004\status_after.txt
- diff: E:\codexfiles\loop\.ai-loop\runs\phase-004\diff.patch
- verify log: E:\codexfiles\loop\.ai-loop\runs\phase-004\verify.log
- changed files: E:\codexfiles\loop\.ai-loop\runs\phase-004\changed_files.txt
- changed business files: E:\codexfiles\loop\.ai-loop\runs\phase-004\changed_business_files.txt
- changed evidence files: E:\codexfiles\loop\.ai-loop\runs\phase-004\changed_evidence_files.txt
- evidence ledger: E:\codexfiles\loop\.ai-loop\evidence\evidence-ledger.md
- artifact manifest: E:\codexfiles\loop\.ai-loop\evidence\artifact-manifest.json
- artifact index: E:\codexfiles\loop\.ai-loop\evidence\artifact-index.md
- command log: E:\codexfiles\loop\.ai-loop\evidence\command-log.md
- test log: E:\codexfiles\loop\.ai-loop\evidence\test-log.md
- provenance map: E:\codexfiles\loop\.ai-loop\evidence\provenance-map.md
- skill trigger matrix: E:\codexfiles\loop\.ai-loop\skills\skill-trigger-matrix.md
- skill usage ledger: E:\codexfiles\loop\.ai-loop\skills\skill-usage-ledger.md
- skill artifact map: E:\codexfiles\loop\.ai-loop\skills\skill-artifact-map.md

## Changed Or Relevant Source Files

- .ai-loop/audits/phase-004-audit.md
- .ai-loop/audits/phase-004-audit-input.md
- .ai-loop/evidence/artifact-index.md
- .ai-loop/evidence/artifact-manifest.json
- .ai-loop/evidence/command-log.md
- .ai-loop/evidence/evidence-ledger.md
- .ai-loop/evidence/provenance-map.md
- .ai-loop/evidence/test-log.md
- .ai-loop/memory/activeContext.md
- .ai-loop/memory/handoff-summary.md
- .ai-loop/memory/progress.md
- .ai-loop/runs/phase-004/accepted.txt
- .ai-loop/runs/phase-004/base_commit.txt
- .ai-loop/runs/phase-004/changed_business_files.txt
- .ai-loop/runs/phase-004/changed_evidence_files.txt
- .ai-loop/runs/phase-004/changed_files.txt
- .ai-loop/runs/phase-004/diff.patch
- .ai-loop/runs/phase-004/phase_meta.json
- .ai-loop/runs/phase-004/phase_requirements.json
- .ai-loop/runs/phase-004/prompt.md
- .ai-loop/runs/phase-004/report.md
- .ai-loop/runs/phase-004/status_after.txt
- .ai-loop/runs/phase-004/status_before.txt
- .ai-loop/runs/phase-004/verify.log
- .ai-loop/status.json
- loop-standard/scripts/collect-evidence.ps1
- loop-standard/scripts/Test-CollectLedgerIdempotence.ps1
- loop-standard/scripts/Test-LoopStandard.ps1
- loop-standard/scripts/Test-Phase004.ps1
- loop-standard/scripts/Test-ValidateLoopFailures.ps1

## Changed Business Files

- loop-standard/scripts/collect-evidence.ps1
- loop-standard/scripts/Test-CollectLedgerIdempotence.ps1
- loop-standard/scripts/Test-LoopStandard.ps1
- loop-standard/scripts/Test-Phase004.ps1
- loop-standard/scripts/Test-ValidateLoopFailures.ps1

## Changed Evidence Files

- .ai-loop/audits/phase-004-audit.md
- .ai-loop/audits/phase-004-audit-input.md
- .ai-loop/evidence/artifact-index.md
- .ai-loop/evidence/artifact-manifest.json
- .ai-loop/evidence/command-log.md
- .ai-loop/evidence/evidence-ledger.md
- .ai-loop/evidence/provenance-map.md
- .ai-loop/evidence/test-log.md
- .ai-loop/memory/activeContext.md
- .ai-loop/memory/handoff-summary.md
- .ai-loop/memory/progress.md
- .ai-loop/runs/phase-004/accepted.txt
- .ai-loop/runs/phase-004/base_commit.txt
- .ai-loop/runs/phase-004/changed_business_files.txt
- .ai-loop/runs/phase-004/changed_evidence_files.txt
- .ai-loop/runs/phase-004/changed_files.txt
- .ai-loop/runs/phase-004/diff.patch
- .ai-loop/runs/phase-004/phase_meta.json
- .ai-loop/runs/phase-004/phase_requirements.json
- .ai-loop/runs/phase-004/prompt.md
- .ai-loop/runs/phase-004/report.md
- .ai-loop/runs/phase-004/status_after.txt
- .ai-loop/runs/phase-004/status_before.txt
- .ai-loop/runs/phase-004/verify.log
- .ai-loop/status.json

## Artifact Integrity Summary

| Path | Manifest Status | SHA256 | Size | Check |
| --- | --- | --- | --- | --- |
| .ai-loop/runs/phase-004/prompt.md | recorded | EF407C5A35F3 | 1201 | OK |
| .ai-loop/runs/phase-004/report.md | recorded | 3431540555F1 | 886 | OK |
| .ai-loop/runs/phase-004/status_after.txt | recorded | B86B6F43C64C | 743 | OK |
| .ai-loop/runs/phase-004/diff.patch | recorded | 7C0BF7C81866 | 107523 | OK |
| .ai-loop/runs/phase-004/verify.log | recorded | 64BF1E272CBD | 2016 | OK |
| .ai-loop/runs/phase-004/changed_files.txt | recorded | E0B46B514A02 | 1206 | OK |
| .ai-loop/runs/phase-004/changed_business_files.txt | recorded | AA788641C6D1 | 245 | OK |
| .ai-loop/runs/phase-004/changed_evidence_files.txt | recorded | 5A3A78312CD5 | 966 | OK |
| .ai-loop/runs/phase-004/phase_requirements.json | recorded | 2CC615B385E6 | 986 | OK |

## Missing Or Invalid Evidence

None

## Phase Gate Validation

`	ext
Phase gate validation: OK
Project root: E:\codexfiles\loop
Phase: phase-004
Target status: audit_ready
`

## Audit Instructions

Codex must inspect the Worker report, diff, verify log, status files, phase
metadata, phase requirements, evidence ledger, skill usage ledger, and relevant
source files. Codex must not accept based only on the Worker report.

If evidence is missing, contains MISSING:, verification failed, required skill
artifacts are missing, artifact integrity is missing or mismatched, or source
inspection cannot be completed, Codex must decide BLOCKED or REWORK.

Write the audit result to:

    E:\codexfiles\loop\.ai-loop\audits\phase-004-audit.md

The audit result must contain exactly one decision line:

    Decision: ACCEPTED

or:

    Decision: REWORK

or:

    Decision: BLOCKED

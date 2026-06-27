# Codex Audit Input: phase-005

## Project Root

    E:\codexfiles\loop

## Required Evidence Files

- status: E:\codexfiles\loop\.ai-loop\status.json
- base commit: E:\codexfiles\loop\.ai-loop\runs\phase-005\base_commit.txt
- status before: E:\codexfiles\loop\.ai-loop\runs\phase-005\status_before.txt
- phase metadata: E:\codexfiles\loop\.ai-loop\runs\phase-005\phase_meta.json
- phase requirements: E:\codexfiles\loop\.ai-loop\runs\phase-005\phase_requirements.json
- prompt: E:\codexfiles\loop\.ai-loop\runs\phase-005\prompt.md
- Worker report: E:\codexfiles\loop\.ai-loop\runs\phase-005\report.md
- status after: E:\codexfiles\loop\.ai-loop\runs\phase-005\status_after.txt
- diff: E:\codexfiles\loop\.ai-loop\runs\phase-005\diff.patch
- verify log: E:\codexfiles\loop\.ai-loop\runs\phase-005\verify.log
- changed files: E:\codexfiles\loop\.ai-loop\runs\phase-005\changed_files.txt
- changed business files: E:\codexfiles\loop\.ai-loop\runs\phase-005\changed_business_files.txt
- changed evidence files: E:\codexfiles\loop\.ai-loop\runs\phase-005\changed_evidence_files.txt
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

- .ai-loop/audits/phase-005-audit.md
- .ai-loop/audits/phase-005-audit-input.md
- .ai-loop/evidence/artifact-index.md
- .ai-loop/evidence/artifact-manifest.json
- .ai-loop/evidence/command-log.md
- .ai-loop/evidence/evidence-ledger.md
- .ai-loop/evidence/provenance-map.md
- .ai-loop/evidence/test-log.md
- .ai-loop/memory/activeContext.md
- .ai-loop/memory/handoff-summary.md
- .ai-loop/memory/progress.md
- .ai-loop/README.md
- .ai-loop/runs/phase-005/accepted.txt
- .ai-loop/runs/phase-005/base_commit.txt
- .ai-loop/runs/phase-005/changed_business_files.txt
- .ai-loop/runs/phase-005/changed_evidence_files.txt
- .ai-loop/runs/phase-005/changed_files.txt
- .ai-loop/runs/phase-005/diff.patch
- .ai-loop/runs/phase-005/phase_meta.json
- .ai-loop/runs/phase-005/phase_requirements.json
- .ai-loop/runs/phase-005/prompt.md
- .ai-loop/runs/phase-005/report.md
- .ai-loop/runs/phase-005/status_after.txt
- .ai-loop/runs/phase-005/status_before.txt
- .ai-loop/runs/phase-005/verify.log
- .ai-loop/schema/migration-log.md
- .ai-loop/schema/schema-version.json
- .ai-loop/status.json
- loop-standard/.ai-loop/schema/migration-log.md
- loop-standard/.ai-loop/schema/schema-version.json
- loop-standard/README.md
- loop-standard/scripts/ai-loop.ps1
- loop-standard/scripts/Test-LoopStandard.ps1
- loop-standard/scripts/Test-Phase005.ps1
- loop-standard/scripts/Test-SchemaVersioning.ps1
- loop-standard/scripts/validate-loop.ps1
- loop-standard/templates/.ai-loop/schema/migration-log.md
- loop-standard/templates/.ai-loop/schema/schema-version.json
- README.md
- README_EN.md

## Changed Business Files

- loop-standard/.ai-loop/schema/migration-log.md
- loop-standard/.ai-loop/schema/schema-version.json
- loop-standard/README.md
- loop-standard/scripts/ai-loop.ps1
- loop-standard/scripts/Test-LoopStandard.ps1
- loop-standard/scripts/Test-Phase005.ps1
- loop-standard/scripts/Test-SchemaVersioning.ps1
- loop-standard/scripts/validate-loop.ps1
- loop-standard/templates/.ai-loop/schema/migration-log.md
- loop-standard/templates/.ai-loop/schema/schema-version.json
- README.md
- README_EN.md

## Changed Evidence Files

- .ai-loop/audits/phase-005-audit.md
- .ai-loop/audits/phase-005-audit-input.md
- .ai-loop/evidence/artifact-index.md
- .ai-loop/evidence/artifact-manifest.json
- .ai-loop/evidence/command-log.md
- .ai-loop/evidence/evidence-ledger.md
- .ai-loop/evidence/provenance-map.md
- .ai-loop/evidence/test-log.md
- .ai-loop/memory/activeContext.md
- .ai-loop/memory/handoff-summary.md
- .ai-loop/memory/progress.md
- .ai-loop/README.md
- .ai-loop/runs/phase-005/accepted.txt
- .ai-loop/runs/phase-005/base_commit.txt
- .ai-loop/runs/phase-005/changed_business_files.txt
- .ai-loop/runs/phase-005/changed_evidence_files.txt
- .ai-loop/runs/phase-005/changed_files.txt
- .ai-loop/runs/phase-005/diff.patch
- .ai-loop/runs/phase-005/phase_meta.json
- .ai-loop/runs/phase-005/phase_requirements.json
- .ai-loop/runs/phase-005/prompt.md
- .ai-loop/runs/phase-005/report.md
- .ai-loop/runs/phase-005/status_after.txt
- .ai-loop/runs/phase-005/status_before.txt
- .ai-loop/runs/phase-005/verify.log
- .ai-loop/schema/migration-log.md
- .ai-loop/schema/schema-version.json
- .ai-loop/status.json

## Artifact Integrity Summary

| Path | Manifest Status | SHA256 | Size | Check |
| --- | --- | --- | --- | --- |
| .ai-loop/runs/phase-005/prompt.md | recorded | DC270B543385 | 1253 | OK |
| .ai-loop/runs/phase-005/report.md | recorded | 90527B9740AD | 1107 | OK |
| .ai-loop/runs/phase-005/status_after.txt | recorded | C8CFE26F7EB1 | 897 | OK |
| .ai-loop/runs/phase-005/diff.patch | recorded | 45CA08147FD2 | 139611 | OK |
| .ai-loop/runs/phase-005/verify.log | recorded | F726FC376262 | 2188 | OK |
| .ai-loop/runs/phase-005/changed_files.txt | recorded | BC256B9C15EC | 1536 | OK |
| .ai-loop/runs/phase-005/changed_business_files.txt | recorded | FB66A7E1823C | 484 | OK |
| .ai-loop/runs/phase-005/changed_evidence_files.txt | recorded | 81269F36B567 | 1057 | OK |
| .ai-loop/runs/phase-005/phase_requirements.json | recorded | EE27593793DA | 986 | OK |

## Missing Or Invalid Evidence

None

## Phase Gate Validation

`	ext
Phase gate validation: OK
Project root: E:\codexfiles\loop
Phase: phase-005
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

    E:\codexfiles\loop\.ai-loop\audits\phase-005-audit.md

The audit result must contain exactly one decision line:

    Decision: ACCEPTED

or:

    Decision: REWORK

or:

    Decision: BLOCKED

# Codex Audit Input: phase-001

## Project Root

    E:\codexfiles\loop

## Required Evidence Files

- status: E:\codexfiles\loop\.ai-loop\status.json
- base commit: E:\codexfiles\loop\.ai-loop\runs\phase-001\base_commit.txt
- status before: E:\codexfiles\loop\.ai-loop\runs\phase-001\status_before.txt
- phase metadata: E:\codexfiles\loop\.ai-loop\runs\phase-001\phase_meta.json
- phase requirements: E:\codexfiles\loop\.ai-loop\runs\phase-001\phase_requirements.json
- prompt: E:\codexfiles\loop\.ai-loop\runs\phase-001\prompt.md
- Worker report: E:\codexfiles\loop\.ai-loop\runs\phase-001\report.md
- status after: E:\codexfiles\loop\.ai-loop\runs\phase-001\status_after.txt
- diff: E:\codexfiles\loop\.ai-loop\runs\phase-001\diff.patch
- verify log: E:\codexfiles\loop\.ai-loop\runs\phase-001\verify.log
- changed files: E:\codexfiles\loop\.ai-loop\runs\phase-001\changed_files.txt
- changed business files: E:\codexfiles\loop\.ai-loop\runs\phase-001\changed_business_files.txt
- changed evidence files: E:\codexfiles\loop\.ai-loop\runs\phase-001\changed_evidence_files.txt
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

- .ai-loop/audits/phase-001-audit.md
- .ai-loop/audits/phase-001-audit-input.md
- .ai-loop/audits/README.md
- .ai-loop/evidence/artifact-index.md
- .ai-loop/evidence/artifact-manifest.json
- .ai-loop/evidence/command-log.md
- .ai-loop/evidence/evidence-ledger.md
- .ai-loop/evidence/provenance-map.md
- .ai-loop/evidence/test-log.md
- .ai-loop/loop.config.json
- .ai-loop/memory/activeContext.md
- .ai-loop/memory/handoff-summary.md
- .ai-loop/memory/progress.md
- .ai-loop/runs/phase-001/accepted.txt
- .ai-loop/runs/phase-001/base_commit.txt
- .ai-loop/runs/phase-001/changed_business_files.txt
- .ai-loop/runs/phase-001/changed_evidence_files.txt
- .ai-loop/runs/phase-001/changed_files.txt
- .ai-loop/runs/phase-001/diff.patch
- .ai-loop/runs/phase-001/phase_meta.json
- .ai-loop/runs/phase-001/phase_requirements.json
- .ai-loop/runs/phase-001/prompt.md
- .ai-loop/runs/phase-001/report.md
- .ai-loop/runs/phase-001/status_after.txt
- .ai-loop/runs/phase-001/status_before.txt
- .ai-loop/runs/phase-001/verify.log
- .ai-loop/runs/README.md
- .ai-loop/status.json
- .ai-loop/templates/audit.md
- .ai-loop/templates/audit-input.md
- .ai-loop/templates/phase-plan.md
- .ai-loop/templates/prompt.md
- .ai-loop/templates/report.md
- loop-standard/scripts/ai-loop.ps1
- loop-standard/scripts/collect-evidence.ps1
- loop-standard/scripts/init-loop.ps1
- loop-standard/scripts/Test-LoopStandard.ps1
- loop-standard/templates/.ai-loop/templates/audit.md
- loop-standard/templates/.ai-loop/templates/audit-input.md
- loop-standard/templates/.ai-loop/templates/phase-plan.md
- loop-standard/templates/.ai-loop/templates/prompt.md
- loop-standard/templates/.ai-loop/templates/report.md

## Changed Business Files

- loop-standard/scripts/ai-loop.ps1
- loop-standard/scripts/collect-evidence.ps1
- loop-standard/scripts/init-loop.ps1
- loop-standard/scripts/Test-LoopStandard.ps1
- loop-standard/templates/.ai-loop/templates/audit.md
- loop-standard/templates/.ai-loop/templates/audit-input.md
- loop-standard/templates/.ai-loop/templates/phase-plan.md
- loop-standard/templates/.ai-loop/templates/prompt.md
- loop-standard/templates/.ai-loop/templates/report.md

## Changed Evidence Files

- .ai-loop/audits/phase-001-audit.md
- .ai-loop/audits/phase-001-audit-input.md
- .ai-loop/audits/README.md
- .ai-loop/evidence/artifact-index.md
- .ai-loop/evidence/artifact-manifest.json
- .ai-loop/evidence/command-log.md
- .ai-loop/evidence/evidence-ledger.md
- .ai-loop/evidence/provenance-map.md
- .ai-loop/evidence/test-log.md
- .ai-loop/loop.config.json
- .ai-loop/memory/activeContext.md
- .ai-loop/memory/handoff-summary.md
- .ai-loop/memory/progress.md
- .ai-loop/runs/phase-001/accepted.txt
- .ai-loop/runs/phase-001/base_commit.txt
- .ai-loop/runs/phase-001/changed_business_files.txt
- .ai-loop/runs/phase-001/changed_evidence_files.txt
- .ai-loop/runs/phase-001/changed_files.txt
- .ai-loop/runs/phase-001/diff.patch
- .ai-loop/runs/phase-001/phase_meta.json
- .ai-loop/runs/phase-001/phase_requirements.json
- .ai-loop/runs/phase-001/prompt.md
- .ai-loop/runs/phase-001/report.md
- .ai-loop/runs/phase-001/status_after.txt
- .ai-loop/runs/phase-001/status_before.txt
- .ai-loop/runs/phase-001/verify.log
- .ai-loop/runs/README.md
- .ai-loop/status.json
- .ai-loop/templates/audit.md
- .ai-loop/templates/audit-input.md
- .ai-loop/templates/phase-plan.md
- .ai-loop/templates/prompt.md
- .ai-loop/templates/report.md

## Artifact Integrity Summary

| Path | Manifest Status | SHA256 | Size | Check |
| --- | --- | --- | --- | --- |
| .ai-loop/runs/phase-001/prompt.md | recorded | 18C1EFF1850B | 1277 | OK |
| .ai-loop/runs/phase-001/report.md | recorded | AB3690C941FD | 1347 | OK |
| .ai-loop/runs/phase-001/status_after.txt | recorded | F2364F7E1057 | 1084 | OK |
| .ai-loop/runs/phase-001/diff.patch | recorded | B9AA9653A1A7 | 34229 | OK |
| .ai-loop/runs/phase-001/verify.log | recorded | 35439220EC37 | 346 | OK |
| .ai-loop/runs/phase-001/changed_files.txt | recorded | 1D0EA2D78BAD | 1642 | OK |
| .ai-loop/runs/phase-001/changed_business_files.txt | recorded | F93105306BF7 | 444 | OK |
| .ai-loop/runs/phase-001/changed_evidence_files.txt | recorded | 2FE9ED10EAFA | 1203 | OK |
| .ai-loop/runs/phase-001/phase_requirements.json | recorded | FA16479F479D | 986 | OK |

## Missing Or Invalid Evidence

None

## Phase Gate Validation

`	ext
Phase gate validation: OK
Project root: E:\codexfiles\loop
Phase: phase-001
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

    E:\codexfiles\loop\.ai-loop\audits\phase-001-audit.md

The audit result must contain exactly one decision line:

    Decision: ACCEPTED

or:

    Decision: REWORK

or:

    Decision: BLOCKED

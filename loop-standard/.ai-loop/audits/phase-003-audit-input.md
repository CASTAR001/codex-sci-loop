# Codex Audit Input: phase-003

## Project Root

    E:\codexfiles\loop\loop-standard

## Required Evidence Files

- status: E:\codexfiles\loop\loop-standard\.ai-loop\status.json
- base commit: E:\codexfiles\loop\loop-standard\.ai-loop\runs\phase-003\base_commit.txt
- status before: E:\codexfiles\loop\loop-standard\.ai-loop\runs\phase-003\status_before.txt
- phase metadata: E:\codexfiles\loop\loop-standard\.ai-loop\runs\phase-003\phase_meta.json
- phase requirements: E:\codexfiles\loop\loop-standard\.ai-loop\runs\phase-003\phase_requirements.json
- prompt: E:\codexfiles\loop\loop-standard\.ai-loop\runs\phase-003\prompt.md
- Worker report: E:\codexfiles\loop\loop-standard\.ai-loop\runs\phase-003\report.md
- status after: E:\codexfiles\loop\loop-standard\.ai-loop\runs\phase-003\status_after.txt
- diff: E:\codexfiles\loop\loop-standard\.ai-loop\runs\phase-003\diff.patch
- verify log: E:\codexfiles\loop\loop-standard\.ai-loop\runs\phase-003\verify.log
- changed files: E:\codexfiles\loop\loop-standard\.ai-loop\runs\phase-003\changed_files.txt
- changed business files: E:\codexfiles\loop\loop-standard\.ai-loop\runs\phase-003\changed_business_files.txt
- changed evidence files: E:\codexfiles\loop\loop-standard\.ai-loop\runs\phase-003\changed_evidence_files.txt
- evidence ledger: E:\codexfiles\loop\loop-standard\.ai-loop\evidence\evidence-ledger.md
- artifact manifest: E:\codexfiles\loop\loop-standard\.ai-loop\evidence\artifact-manifest.json
- artifact index: E:\codexfiles\loop\loop-standard\.ai-loop\evidence\artifact-index.md
- command log: E:\codexfiles\loop\loop-standard\.ai-loop\evidence\command-log.md
- test log: E:\codexfiles\loop\loop-standard\.ai-loop\evidence\test-log.md
- provenance map: E:\codexfiles\loop\loop-standard\.ai-loop\evidence\provenance-map.md
- skill trigger matrix: E:\codexfiles\loop\loop-standard\.ai-loop\skills\skill-trigger-matrix.md
- skill usage ledger: E:\codexfiles\loop\loop-standard\.ai-loop\skills\skill-usage-ledger.md
- skill artifact map: E:\codexfiles\loop\loop-standard\.ai-loop\skills\skill-artifact-map.md

## Changed Or Relevant Source Files

- .ai-loop/evidence/artifact-index.md
- .ai-loop/evidence/evidence-ledger.md
- .ai-loop/status.json
- scripts/collect-evidence.ps1
- scripts/Test-LoopStandard.ps1

## Changed Business Files

- scripts/collect-evidence.ps1
- scripts/Test-LoopStandard.ps1

## Changed Evidence Files

- .ai-loop/evidence/artifact-index.md
- .ai-loop/evidence/evidence-ledger.md
- .ai-loop/status.json

## Artifact Integrity Summary

| Path | Manifest Status | SHA256 | Size | Check |
| --- | --- | --- | --- | --- |
| .ai-loop/runs/phase-003/prompt.md | recorded | 3BD8778E016F | 1326 | OK |
| .ai-loop/runs/phase-003/report.md | recorded | 071BD2BF279C | 1035 | OK |
| .ai-loop/runs/phase-003/status_after.txt | recorded | 6740091335A0 | 207 | OK |
| .ai-loop/runs/phase-003/diff.patch | recorded | D9332F9E0A3D | 22829 | OK |
| .ai-loop/runs/phase-003/verify.log | recorded | 8FBAB65E4EA9 | 332 | OK |
| .ai-loop/runs/phase-003/changed_files.txt | recorded | 2568F0A2AF12 | 163 | OK |
| .ai-loop/runs/phase-003/changed_business_files.txt | recorded | 9B0870E9F6F0 | 66 | OK |
| .ai-loop/runs/phase-003/changed_evidence_files.txt | recorded | F88F2D5419D1 | 102 | OK |
| .ai-loop/runs/phase-003/phase_requirements.json | recorded | EDFE79F4DA5C | 986 | OK |

## Missing Or Invalid Evidence

None

## Phase Gate Validation

`	ext
Phase gate validation: OK
Project root: E:\codexfiles\loop\loop-standard
Phase: phase-003
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

    E:\codexfiles\loop\loop-standard\.ai-loop\audits\phase-003-audit.md

The audit result must contain exactly one decision line:

    Decision: ACCEPTED

or:

    Decision: REWORK

or:

    Decision: BLOCKED

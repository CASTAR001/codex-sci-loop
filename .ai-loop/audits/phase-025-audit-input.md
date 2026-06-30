# Codex Audit Input: phase-025

## Project Root

    E:\codexfiles\loop

## Required Evidence Files

- status: E:\codexfiles\loop\.ai-loop\status.json
- base commit: E:\codexfiles\loop\.ai-loop\runs\phase-025\base_commit.txt
- status before: E:\codexfiles\loop\.ai-loop\runs\phase-025\status_before.txt
- phase metadata: E:\codexfiles\loop\.ai-loop\runs\phase-025\phase_meta.json
- phase requirements: E:\codexfiles\loop\.ai-loop\runs\phase-025\phase_requirements.json
- prompt: E:\codexfiles\loop\.ai-loop\runs\phase-025\prompt.md
- Worker report: E:\codexfiles\loop\.ai-loop\runs\phase-025\report.md
- status after: E:\codexfiles\loop\.ai-loop\runs\phase-025\status_after.txt
- diff: E:\codexfiles\loop\.ai-loop\runs\phase-025\diff.patch
- verify log: E:\codexfiles\loop\.ai-loop\runs\phase-025\verify.log
- changed files: E:\codexfiles\loop\.ai-loop\runs\phase-025\changed_files.txt
- changed business files: E:\codexfiles\loop\.ai-loop\runs\phase-025\changed_business_files.txt
- changed evidence files: E:\codexfiles\loop\.ai-loop\runs\phase-025\changed_evidence_files.txt
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

- .ai-loop/events/state-transitions.ndjson
- .ai-loop/evidence/artifact-index.md
- .ai-loop/evidence/evidence-ledger.md
- .ai-loop/runs/phase-025/base_commit.txt
- .ai-loop/runs/phase-025/diff.patch
- .ai-loop/runs/phase-025/phase_meta.json
- .ai-loop/runs/phase-025/phase_requirements.json
- .ai-loop/runs/phase-025/prompt.md
- .ai-loop/runs/phase-025/report.md
- .ai-loop/runs/phase-025/status_after.txt
- .ai-loop/runs/phase-025/status_before.txt
- .ai-loop/runs/phase-025/verify.log
- .ai-loop/skills/skill-usage-ledger.md
- .ai-loop/status.json
- loop-standard/scripts/ai-loop.ps1
- loop-standard/scripts/Test-LoopStandard.ps1
- loop-standard/scripts/Test-Phase025.ps1
- loop-standard/scripts/Test-ResumeDiagnostics.ps1
- loop-standard/scripts/Test-ResumeJson.ps1

## Changed Business Files

- loop-standard/scripts/ai-loop.ps1
- loop-standard/scripts/Test-LoopStandard.ps1
- loop-standard/scripts/Test-Phase025.ps1
- loop-standard/scripts/Test-ResumeDiagnostics.ps1
- loop-standard/scripts/Test-ResumeJson.ps1

## Changed Evidence Files

- .ai-loop/events/state-transitions.ndjson
- .ai-loop/evidence/artifact-index.md
- .ai-loop/evidence/evidence-ledger.md
- .ai-loop/runs/phase-025/base_commit.txt
- .ai-loop/runs/phase-025/diff.patch
- .ai-loop/runs/phase-025/phase_meta.json
- .ai-loop/runs/phase-025/phase_requirements.json
- .ai-loop/runs/phase-025/prompt.md
- .ai-loop/runs/phase-025/report.md
- .ai-loop/runs/phase-025/status_after.txt
- .ai-loop/runs/phase-025/status_before.txt
- .ai-loop/runs/phase-025/verify.log
- .ai-loop/skills/skill-usage-ledger.md
- .ai-loop/status.json

## Artifact Integrity Summary

| Path | Manifest Status | SHA256 | Size | Check |
| --- | --- | --- | --- | --- |
| .ai-loop/runs/phase-025/prompt.md | recorded | 2A572DCA3B6F | 1521 | OK |
| .ai-loop/runs/phase-025/report.md | recorded | B24DC4FCDC80 | 1002 | OK |
| .ai-loop/runs/phase-025/status_after.txt | recorded | D0BC12E5DEB2 | 456 | OK |
| .ai-loop/runs/phase-025/diff.patch | recorded | A180DCB24FE7 | 353336 | OK |
| .ai-loop/runs/phase-025/verify.log | recorded | 7278A4502B08 | 13386 | OK |
| .ai-loop/runs/phase-025/changed_files.txt | recorded | B006C0402D75 | 755 | OK |
| .ai-loop/runs/phase-025/changed_business_files.txt | recorded | D92DC7DE660C | 219 | OK |
| .ai-loop/runs/phase-025/changed_evidence_files.txt | recorded | 14CB21F1FB0C | 541 | OK |
| .ai-loop/runs/phase-025/phase_requirements.json | recorded | 20404FF96D17 | 1138 | OK |

## External Worker Evidence Requirements

None declared.

## Missing Or Invalid Evidence

None

## Phase Gate Validation

```text
Phase gate validation: OK
Project root: E:\codexfiles\loop
Phase: phase-025
Target status: audit_ready
```

## Audit Instructions

Codex must inspect the Worker report, diff, verify log, status files, phase
metadata, phase requirements, evidence ledger, skill usage ledger, and relevant
source files. Codex must not accept based only on the Worker report.

If evidence is missing, contains MISSING:, verification failed, required skill
artifacts are missing, artifact integrity is missing or mismatched, or source
inspection cannot be completed, Codex must decide BLOCKED or REWORK.

Write the audit result to:

    E:\codexfiles\loop\.ai-loop\audits\phase-025-audit.md

The audit result must contain exactly one decision line:

    Decision: ACCEPTED

or:

    Decision: REWORK

or:

    Decision: BLOCKED

# Codex Audit Input: phase-011

## Project Root

    E:\codexfiles\loop

## Required Evidence Files

- status: E:\codexfiles\loop\.ai-loop\status.json
- base commit: E:\codexfiles\loop\.ai-loop\runs\phase-011\base_commit.txt
- status before: E:\codexfiles\loop\.ai-loop\runs\phase-011\status_before.txt
- phase metadata: E:\codexfiles\loop\.ai-loop\runs\phase-011\phase_meta.json
- phase requirements: E:\codexfiles\loop\.ai-loop\runs\phase-011\phase_requirements.json
- prompt: E:\codexfiles\loop\.ai-loop\runs\phase-011\prompt.md
- Worker report: E:\codexfiles\loop\.ai-loop\runs\phase-011\report.md
- status after: E:\codexfiles\loop\.ai-loop\runs\phase-011\status_after.txt
- diff: E:\codexfiles\loop\.ai-loop\runs\phase-011\diff.patch
- verify log: E:\codexfiles\loop\.ai-loop\runs\phase-011\verify.log
- changed files: E:\codexfiles\loop\.ai-loop\runs\phase-011\changed_files.txt
- changed business files: E:\codexfiles\loop\.ai-loop\runs\phase-011\changed_business_files.txt
- changed evidence files: E:\codexfiles\loop\.ai-loop\runs\phase-011\changed_evidence_files.txt
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

- .ai-loop/audits/phase-011-audit.md
- .ai-loop/audits/phase-011-audit-input.md
- .ai-loop/events/state-transitions.ndjson
- .ai-loop/evidence/artifact-index.md
- .ai-loop/evidence/artifact-manifest.json
- .ai-loop/evidence/command-log.md
- .ai-loop/evidence/evidence-ledger.md
- .ai-loop/evidence/provenance-map.md
- .ai-loop/evidence/test-log.md
- .ai-loop/memory/activeContext.md
- .ai-loop/memory/handoff-summary.md
- .ai-loop/memory/progress.md
- .ai-loop/runs/phase-011/accepted.txt
- .ai-loop/runs/phase-011/base_commit.txt
- .ai-loop/runs/phase-011/changed_business_files.txt
- .ai-loop/runs/phase-011/changed_evidence_files.txt
- .ai-loop/runs/phase-011/changed_files.txt
- .ai-loop/runs/phase-011/diff.patch
- .ai-loop/runs/phase-011/phase_meta.json
- .ai-loop/runs/phase-011/phase_requirements.json
- .ai-loop/runs/phase-011/prompt.md
- .ai-loop/runs/phase-011/report.md
- .ai-loop/runs/phase-011/status_after.txt
- .ai-loop/runs/phase-011/status_before.txt
- .ai-loop/runs/phase-011/verify.log
- .ai-loop/status.json
- loop-standard/README.md
- loop-standard/scripts/Test-CollectLedgerIdempotence.ps1
- loop-standard/scripts/Test-LoopStandard.ps1
- loop-standard/scripts/Test-MigrateLoop.ps1
- loop-standard/scripts/Test-Phase011.ps1
- loop-standard/scripts/Test-PhaseDecisions.ps1
- loop-standard/scripts/Test-PluginInstall.ps1
- loop-standard/scripts/Test-ReworkScaffold.ps1
- loop-standard/scripts/Test-SchemaVersioning.ps1
- loop-standard/scripts/Test-SkillArtifactManifest.ps1
- loop-standard/scripts/Test-StateTransitions.ps1
- loop-standard/scripts/Test-TempIsolation.ps1
- loop-standard/scripts/test-temp-root.ps1
- loop-standard/scripts/Test-ValidateLoopFailures.ps1
- README.md
- README_EN.md

## Changed Business Files

- loop-standard/README.md
- loop-standard/scripts/Test-CollectLedgerIdempotence.ps1
- loop-standard/scripts/Test-LoopStandard.ps1
- loop-standard/scripts/Test-MigrateLoop.ps1
- loop-standard/scripts/Test-Phase011.ps1
- loop-standard/scripts/Test-PhaseDecisions.ps1
- loop-standard/scripts/Test-PluginInstall.ps1
- loop-standard/scripts/Test-ReworkScaffold.ps1
- loop-standard/scripts/Test-SchemaVersioning.ps1
- loop-standard/scripts/Test-SkillArtifactManifest.ps1
- loop-standard/scripts/Test-StateTransitions.ps1
- loop-standard/scripts/Test-TempIsolation.ps1
- loop-standard/scripts/test-temp-root.ps1
- loop-standard/scripts/Test-ValidateLoopFailures.ps1
- README.md
- README_EN.md

## Changed Evidence Files

- .ai-loop/audits/phase-011-audit.md
- .ai-loop/audits/phase-011-audit-input.md
- .ai-loop/events/state-transitions.ndjson
- .ai-loop/evidence/artifact-index.md
- .ai-loop/evidence/artifact-manifest.json
- .ai-loop/evidence/command-log.md
- .ai-loop/evidence/evidence-ledger.md
- .ai-loop/evidence/provenance-map.md
- .ai-loop/evidence/test-log.md
- .ai-loop/memory/activeContext.md
- .ai-loop/memory/handoff-summary.md
- .ai-loop/memory/progress.md
- .ai-loop/runs/phase-011/accepted.txt
- .ai-loop/runs/phase-011/base_commit.txt
- .ai-loop/runs/phase-011/changed_business_files.txt
- .ai-loop/runs/phase-011/changed_evidence_files.txt
- .ai-loop/runs/phase-011/changed_files.txt
- .ai-loop/runs/phase-011/diff.patch
- .ai-loop/runs/phase-011/phase_meta.json
- .ai-loop/runs/phase-011/phase_requirements.json
- .ai-loop/runs/phase-011/prompt.md
- .ai-loop/runs/phase-011/report.md
- .ai-loop/runs/phase-011/status_after.txt
- .ai-loop/runs/phase-011/status_before.txt
- .ai-loop/runs/phase-011/verify.log
- .ai-loop/status.json

## Artifact Integrity Summary

| Path | Manifest Status | SHA256 | Size | Check |
| --- | --- | --- | --- | --- |
| .ai-loop/runs/phase-011/prompt.md | recorded | 9DF719FDDC6A | 1267 | OK |
| .ai-loop/runs/phase-011/report.md | recorded | 3E5A19B1AD09 | 1289 | OK |
| .ai-loop/runs/phase-011/status_after.txt | recorded | 3E032F265815 | 1251 | OK |
| .ai-loop/runs/phase-011/diff.patch | recorded | 62A4930B5DFE | 303159 | OK |
| .ai-loop/runs/phase-011/verify.log | recorded | CB848780A067 | 5415 | OK |
| .ai-loop/runs/phase-011/changed_files.txt | recorded | 31C2FD09E678 | 1678 | OK |
| .ai-loop/runs/phase-011/changed_business_files.txt | recorded | 9394A19E4253 | 675 | OK |
| .ai-loop/runs/phase-011/changed_evidence_files.txt | recorded | E1A96203D381 | 1008 | OK |
| .ai-loop/runs/phase-011/phase_requirements.json | recorded | DF2F2073F3BA | 986 | OK |

## Missing Or Invalid Evidence

None

## Phase Gate Validation

`	ext
Phase gate validation: OK
Project root: E:\codexfiles\loop
Phase: phase-011
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

    E:\codexfiles\loop\.ai-loop\audits\phase-011-audit.md

The audit result must contain exactly one decision line:

    Decision: ACCEPTED

or:

    Decision: REWORK

or:

    Decision: BLOCKED

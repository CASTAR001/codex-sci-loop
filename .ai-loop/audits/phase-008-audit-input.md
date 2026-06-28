# Codex Audit Input: phase-008

## Project Root

    E:\codexfiles\loop

## Required Evidence Files

- status: E:\codexfiles\loop\.ai-loop\status.json
- base commit: E:\codexfiles\loop\.ai-loop\runs\phase-008\base_commit.txt
- status before: E:\codexfiles\loop\.ai-loop\runs\phase-008\status_before.txt
- phase metadata: E:\codexfiles\loop\.ai-loop\runs\phase-008\phase_meta.json
- phase requirements: E:\codexfiles\loop\.ai-loop\runs\phase-008\phase_requirements.json
- prompt: E:\codexfiles\loop\.ai-loop\runs\phase-008\prompt.md
- Worker report: E:\codexfiles\loop\.ai-loop\runs\phase-008\report.md
- status after: E:\codexfiles\loop\.ai-loop\runs\phase-008\status_after.txt
- diff: E:\codexfiles\loop\.ai-loop\runs\phase-008\diff.patch
- verify log: E:\codexfiles\loop\.ai-loop\runs\phase-008\verify.log
- changed files: E:\codexfiles\loop\.ai-loop\runs\phase-008\changed_files.txt
- changed business files: E:\codexfiles\loop\.ai-loop\runs\phase-008\changed_business_files.txt
- changed evidence files: E:\codexfiles\loop\.ai-loop\runs\phase-008\changed_evidence_files.txt
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

- .ai-loop/audits/phase-008-audit.md
- .ai-loop/audits/phase-008-audit-input.md
- .ai-loop/events/event-schema.md
- .ai-loop/events/state-transitions.ndjson
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
- .ai-loop/runs/phase-008/accepted.txt
- .ai-loop/runs/phase-008/base_commit.txt
- .ai-loop/runs/phase-008/changed_business_files.txt
- .ai-loop/runs/phase-008/changed_evidence_files.txt
- .ai-loop/runs/phase-008/changed_files.txt
- .ai-loop/runs/phase-008/diff.patch
- .ai-loop/runs/phase-008/phase_meta.json
- .ai-loop/runs/phase-008/phase_requirements.json
- .ai-loop/runs/phase-008/prompt.md
- .ai-loop/runs/phase-008/report.md
- .ai-loop/runs/phase-008/status_after.txt
- .ai-loop/runs/phase-008/status_before.txt
- .ai-loop/runs/phase-008/verify.log
- .ai-loop/schema/schema-version.json
- .ai-loop/status.json
- loop-standard/.ai-loop/events/state-transitions.ndjson
- loop-standard/.ai-loop/loop.config.json
- loop-standard/.ai-loop/schema/schema-version.json
- loop-standard/README.md
- loop-standard/scripts/accept-phase.ps1
- loop-standard/scripts/collect-evidence.ps1
- loop-standard/scripts/decide-phase.ps1
- loop-standard/scripts/prepare-audit-pack.ps1
- loop-standard/scripts/record-state-transition.ps1
- loop-standard/scripts/start-phase.ps1
- loop-standard/scripts/Test-LoopStandard.ps1
- loop-standard/scripts/Test-MigrateLoop.ps1
- loop-standard/scripts/Test-Phase008.ps1
- loop-standard/scripts/Test-SchemaVersioning.ps1
- loop-standard/scripts/Test-StateTransitions.ps1
- loop-standard/scripts/validate-loop.ps1
- loop-standard/templates/.ai-loop/events/event-schema.md
- loop-standard/templates/.ai-loop/events/state-transitions.ndjson
- loop-standard/templates/.ai-loop/loop.config.json
- loop-standard/templates/.ai-loop/schema/schema-version.json
- README.md
- README_EN.md

## Changed Business Files

- loop-standard/.ai-loop/events/state-transitions.ndjson
- loop-standard/.ai-loop/loop.config.json
- loop-standard/.ai-loop/schema/schema-version.json
- loop-standard/README.md
- loop-standard/scripts/accept-phase.ps1
- loop-standard/scripts/collect-evidence.ps1
- loop-standard/scripts/decide-phase.ps1
- loop-standard/scripts/prepare-audit-pack.ps1
- loop-standard/scripts/record-state-transition.ps1
- loop-standard/scripts/start-phase.ps1
- loop-standard/scripts/Test-LoopStandard.ps1
- loop-standard/scripts/Test-MigrateLoop.ps1
- loop-standard/scripts/Test-Phase008.ps1
- loop-standard/scripts/Test-SchemaVersioning.ps1
- loop-standard/scripts/Test-StateTransitions.ps1
- loop-standard/scripts/validate-loop.ps1
- loop-standard/templates/.ai-loop/events/event-schema.md
- loop-standard/templates/.ai-loop/events/state-transitions.ndjson
- loop-standard/templates/.ai-loop/loop.config.json
- loop-standard/templates/.ai-loop/schema/schema-version.json
- README.md
- README_EN.md

## Changed Evidence Files

- .ai-loop/audits/phase-008-audit.md
- .ai-loop/audits/phase-008-audit-input.md
- .ai-loop/events/event-schema.md
- .ai-loop/events/state-transitions.ndjson
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
- .ai-loop/runs/phase-008/accepted.txt
- .ai-loop/runs/phase-008/base_commit.txt
- .ai-loop/runs/phase-008/changed_business_files.txt
- .ai-loop/runs/phase-008/changed_evidence_files.txt
- .ai-loop/runs/phase-008/changed_files.txt
- .ai-loop/runs/phase-008/diff.patch
- .ai-loop/runs/phase-008/phase_meta.json
- .ai-loop/runs/phase-008/phase_requirements.json
- .ai-loop/runs/phase-008/prompt.md
- .ai-loop/runs/phase-008/report.md
- .ai-loop/runs/phase-008/status_after.txt
- .ai-loop/runs/phase-008/status_before.txt
- .ai-loop/runs/phase-008/verify.log
- .ai-loop/schema/schema-version.json
- .ai-loop/status.json

## Artifact Integrity Summary

| Path | Manifest Status | SHA256 | Size | Check |
| --- | --- | --- | --- | --- |
| .ai-loop/runs/phase-008/prompt.md | recorded | 5F0889E6CEE6 | 1285 | OK |
| .ai-loop/runs/phase-008/report.md | recorded | 2AEB136E01F9 | 954 | OK |
| .ai-loop/runs/phase-008/status_after.txt | recorded | 429319F06519 | 1643 | OK |
| .ai-loop/runs/phase-008/diff.patch | recorded | DE5473C7AF00 | 228247 | OK |
| .ai-loop/runs/phase-008/verify.log | recorded | A21C2AB355DD | 3438 | OK |
| .ai-loop/runs/phase-008/changed_files.txt | recorded | 1448D9703A62 | 2067 | OK |
| .ai-loop/runs/phase-008/changed_business_files.txt | recorded | 848B3D52F017 | 967 | OK |
| .ai-loop/runs/phase-008/changed_evidence_files.txt | recorded | C8FBCB8E2794 | 1105 | OK |
| .ai-loop/runs/phase-008/phase_requirements.json | recorded | 3E5D4AA2E232 | 986 | OK |

## Missing Or Invalid Evidence

None

## Phase Gate Validation

`	ext
Phase gate validation: OK
Project root: E:\codexfiles\loop
Phase: phase-008
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

    E:\codexfiles\loop\.ai-loop\audits\phase-008-audit.md

The audit result must contain exactly one decision line:

    Decision: ACCEPTED

or:

    Decision: REWORK

or:

    Decision: BLOCKED

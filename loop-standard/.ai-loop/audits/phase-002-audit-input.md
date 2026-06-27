# Codex Audit Input: phase-002

## Project Root

    C:\Users\CodexSandboxOffline\.codex\.sandbox\cwd\1d0c8a579998ff1f\loop-standard

## Required Evidence Files

- status: C:\Users\CodexSandboxOffline\.codex\.sandbox\cwd\1d0c8a579998ff1f\loop-standard\.ai-loop\status.json
- base commit: C:\Users\CodexSandboxOffline\.codex\.sandbox\cwd\1d0c8a579998ff1f\loop-standard\.ai-loop\runs\phase-002\base_commit.txt
- status before: C:\Users\CodexSandboxOffline\.codex\.sandbox\cwd\1d0c8a579998ff1f\loop-standard\.ai-loop\runs\phase-002\status_before.txt
- phase metadata: C:\Users\CodexSandboxOffline\.codex\.sandbox\cwd\1d0c8a579998ff1f\loop-standard\.ai-loop\runs\phase-002\phase_meta.json
- phase requirements: C:\Users\CodexSandboxOffline\.codex\.sandbox\cwd\1d0c8a579998ff1f\loop-standard\.ai-loop\runs\phase-002\phase_requirements.json
- prompt: C:\Users\CodexSandboxOffline\.codex\.sandbox\cwd\1d0c8a579998ff1f\loop-standard\.ai-loop\runs\phase-002\prompt.md
- Worker report: C:\Users\CodexSandboxOffline\.codex\.sandbox\cwd\1d0c8a579998ff1f\loop-standard\.ai-loop\runs\phase-002\report.md
- status after: C:\Users\CodexSandboxOffline\.codex\.sandbox\cwd\1d0c8a579998ff1f\loop-standard\.ai-loop\runs\phase-002\status_after.txt
- diff: C:\Users\CodexSandboxOffline\.codex\.sandbox\cwd\1d0c8a579998ff1f\loop-standard\.ai-loop\runs\phase-002\diff.patch
- verify log: C:\Users\CodexSandboxOffline\.codex\.sandbox\cwd\1d0c8a579998ff1f\loop-standard\.ai-loop\runs\phase-002\verify.log
- changed files: C:\Users\CodexSandboxOffline\.codex\.sandbox\cwd\1d0c8a579998ff1f\loop-standard\.ai-loop\runs\phase-002\changed_files.txt
- changed business files: C:\Users\CodexSandboxOffline\.codex\.sandbox\cwd\1d0c8a579998ff1f\loop-standard\.ai-loop\runs\phase-002\changed_business_files.txt
- changed evidence files: C:\Users\CodexSandboxOffline\.codex\.sandbox\cwd\1d0c8a579998ff1f\loop-standard\.ai-loop\runs\phase-002\changed_evidence_files.txt
- evidence ledger: C:\Users\CodexSandboxOffline\.codex\.sandbox\cwd\1d0c8a579998ff1f\loop-standard\.ai-loop\evidence\evidence-ledger.md
- artifact manifest: C:\Users\CodexSandboxOffline\.codex\.sandbox\cwd\1d0c8a579998ff1f\loop-standard\.ai-loop\evidence\artifact-manifest.json
- artifact index: C:\Users\CodexSandboxOffline\.codex\.sandbox\cwd\1d0c8a579998ff1f\loop-standard\.ai-loop\evidence\artifact-index.md
- command log: C:\Users\CodexSandboxOffline\.codex\.sandbox\cwd\1d0c8a579998ff1f\loop-standard\.ai-loop\evidence\command-log.md
- test log: C:\Users\CodexSandboxOffline\.codex\.sandbox\cwd\1d0c8a579998ff1f\loop-standard\.ai-loop\evidence\test-log.md
- provenance map: C:\Users\CodexSandboxOffline\.codex\.sandbox\cwd\1d0c8a579998ff1f\loop-standard\.ai-loop\evidence\provenance-map.md
- skill trigger matrix: C:\Users\CodexSandboxOffline\.codex\.sandbox\cwd\1d0c8a579998ff1f\loop-standard\.ai-loop\skills\skill-trigger-matrix.md
- skill usage ledger: C:\Users\CodexSandboxOffline\.codex\.sandbox\cwd\1d0c8a579998ff1f\loop-standard\.ai-loop\skills\skill-usage-ledger.md
- skill artifact map: C:\Users\CodexSandboxOffline\.codex\.sandbox\cwd\1d0c8a579998ff1f\loop-standard\.ai-loop\skills\skill-artifact-map.md

## Changed Or Relevant Source Files

- loop-standard/.ai-loop/evidence/artifact-index.md
- loop-standard/.ai-loop/evidence/evidence-ledger.md
- loop-standard/.ai-loop/status.json
- loop-standard/scripts/ai-loop.ps1
- loop-standard/scripts/Test-LoopStandard.ps1

## Changed Business Files

- loop-standard/.ai-loop/evidence/artifact-index.md
- loop-standard/.ai-loop/evidence/evidence-ledger.md
- loop-standard/.ai-loop/status.json
- loop-standard/scripts/ai-loop.ps1
- loop-standard/scripts/Test-LoopStandard.ps1

## Changed Evidence Files

- None recorded.

## Artifact Integrity Summary

| Path | Manifest Status | SHA256 | Size | Check |
| --- | --- | --- | --- | --- |
| .ai-loop/runs/phase-002/prompt.md | recorded | 589FF88C121C | 1301 | OK |
| .ai-loop/runs/phase-002/report.md | recorded | D111D3ABAF93 | 1017 | OK |
| .ai-loop/runs/phase-002/status_after.txt | recorded | FDD11C4D908A | 188 | OK |
| .ai-loop/runs/phase-002/diff.patch | recorded | 04770DB6A0AB | 7919 | OK |
| .ai-loop/runs/phase-002/verify.log | recorded | 1A065E2BF3D4 | 332 | OK |
| .ai-loop/runs/phase-002/changed_files.txt | recorded | 6D7BA295BB40 | 224 | OK |
| .ai-loop/runs/phase-002/changed_business_files.txt | recorded | 6D7BA295BB40 | 224 | OK |
| .ai-loop/runs/phase-002/changed_evidence_files.txt | recorded | F01A374E9C81 | 5 | OK |
| .ai-loop/runs/phase-002/phase_requirements.json | recorded | A4D3CA50DCD2 | 986 | OK |

## Missing Or Invalid Evidence

None

## Phase Gate Validation

`	ext
Phase gate validation: OK
Project root: C:\Users\CodexSandboxOffline\.codex\.sandbox\cwd\1d0c8a579998ff1f\loop-standard
Phase: phase-002
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

    C:\Users\CodexSandboxOffline\.codex\.sandbox\cwd\1d0c8a579998ff1f\loop-standard\.ai-loop\audits\phase-002-audit.md

The audit result must contain exactly one decision line:

    Decision: ACCEPTED

or:

    Decision: REWORK

or:

    Decision: BLOCKED

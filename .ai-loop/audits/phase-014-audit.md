# Codex Audit: phase-014

Decision: ACCEPTED

## Evidence Checked

- Worker report: `.ai-loop/runs/phase-014/report.md`
- Diff: `.ai-loop/runs/phase-014/diff.patch`
- Verification log: `.ai-loop/runs/phase-014/verify.log`
- Audit input: `.ai-loop/audits/phase-014-audit-input.md`
- Artifact manifest: `.ai-loop/evidence/artifact-manifest.json`
- Changed files: `.ai-loop/runs/phase-014/changed_files.txt`
- Key source files:
  - `loop-standard/scripts/start-phase.ps1`
  - `loop-standard/scripts/collect-evidence.ps1`
  - `loop-standard/scripts/prepare-audit-pack.ps1`
  - `loop-standard/scripts/ai-loop.ps1`
  - `loop-standard/scripts/Test-ExternalWorkerEvidence.ps1`
  - `loop-standard/scripts/Test-Phase014.ps1`

## Findings

- `start` now has an explicit `-RequireExternalWorkerEvidence` switch. Ordinary
  phases are unchanged, and external Worker evidence is required only when
  Supervisor declares it.
- `collect` records additional required evidence from `phase_requirements.json`
  into Markdown ledgers, artifact index, and the JSON artifact manifest.
- `audit-pack` now includes an External Worker Evidence Requirements section and
  preserves the Markdown code fence in the phase gate section.
- `Test-ExternalWorkerEvidence.ps1` proves missing preflight/invocation evidence
  blocks validation, and complete local evidence validates without calling any
  external Worker service.

## Verification

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-Phase014.ps1`

Result: passed.

`ai-loop validate -TargetStatus audit_ready`

Result: passed.

No external Worker service was invoked.

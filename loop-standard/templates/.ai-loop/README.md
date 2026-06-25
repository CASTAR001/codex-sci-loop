# .ai-loop Template

This directory is the project-local source of truth for the Supervisor-Worker
loop after it is copied into a target project. Do not rely on chat history for
phase status, evidence, decisions, or audit results.

## Roles

- Codex is Supervisor and owns phase planning, audit, and acceptance.
- A Worker Agent executes only the current phase prompt. The Worker may be Kimi
  Code, another external coding agent, or Codex running in Worker mode.

## Standard Layout

```text
.ai-loop/
  loop.config.json
  status.json
  runs/
    <phase-id>/
      base_commit.txt
      status_before.txt
      phase_meta.json
      phase_requirements.json
      prompt.md
      report.md
      status_after.txt
      diff.patch
      verify.log
      changed_files.txt
      changed_business_files.txt
      changed_evidence_files.txt
  audits/
    <phase-id>-audit-input.md
    <phase-id>-audit.md
  evidence/
    evidence-ledger.md
    artifact-manifest.json
    artifact-index.md
    command-log.md
    test-log.md
    provenance-map.md
  skills/
    skill-trigger-matrix.md
    skill-usage-ledger.md
    skill-artifact-map.md
    skill-source-map.md
  evolution/
    project-loop-evolution.md
```

Evidence uses a dual-track model: Markdown ledgers remain the human-readable
audit surface, while `artifact-manifest.json` records SHA256, file size, mtime,
phase, and path for gate validation.

Codex must not accept a phase unless required evidence exists, artifact
integrity matches the manifest, required skill artifacts are present or
explicitly overridden, and the audit checks the report, diff, verify log, status
files, phase requirements, ledgers, and relevant source files.

# Codex Loop Harness 1.0 Delivery Audit

This audit maps the 1.0 delivery objective to current repository evidence. It
is not a substitute for running `release-check`; it records what each release
claim depends on.

## Release Posture

- Status: `ready_with_warnings`.
- Latest accepted root phase: `phase-027`.
- Latest full release sign-off evidence: `ai-loop -Command release-check
  -ProjectRoot . -Json` executed `Test-Phase026.ps1` with `pass=3`, `warn=1`,
  `fail=0`, `skipped=0`.
- Expected warning: `PLUGIN-GLOBAL`, because real global Codex plugin discovery
  requires explicit user approval to modify real global Codex configuration.

## Requirement Evidence Map

| Requirement | Current Evidence | Status |
| --- | --- | --- |
| Local-first operation | `loop-standard/scripts/*.ps1`, `.ai-loop/`, docs non-goals, no service dependency in release notes | Passed |
| Markdown-first project control plane | `.ai-loop/memory/*.md`, `.ai-loop/evidence/*.md`, `.ai-loop/skills/*.md`, templates under `loop-standard/templates/.ai-loop/` | Passed |
| Git-trackable state | Root `.ai-loop/` phase evidence, audits, status, ledgers, and accepted commits through `phase-027` | Passed |
| Worker-agnostic loop | `preflight-worker.ps1`, `invoke-worker.ps1`, `EXTERNAL_WORKER_PROTOCOL.md`, Worker profile fields in phase requirements | Passed |
| Initialize arbitrary project folders | `init-loop.ps1`, readiness `KIT-INIT`, operator checklist initialization section | Passed |
| Start bounded phases | `start-phase.ps1`, `phase_requirements.json`, start idempotence tests | Passed |
| Link project-local skills | `link-skills.ps1`, `.ai-loop/skills/skill-source-map.md`, task-kind skill trigger fixtures | Passed |
| External Worker preflight and invocation evidence | `worker-preflight`, `invoke-worker`, `Test-ExternalWorkerEvidence.ps1`; no external service call is made without explicit approval | Passed |
| Hash-backed evidence collection | `collect-evidence.ps1`, `.ai-loop/evidence/artifact-manifest.json`, artifact integrity summaries | Passed |
| State-machine gates | `validate-phase-gates.ps1`, `validate-loop.ps1`, accepted phase audits and status transitions | Passed |
| Audit package generation | `prepare-audit-pack.ps1`, `.ai-loop/audits/phase-027-audit-input.md` | Passed |
| Interrupted-state recovery | `ai-loop resume`, `resume -Json`, transition diagnostics, recovery reason/cause tests | Passed |
| Durable REWORK and BLOCKED handling | `decide-phase.ps1`, structured findings extraction, bounded rework scaffold tests | Passed |
| Project-local memory, constraints, and evolution | `.ai-loop/memory/`, `.ai-loop/evolution/project-loop-evolution.md`, templates and readiness checks | Passed |
| Non-destructive migration | `migrate-loop.ps1`, dry-run JSON, semantic migration transforms and tests | Passed |
| Safe temp fixture cleanup | `prune-temp-fixtures.ps1`, `prune-temp -Json`, retention/idempotence tests | Passed |
| Release readiness reporting | `check-readiness.ps1`, `release-check.ps1`, dynamic latest matrix discovery in `phase-026` | Passed |
| Complete non-global PowerShell matrix | `Test-Phase026.ps1` through full `release-check` without `-SkipMatrix` | Passed |
| Real global Codex plugin discovery | Repo-local plugin smoke tests pass; live global config mutation is not performed without explicit user approval | Warning |

## Acceptance Boundary

The harness is deliverable as a non-global, local-first 1.0 package with one
explicit warning: live global Codex plugin discovery is approval-gated. Do not
claim `PLUGIN-GLOBAL` as passed until a user-approved test modifies or inspects
real global Codex plugin configuration and records evidence.

## Operator Verification Commands

Quick status:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\ai-loop.ps1 -Command release-check -ProjectRoot . -Json -SkipMatrix
```

Full non-global sign-off:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\ai-loop.ps1 -Command release-check -ProjectRoot . -Json
```

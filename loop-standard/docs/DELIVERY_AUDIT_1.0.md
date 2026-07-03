# Codex Loop Harness 1.0 Delivery Audit

This audit maps the 1.0 delivery objective to current repository evidence. It
is not a substitute for running `release-check`; it records what each release
claim depends on.

## Release Posture

- Status: `ready`.
- Latest accepted root phase: `phase-028`.
- Latest full release sign-off evidence: `ai-loop -Command release-check
  -ProjectRoot . -Json` executed `Test-Phase028.ps1` with `pass=3`, `warn=0`,
  `fail=0`, `skipped=0`.
- `PLUGIN-GLOBAL` has approved live evidence in
  `.ai-loop/evidence/global-plugin-discovery.json`. Future live global
  configuration changes still require explicit user approval.

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
| Release readiness reporting | `check-readiness.ps1`, `release-check.ps1`, dynamic latest matrix discovery, evidence-gated `PLUGIN-GLOBAL` | Passed |
| Complete PowerShell matrix | `Test-Phase028.ps1` through full `release-check` without `-SkipMatrix` | Passed |
| Real global Codex plugin discovery | `.ai-loop/evidence/global-plugin-discovery.json`, `phase-028` Codex CLI marketplace/list/add JSON, manifest and marketplace SHA-256 hashes | Passed |

## Acceptance Boundary

The harness is deliverable as a local-first 1.0 package with live global plugin
discovery evidence. Do not repeat, mutate, or repair real global Codex plugin
configuration without explicit user approval. If
`.ai-loop/evidence/global-plugin-discovery.json` is missing, malformed, or
mismatched, readiness must not claim `PLUGIN-GLOBAL` as passed.

Phase-028 also fixed a live installer compatibility issue: Windows PowerShell
`Set-Content -Encoding utf8` emitted a UTF-8 BOM in `marketplace.json`, which
Codex CLI rejected. `install-global.ps1` now writes marketplace JSON with
`System.Text.UTF8Encoding(false)`.

## Operator Verification Commands

Quick status:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\ai-loop.ps1 -Command release-check -ProjectRoot . -Json -SkipMatrix
```

Full non-global sign-off:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\ai-loop.ps1 -Command release-check -ProjectRoot . -Json
```

# Codex Loop Harness 1.0 Release Notes

## Status

`1.0` is a local-first, Markdown-first, git-trackable Supervisor-Worker loop
harness for Windows PowerShell projects. The current readiness command reports:

```text
ready
```

Real global Codex plugin discovery was live-tested once with explicit user
approval. The evidence is recorded in
`.ai-loop/evidence/global-plugin-discovery.json` and includes Codex CLI
marketplace/list/add outputs plus SHA-256 hashes for the registered marketplace
and plugin manifest.

## What 1.0 Delivers

- Reusable `.ai-loop/` project control-plane templates.
- Short root `AGENTS.md` bootstrap that delegates detailed rules to `.ai-loop/`.
- Unified `ai-loop.ps1` command surface.
- Phase lifecycle: `init`, `start`, `collect`, `validate`, `audit-pack`,
  `accept`, `decide`, `scaffold-rework`, `resume`.
- Hash-backed artifact evidence manifest and human-readable evidence ledgers.
- Required evidence gates for prompt, report, diff, verification log, status,
  changed files, and phase requirements.
- Skill trigger matrix, skill usage ledger, skill artifact tracking, and skill
  source map.
- Worker-agnostic external Worker preflight and invocation records.
- Durable `REWORK` and `BLOCKED` decisions with structured findings.
- Bounded rework phase scaffolding from accepted audit findings.
- Append-only state transition log and recovery diagnostics.
- Machine-readable JSON for `resume`, `migrate -DryRun`, `prune-temp`,
  `readiness`, and `release-check`.
- Compact `release-check` command for 1.0 release validation.
- Dynamic latest-matrix discovery for release sign-off: when `-MatrixScript` is
  omitted, `release-check` runs the highest numbered `Test-PhaseNNN.ps1`.
- Evidence-gated global Codex plugin discovery: `PLUGIN-GLOBAL` passes only
  when approved live-discovery evidence exists.
- Non-destructive migration with dry-run planning and semantic transforms for
  older `.ai-loop` projects.
- Project-local evolution file that does not override governance until promoted.
- Repo-local Codex plugin scaffold and temporary install/discovery smoke test.

## Verified Matrix

The current non-global verification matrix is selected by `release-check`.
When `-MatrixScript` is omitted, it discovers the highest numbered
`Test-PhaseNNN.ps1` under `loop-standard/scripts/` and executes it. The latest
full release sign-off run executed `Test-Phase028.ps1` and reported
`pass=3`, `warn=0`, `fail=0`, `skipped=0`.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\ai-loop.ps1 -Command release-check -ProjectRoot .
```

It covers:

- Standard kit structure and required files.
- Plugin install/discovery smoke test under a temporary install root.
- Negative loop-wide validation fixtures.
- Evidence ledger idempotence.
- Schema versioning and migration.
- Durable `REWORK` / `BLOCKED` decisions.
- State transition logging.
- Bounded rework scaffolding.
- Skill artifact hashing and tamper detection.
- Per-run temp fixture isolation.
- Start-phase idempotence.
- Recovery diagnostics and `resume -Json`.
- External Worker evidence requirements without invoking an external service.
- Structured audit finding extraction.
- Safe temp fixture pruning with text and JSON output.
- Migration dry-run text and JSON output.
- Semantic migration transforms for legacy evidence fields, current phase
  reconstruction, and terminal success status naming.
- Task-kind skill trigger fixtures for full-stack, physics research,
  data-analysis, research-writing, research profiles, and manual skill
  overrides.
- Release-check text and JSON output that aggregates readiness, loop-wide
  validation, and the dynamically discovered verification matrix.
- Readiness text and JSON output.
- Global plugin discovery evidence schema and readiness gate behavior.

## Operator Entry Points

Run readiness before claiming delivery:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\ai-loop.ps1 -Command readiness -ProjectRoot .
```

Use JSON when automation needs the result:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\ai-loop.ps1 -Command readiness -ProjectRoot . -Json
```

Initialize a target project:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 -Command init -ProjectRoot E:\some-project -CreateAgentsBootstrap
```

Link the full research skill profile when needed:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 -Command link-skills -ProjectRoot E:\some-project -Profile full-research
```

## Non-Goals

- No cloud service dependency.
- No database dependency.
- No Mem0, Zep, Graphiti, or projectmem runtime dependency.
- No real global Codex configuration mutation without explicit user approval.
- No external Worker invocation unless the Supervisor records preflight and the
  user has explicitly allowed external service use for that phase.

## Global Plugin Evidence

`PLUGIN-GLOBAL` is evidence-gated. Without
`.ai-loop/evidence/global-plugin-discovery.json`, readiness reports a warning.
With malformed or mismatched evidence, readiness fails. With approved live
Codex CLI evidence for `codex-loop-harness@loop-harness-local`, readiness
passes.

The phase-028 live validation installed the harness through Codex CLI plugin
discovery. The CLI registered root was `E:\.codex\loop-harness`, and the
rollback command is recorded in the evidence JSON.

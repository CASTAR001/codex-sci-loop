# Codex Loop Harness 1.0 Release Notes

## Status

`1.0` is a local-first, Markdown-first, git-trackable Supervisor-Worker loop
harness for Windows PowerShell projects. The current readiness command reports:

```text
ready_with_warnings
```

The remaining warning is intentional: real global Codex plugin discovery has
not been live-tested because it requires explicit user approval to modify global
Codex configuration. Repo-local plugin install/discovery smoke tests are in
place.

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
- Non-destructive migration with dry-run planning and semantic transforms for
  older `.ai-loop` projects.
- Project-local evolution file that does not override governance until promoted.
- Repo-local Codex plugin scaffold and temporary install/discovery smoke test.

## Verified Matrix

The current non-global verification matrix is aggregated by:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-Phase020.ps1
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
  validation, and the verification matrix.
- Readiness text and JSON output.

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

## Known Warning

`PLUGIN-GLOBAL` remains a readiness warning until a user-approved live global
Codex plugin install/discovery test is performed. This warning is expected under
the current safety policy and should not be bypassed silently.

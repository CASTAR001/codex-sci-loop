# Goal Handoff - 2026-06-30

## Current State

- Repository: `E:\codexfiles\loop`
- Goal status from Codex goal tracker: `paused`
- Git working tree at handoff check: clean
- Latest commit: `8cff940 Add release check command`
- Current accepted phase: `phase-024`
- Current phase status in `.ai-loop/status.json`: `accepted`

Lightweight verification run during handoff:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\validate-loop.ps1 -ProjectRoot .
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\ai-loop.ps1 -Command release-check -ProjectRoot . -Json -SkipMatrix
```

Observed result:

- `validate-loop`: `OK`
- `release-check -SkipMatrix`: `ready_with_warnings`
- `release-check` summary: `pass=2`, `warn=1`, `fail=0`, `skipped=1`
- Expected warning: `PLUGIN-GLOBAL`, because real global Codex plugin discovery
  has not been user-approved.

## What Is Built

The repository now contains a local-first, markdown-first, git-trackable loop
harness with:

- reusable `loop-standard/` kit;
- root `.ai-loop/` memory, constraints, evidence, gates, events, roles,
  workers, prompts, schema, and project-local evolution files;
- short root `AGENTS.md` bootstrap;
- unified `loop-standard/scripts/ai-loop.ps1` entrypoint;
- init, migrate, start, collect, validate, audit-pack, accept, decide,
  scaffold-rework, resume, link-skills, worker-preflight, invoke-worker,
  prune-temp, readiness, and release-check commands;
- hash-backed artifact manifest and human-readable evidence ledgers;
- required skill triggers and skill artifact gates;
- worker-agnostic external Worker preflight and invocation evidence;
- durable `ACCEPTED`, `REWORK`, and `BLOCKED` state handling;
- structured audit finding extraction and bounded rework scaffolding;
- append-only state transition logging;
- machine-readable JSON for resume, migrate dry-run, prune-temp, readiness,
  and release-check;
- non-destructive migration and semantic migration transforms;
- task-kind skill trigger fixtures for full-stack and research workflows;
- repo-local Codex plugin scaffold and temporary install/discovery smoke tests.

## Recent Phase Trail

- `phase-020`: readiness command.
- `phase-021`: 1.0 release notes and operator checklist.
- `phase-022`: semantic migration transform registry.
- `phase-023`: task-kind skill trigger fixtures.
- `phase-024`: compact `release-check` command.

Recent commits:

```text
8cff940 Add release check command
5f0b0a9 Add task kind skill trigger fixtures
731613a Add semantic migration transforms
e6ce5fe Add 1.0 release docs and checklist
c266821 Add 1.0 readiness audit command
```

## Recommended New-Chat Bootstrap

In the next conversation, read these first:

1. `AGENTS.md`
2. `.ai-loop/README.md`
3. `.ai-loop/memory/activeContext.md`
4. `.ai-loop/memory/constraint-ledger.md`
5. `.ai-loop/gates/pre-action-check.md`
6. `.ai-loop/memory/handoff-summary.md`
7. `.ai-loop/reports/goal-handoff-2026-06-30.md`

Then run a lightweight status check:

```powershell
git status --short
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\ai-loop.ps1 -Command release-check -ProjectRoot . -Json -SkipMatrix
```

Run the full matrix only when starting or accepting a substantial harness phase:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-Phase024.ps1
```

## Best Next Work

Best non-global next phase:

```text
phase-025: richer recovery explanations from state-transitions.ndjson
```

Suggested objective:

```text
Enhance ai-loop resume so it explains why a phase is RESUMABLE/BLOCKED, lists
the specific transition/status/evidence causes, and emits a compact
machine-readable recovery_reason/recovery_causes array for automation.
```

Why this is next:

- It directly advances safe recovery from interrupted state.
- It does not require real global Codex configuration changes.
- It does not require external Worker invocation.
- It can be tested with temporary fixture projects.

## Hard Boundaries To Preserve

- Do not modify real global Codex configuration without explicit user approval.
- Do not call external Worker services without explicit approval and preflight
  evidence.
- Do not upgrade long-term memory without stopping for user confirmation.
- Do not use this harness repo's `.ai-loop/evolution/` for dogfood-specific
  evolution content; target projects own their own evolution files.
- Do not accept prose alone. Inspect diff, verify log, status, evidence,
  artifact manifest, and relevant source.

## Token And Audit Overhead Estimate

The current process is robust but expensive.

Observed order of magnitude:

- Lightweight status check using `release-check -SkipMatrix` plus
  `validate-loop`: low token cost when only compact summaries are read.
- A full self-loop phase that runs the aggregate matrix, collects evidence,
  reads audit inputs, updates memory, re-collects, validates, accepts, and
  commits can consume hundreds of thousands of goal tokens. Recent phase-level
  deltas were roughly in the `200k-350k` token range, mostly from long command
  outputs, repeated verification matrices, audit-pack content, and evidence
  inspection.
- Full matrix runtime is often around `8-12` minutes per collect or direct
  matrix run on this machine.

Recommended token controls:

- Use `release-check -SkipMatrix` for routine status checks.
- Do not run the full matrix just to inspect status.
- Batch small documentation/test registration changes into one phase.
- Inspect targeted snippets with `Select-String` and `Get-Content -Tail`
  instead of full logs, full diffs, or full audit packs.
- Keep audit text concise and cite artifact paths instead of copying large
  evidence bodies.
- Consider a future `collect -SummaryOnly` or `audit-pack -SummaryOnly` mode if
  token pressure remains high.

The tradeoff is deliberate: strong evidence gates reduce hallucination and
state drift, but the current full self-loop protocol is overkill for tiny
maintenance edits. New chats should use lightweight checks until a bounded
phase is ready.

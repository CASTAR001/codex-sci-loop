# Loop Harness

This repository is building a reusable Supervisor-Worker loop harness for AI
coding work. The goal is to make a workflow that can be copied or installed into
any project folder, then used by Codex, Kimi Code, or another worker agent
without relying on chat history as the source of truth.

The harness is local-first, markdown-first, git-trackable, and Windows
PowerShell-first.

Humans should start with `README.md` or this English companion. Agents should
bootstrap from `AGENTS.md` and then follow `.ai-loop/`; long governance rules do
not belong in the root bootstrap.

## What This Repository Contains

### `loop-standard/`

The reusable kit. This is the part intended to be applied to other projects.

Important pieces:

- `templates/.ai-loop/`: template control plane copied into target projects.
- `scripts/init-loop.ps1`: initializes `.ai-loop/` in a project.
- `scripts/start-phase.ps1`: starts a phase and generates phase requirements.
- `scripts/collect-evidence.ps1`: collects status, diff, verify log, and file
  evidence after a worker acts.
- `scripts/prepare-audit-pack.ps1`: prepares the Codex audit input.
- `scripts/validate-phase-gates.ps1`: blocks phases with missing evidence,
  invalid state, missing skill artifacts, or broken skill links.
- `scripts/accept-phase.ps1`: accepts a phase only after audit and gate checks.
- `scripts/link-skills.ps1`: links shared skills into a project `.agents/skills/`.
- `scripts/ai-loop.ps1`: the recommended unified entrypoint.

Use `loop-standard/README.md` for lower-level script details.

### `.ai-loop/`

This repository's own loop control plane. It records project memory,
constraints, evidence, skill usage, phase gates, events, reports, and handoff
state.

This directory is also the model for what gets installed into other projects.
It is the durable source of truth. Do not rely on chat history for important
state.

Key subdirectories:

- `memory/`: project brief, active context, decisions, failures, progress,
  handoff summary.
- `roles/`: Supervisor, Worker, Auditor, Verifier, and Recovery contracts.
- `gates/`: pre-action checks, phase gates, stop rules.
- `evidence/`: evidence ledger, artifact index, command log, test log,
  provenance map.
- `skills/`: skill trigger matrix, usage ledger, artifact map, skill source map.
- `events/`: append-only event log in ndjson form.
- `prompts/`: reusable prompts for resume, pre-action checks, memory updates,
  and next-step decisions.
- `evolution/`: project-local loop improvement proposals that do not become
  governance until promoted.
- `reports/`: implementation and audit reports.

### `.agents/`

Runtime agent assets. This is where project-visible skills can be linked.

Boundary rule:

- `.ai-loop/` is durable project memory and governance.
- `.agents/` is runtime/tooling surface, such as linked skills.

For the current research workflow, skills are not copied into every project.
They are linked into `.agents/skills/` and recorded in
`.ai-loop/skills/skill-source-map.md`.

### `plugins/codex-loop-harness/`

The first Codex plugin scaffold for distributing and discovering this workflow.
It does not store project state. Project state remains in each project's
`.ai-loop/`.

Plugin skills currently included:

- `loop-supervisor`: how Codex should start and supervise loop phases.
- `loop-auditor`: how Codex should audit worker output.
- `loop-recovery`: how to resume from `.ai-loop/` after interruption.
- `research-loop-orchestrator`: how to select research skill profiles.

The plugin is a distribution and guidance layer. The scripts remain the stable
operating core.

### `pilot-project/`

A small fixture project used to test the loop flow. It is tracked by this
repository and is not a nested git repository.

## Current Operating Model

The harness now uses a two-layer model:

1. Script core: `loop-standard/scripts/ai-loop.ps1` is the recommended command.
2. Plugin distribution: `plugins/codex-loop-harness/` helps Codex discover and
   follow the workflow.

All project-specific state belongs in the target project's `.ai-loop/`.

## How To Use In Another Project

Replace `E:\some-project` with the target project path.

Initialize the loop:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 -Command init -ProjectRoot E:\some-project -CreateAgentsBootstrap
```

Link research skills when needed:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 -Command link-skills -ProjectRoot E:\some-project -Profile full-research
```

Start a normal full-stack phase:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 -Command start -ProjectRoot E:\some-project -PhaseId phase-001 -TaskKind fullstack -Title "Small fix" -Objective "Make one verifiable change" -VerifyCommand "npm test"
```

Start a physics or numerical research phase:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 -Command start -ProjectRoot E:\some-project -PhaseId phase-001 -TaskKind physics-research -Profile physics-sim -Title "Simulation check" -Objective "Make one evidence-backed simulation change"
```

After the worker finishes:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 -Command collect -ProjectRoot E:\some-project -PhaseId phase-001
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 -Command audit-pack -ProjectRoot E:\some-project -PhaseId phase-001
```

Before acceptance:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 -Command validate -ProjectRoot E:\some-project -PhaseId phase-001
```

Accept only after Codex writes an audit with `Decision: ACCEPTED`:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 -Command accept -ProjectRoot E:\some-project -PhaseId phase-001
```

## Research Skill Profiles

The first version assumes the shared skill library is:

```text
E:\codexfiles\test\.agents\skills
```

Profiles:

- `research-core`: research task tree, invariant contract, deterministic
  verification, skill compliance audit.
- `physics-sim`: research task tree, invariant contract, bounded experiment
  loop, deterministic verification, independent crosscheck, result provenance
  audit, skill compliance audit.
- `manuscript`: research task tree, deterministic verification, result
  provenance audit, manuscript consistency audit, skill compliance audit.
- `full-research`: all 8 research workflow skills.

The 8 research skills are linked into each project with Windows directory
junctions when possible. If linking fails, the source map records the failure
and gates can block required phases.

## Evidence Rule

Codex must not accept a phase from a worker report alone.

A valid phase must include evidence such as:

- prompt
- worker report
- git status before and after
- diff patch
- verification log
- changed files
- phase requirements
- evidence ledgers
- skill usage records
- required skill artifacts when triggers apply
- Codex audit result

If evidence is missing, verification fails, skill artifacts are missing, or a
required skill link is unavailable, the phase must be `BLOCKED` or `REWORK`
unless the Supervisor uses a recorded force override.

## What Has Been Verified

Recent checks passed:

- PowerShell parse check for scripts.
- `Test-LoopStandard.ps1 -AllowPilotProject`.
- `ai-loop.ps1 doctor`.
- Plugin wrapper `doctor`.
- Temporary project behavior:
  - `init` creates `.ai-loop/` and `.agents/skills/`.
  - `link-skills -Profile full-research` links all 8 skills.
  - full-stack phase can pass ordinary evidence gates.
  - physics-research phase blocks when required skill artifacts are missing.
  - force accept requires an override reason.
  - broken skill links block validation.

See `.ai-loop/reports/fixed-wrapper-plugin-report.md` for the latest detailed
report.

## Current Status

Implemented:

- reusable `loop-standard/` kit
- `.ai-loop/` memory and constraint system
- evidence ledgers
- skill trigger matrix and skill usage records
- phase gate automation
- project-local evolution file
- unified `ai-loop.ps1` wrapper
- skill linking and skill source map
- Codex plugin scaffold

Still planned:

- global install or PATH shim for `ai-loop.ps1`
- plugin installation validation
- stronger recovery automation
- broader state machine checks
- evidence ledger automation improvements
- skill trigger matrix expansion for full-stack and physics workflows

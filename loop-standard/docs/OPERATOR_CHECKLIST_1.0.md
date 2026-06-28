# Operator Checklist For Loop Harness 1.0

Use this checklist when applying the harness to a real project. It is
deliberately local-first and does not require global Codex configuration
changes.

## Before Installing Into A Project

- Confirm the target project is under the intended filesystem root.
- Confirm the project can be tracked by git or has an explicit reason not to be.
- Run the kit readiness command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 -Command readiness -ProjectRoot E:\codexfiles\loop
```

- Accept `PLUGIN-GLOBAL` as a warning only if real global Codex plugin discovery
  has not been user-approved.
- Do not run external Worker commands before `worker-preflight` is recorded.

## Initialize

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 -Command init -ProjectRoot E:\some-project -CreateAgentsBootstrap
```

Confirm:

- `.ai-loop/README.md` exists.
- `.ai-loop/status.json` exists and parses.
- `.ai-loop/evidence/artifact-manifest.json` exists and parses.
- `.ai-loop/evolution/project-loop-evolution.md` exists.
- Root `AGENTS.md` remains short and only bootstraps into `.ai-loop/`.

## Link Skills

For research-heavy projects:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 -Command link-skills -ProjectRoot E:\some-project -Profile full-research
```

Confirm:

- `.agents/skills/` exists.
- `.ai-loop/skills/skill-source-map.md` records each skill source.
- Required skills are available before starting correctness-sensitive phases.

## Start A Phase

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 -Command start -ProjectRoot E:\some-project -PhaseId phase-001 -TaskKind fullstack -Title "Small scoped change" -Objective "Make one verifiable change" -VerifyCommand "powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify.ps1"
```

Confirm:

- `.ai-loop/runs/phase-001/prompt.md` exists.
- `.ai-loop/runs/phase-001/phase_requirements.json` exists.
- `status.json` current phase is `phase-001`.
- Worker scope is bounded to the current phase.

## External Worker Use

Before invoking an external Worker:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 -Command worker-preflight -ProjectRoot E:\some-project -PhaseId phase-001 -WorkerProfile kimi-code -Yolo
```

Only invoke the Worker after preflight is safe or the user explicitly approves
external service use:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 -Command invoke-worker -ProjectRoot E:\some-project -PhaseId phase-001 -WorkerProfile kimi-code -AllowExternalService -Yolo
```

Confirm:

- External Worker evidence is required for phases started with
  `-RequireExternalWorkerEvidence`.
- Preflight and invocation artifacts are collected before audit.
- `-Yolo` is recorded but does not replace external-service approval.

## Collect And Audit

After Worker execution:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 -Command collect -ProjectRoot E:\some-project -PhaseId phase-001
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 -Command validate -ProjectRoot E:\some-project -PhaseId phase-001
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 -Command audit-pack -ProjectRoot E:\some-project -PhaseId phase-001
```

Auditor must inspect:

- Worker report.
- `diff.patch`.
- `verify.log`.
- `status_after.txt`.
- `changed_business_files.txt`.
- `artifact-manifest.json`.
- Relevant source files.

Accept only after writing an audit with:

```text
Decision: ACCEPTED
```

Use `decide -Decision REWORK` or `decide -Decision BLOCKED` when evidence is
missing, stale, out of scope, or unverifiable.

## Recovery

Human-readable:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 -Command resume -ProjectRoot E:\some-project
```

Machine-readable:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 -Command resume -ProjectRoot E:\some-project -Json
```

If recovery reports `BLOCKED`, do not continue the phase until the blocker is
resolved or a documented `REWORK` phase is scaffolded.

## Migration

Before upgrading an older project, inspect the migration plan:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File <install-root>\bin\ai-loop.ps1 `
  -Command migrate `
  -ProjectRoot <project> `
  -DryRun `
  -Json
```

Confirm:

- The plan lists only expected template, schema, JSON, and semantic transform
  actions.
- Any `semantic_transforms` entries are understood before applying migration.
- A real migration writes `.ai-loop/schema/migration-records/.../migration-record.json`.
- Project memory, evidence ledgers, and business files are preserved.

## Release Readiness

Before calling a project ready:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 -Command readiness -ProjectRoot E:\some-project -Json
```

Required:

- `summary.fail` is `0`.
- Warnings are understood and explicitly accepted.
- `validate-loop` passes.
- Latest phase is accepted, reworked, blocked with a reason, or intentionally
  paused with recovery notes.

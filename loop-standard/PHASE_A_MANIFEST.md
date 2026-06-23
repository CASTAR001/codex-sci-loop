# Phase A Manifest

Phase A initializes the reusable Supervisor-Worker Loop Standard Kit only. It
does not create or run `pilot-project/`.

## Created Directories

- `loop-standard/` - reusable standard kit root.
- `loop-standard/templates/` - canonical copyable templates.
- `loop-standard/.ai-loop/` - template state directory to copy into a project
  root.
- `loop-standard/.ai-loop/evidence/` - per-phase required evidence root.
- `loop-standard/.ai-loop/audits/` - per-phase audit package and audit result
  root.
- `loop-standard/.ai-loop/logs/` - optional durable logs.
- `loop-standard/.ai-loop/templates/` - reusable phase prompt, report,
  audit-input, audit, and phase-plan templates.
- `loop-standard/scripts/` - Windows PowerShell loop scripts.
- `loop-standard/prompts/` - Supervisor, Worker, and Audit prompts.
- `loop-standard/docs/` - operational documentation.

## Created Files And Purpose

- `README.md` - user-facing reuse guide and command sequence.
- `PHASE_A_MANIFEST.md` - durable record of Phase A outputs and checks.
- `PHASE_A_VERIFICATION.md` - durable Phase A verification result and command.
- `PHASE_B_PLAN.md` - file-based plan for the next phase without starting it.
- `templates/README.md` - template directory overview.
- `templates/.ai-loop/README.md` - canonical project-local loop contract.
- `templates/.ai-loop/loop.config.json` - canonical project-local loop config.
- `templates/.ai-loop/status.json` - canonical project-local durable status.
- `templates/.ai-loop/runs/README.md` - run directory contract.
- `templates/.ai-loop/audits/README.md` - audit file contract.
- `docs/README.md` - standard script flow and evidence gate documentation.
- `.ai-loop/README.md` - project-local loop contract.
- `.ai-loop/loop.config.json` - machine-readable roles, evidence requirements,
  audit inputs, decisions, and rules.
- `.ai-loop/status.json` - durable project loop status template.
- `.ai-loop/evidence/README.md` - evidence directory contract.
- `.ai-loop/audits/README.md` - audit directory contract.
- `.ai-loop/logs/README.md` - optional log directory note.
- `.ai-loop/templates/phase-plan.md` - phase planning template.
- `.ai-loop/templates/prompt.md` - Codex-generated Worker prompt template.
- `.ai-loop/templates/report.md` - Kimi Worker report template.
- `.ai-loop/templates/audit-input.md` - generated audit package input template.
- `.ai-loop/templates/audit.md` - Codex audit result template.
- `prompts/codex-supervisor.md` - Codex Supervisor operating prompt.
- `prompts/kimi-worker.md` - Kimi Worker operating prompt.
- `prompts/codex-audit.md` - Codex Audit operating prompt.
- `scripts/init-loop.ps1` - copy `templates/.ai-loop` into a target project;
  supports `.\init-loop.ps1 -ProjectRoot "E:\some-project"`.
- `scripts/start-phase.ps1` - create `.ai-loop/runs/<phase-id>/` and save
  `base_commit.txt`, `status_before.txt`, `phase_meta.json`, and `prompt.md`.
- `scripts/collect-evidence.ps1` - after Worker execution, save
  `status_after.txt`, `diff.patch`, `verify.log`, and `changed_files.txt`.
- `scripts/prepare-audit-pack.ps1` - generate
  `.ai-loop/audits/<phase-id>-audit-input.md` from report, diff, verify log,
  status, and changed file paths.
- `scripts/accept-phase.ps1` - after Codex writes `Decision: ACCEPTED`, mark
  the phase accepted and optionally commit with `-Commit`.
- `scripts/Initialize-AiLoop.ps1` - compatibility helper to copy `.ai-loop` template into a target
  project and initialize `status.json`.
- `scripts/Start-LoopPhase.ps1` - create a phase evidence directory, generate
  Kimi's current-phase prompt, and update `status.json`.
- `scripts/Collect-LoopEvidence.ps1` - collect `report.md`, `diff.patch`,
  `verify.log`, and `status.txt`.
- `scripts/Prepare-LoopAuditPackage.ps1` - check required evidence and generate
  `audit-input.md`; missing evidence marks the phase blocked for audit.
- `scripts/Accept-LoopPhase.ps1` - record `ACCEPTED`, `REWORK`, or `BLOCKED`
  from Codex's `audit.md`; `ACCEPTED` is rejected when required evidence is
  missing.
- `scripts/Test-LoopStandard.ps1` - static self-check for the Phase A standard
  kit; it verifies required files, JSON parsing, PowerShell parsing, canonical
  evidence naming, and absence of `pilot-project/`.

## Verification

Run the Phase A self-check from `E:\codexfiles\loop`:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-LoopStandard.ps1
```

The latest recorded verification result is stored in
`loop-standard/PHASE_A_VERIFICATION.md`.

## Evidence Contract

Each phase must have:

- `.ai-loop/evidence/<phase-id>/prompt.md`
- `.ai-loop/evidence/<phase-id>/report.md`
- `.ai-loop/evidence/<phase-id>/diff.patch`
- `.ai-loop/evidence/<phase-id>/verify.log`
- `.ai-loop/evidence/<phase-id>/status.txt`
- `.ai-loop/audits/<phase-id>/audit.md`

Codex must inspect the prompt, report, diff, verify log, status, and relevant
source files before deciding. Missing evidence or `MISSING:` placeholders require
`BLOCKED` or `REWORK`.

## Phase B Start

Phase B should create `pilot-project/` and then run:

```powershell
.\loop-standard\scripts\Initialize-AiLoop.ps1 -TargetRoot E:\codexfiles\loop\pilot-project
.\loop-standard\scripts\Start-LoopPhase.ps1 -TargetRoot E:\codexfiles\loop\pilot-project -PhaseId phase-001 -Title "Minimal pilot change" -Objective "Run the smallest end-to-end Supervisor-Worker loop test."
```

After Kimi executes `.ai-loop/evidence/phase-001/prompt.md`, Phase B should
collect evidence, prepare an audit package, and have Codex write
`.ai-loop/audits/phase-001/audit.md` with exactly one decision.

# Supervisor-Worker Loop Standard Kit

This kit defines a reusable coding loop where Codex acts as Supervisor and
Kimi Code acts as Worker. The Worker executes only the current phase. Codex
owns route planning, evidence review, audit decisions, and phase acceptance.

## Directory Layout

- `templates/` - canonical project templates, including `.ai-loop/`.
- `.ai-loop/` - compatibility copy of the project loop template retained from
  the first draft.
- `scripts/` - Windows PowerShell scripts for loop operations.
- `prompts/` - reusable prompts for Supervisor, Worker, and Audit.
- `docs/` - operational documentation.
- `PHASE_A_MANIFEST.md` - durable Phase A file inventory and verification
  summary.
- `PHASE_A_VERIFICATION.md` - latest recorded Phase A verification result.
- `PHASE_B_PLAN.md` - next-phase pilot plan; it documents Phase B without
  starting it.

The `.ai-loop/templates/` directory includes human-readable templates for
`prompt.md`, `report.md`, `audit-input.md`, `audit.md`, and phase planning.

Phase A of this kit creates the reusable framework only. It does not run the
pilot project.

Check the standard kit without creating a project:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-LoopStandard.ps1
```

After `pilot-project/` exists, add `-AllowPilotProject`.

For global migration planning, read `docs/GLOBAL_INSTALL_PLAN.md`.

## Required Phase Evidence

Every phase must produce these files under `.ai-loop/evidence/<phase-id>/`:

- `prompt.md` - Codex-generated Worker prompt for the current phase.
- `report.md` - Kimi Worker report after executing the phase.
- `diff.patch` - project diff captured by the evidence script.
- `verify.log` - verification command output and exit code.
- `status.txt` - git status or repository status notes.

The audit package is created under `.ai-loop/audits/<phase-id>/` and must
include an `audit.md` with exactly one decision:

- `ACCEPTED`
- `REWORK`
- `BLOCKED`

Codex must not accept a phase by reading only the Worker report. It must inspect
the report, diff, verification log, status, and relevant source files.

Required evidence file names are canonical in the first version:
`prompt.md`, `report.md`, `diff.patch`, `verify.log`, `status.txt`, and
`audit.md`.

## Quick Start In A Project

From this kit directory:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\init-loop.ps1 -ProjectRoot "C:\path\to\project"
```

Start a phase:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\start-phase.ps1 `
  -ProjectRoot "C:\path\to\project" `
  -PhaseId "phase-001" `
  -Title "Implement minimal feature" `
  -Objective "Make the smallest scoped code change and verify it."
```

After Kimi executes the generated prompt, collect evidence:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\collect-evidence.ps1 `
  -ProjectRoot "C:\path\to\project" `
  -PhaseId "phase-001" `
  -ReportPath "C:\path\to\report.md" `
  -VerifyCommand "npm test"
```

Prepare the audit package:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\prepare-audit-pack.ps1 `
  -ProjectRoot "C:\path\to\project" `
  -PhaseId "phase-001"
```

After Codex writes `.ai-loop/audits/phase-001-audit.md`, record the decision:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\accept-phase.ps1 `
  -ProjectRoot "C:\path\to\project" `
  -PhaseId "phase-001"
```

Use `REWORK` or `BLOCKED` instead of `ACCEPTED` when evidence is incomplete,
verification fails, the diff does not match the phase objective, or source
inspection reveals unresolved issues.

## Next Phase

Phase B should create `pilot-project/`, initialize `.ai-loop` inside it, run one
minimal Worker phase, collect evidence, prepare an audit package, and make a
Codex audit decision.

See `PHASE_B_PLAN.md` for the file-based checklist.

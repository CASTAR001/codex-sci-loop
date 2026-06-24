# Evidence, Skill, And Gate Automation Report

Date: 2026-06-24

## Summary

Implemented the next harness layer for auditable Supervisor-Worker phases:
evidence ledgers, skill trigger records, phase gate validation, and a
project-local loop evolution file.

The system remains local-first, markdown-first, git-trackable, human-readable,
and free of cloud, database, Mem0, Zep, Graphiti, or projectmem dependencies.

## Design Patterns Used

- Cline Memory Bank: keep resumable state in layered Markdown files.
- Roo-style mode contracts: keep Supervisor, Worker, Auditor, Verifier, and
  Recovery roles separate.
- Codex `AGENTS.md`: keep root bootstrap short and delegate detailed governance
  into `.ai-loop/`.
- Aider / Continue conventions: treat governance files as read-mostly rules.
- projectmem: use local event logs, decisions, failures, evidence, and handoffs
  rather than chat memory.

## Created Or Updated

- Added `.ai-loop/evidence/` ledgers: evidence ledger, artifact index, command
  log, test log, and provenance map.
- Added `.ai-loop/skills/` ledgers: skill trigger matrix, skill usage ledger,
  and skill artifact map.
- Added `.ai-loop/evolution/project-loop-evolution.md` for project-local
  self-evolution proposals.
- Mirrored the same structures into `loop-standard/templates/.ai-loop/` for new
  projects and `loop-standard/.ai-loop/` compatibility files.
- Added `loop-standard/scripts/validate-phase-gates.ps1`.
- Extended `start-phase.ps1`, `collect-evidence.ps1`,
  `prepare-audit-pack.ps1`, and `accept-phase.ps1`.
- Updated memory, constraints, gates, prompts, config, README, and event schema.

## Behavior Added

- `start-phase.ps1` writes `phase_requirements.json` with task kind, claim IDs,
  required evidence, required skills, and required skill artifacts.
- `collect-evidence.ps1` records phase artifacts into evidence ledgers.
- `prepare-audit-pack.ps1` includes evidence and skill ledgers in audit input
  and blocks audit readiness when gates fail.
- `accept-phase.ps1` validates gates before accepting and requires
  `-Force -OverrideReason` for any override.
- `validate-phase-gates.ps1` checks status transitions, required evidence,
  `MISSING:` placeholders, verification exit code, ledger rows, and required
  skill artifacts.

## Skill Trigger Defaults

- `generic`: no default skill gate.
- `fullstack`: no default scientific skill gate unless Supervisor adds one.
- `physics-research`: `invariant-contract`, `deterministic-verification`.
- `research-writing`: `manuscript-consistency-audit`,
  `deterministic-verification`.
- `data-analysis`: `invariant-contract`, `deterministic-verification`,
  `result-provenance-audit`.

The 8 scientific workflow skills are referenced by name. They are not copied
into each initialized project.

## Verification

Commands and scenarios run:

- PowerShell parse check for all `loop-standard/scripts/*.ps1`: passed.
- `Test-LoopStandard.ps1 -AllowPilotProject`: passed with 61 checked paths.
- Temporary initialized project copied new evidence, skills, and evolution
  templates.
- Generic `fullstack` phase reached audit-ready and accepted successfully.
- `physics-research` phase without required skill artifacts was blocked at audit
  preparation.
- `accept-phase.ps1` refused missing skill artifacts without `-Force`.
- `accept-phase.ps1 -Force -OverrideReason ...` accepted and recorded an
  override event.

Known benign warning:

- Git may print a permission warning for `C:\Users\Lenovo/.config/git/ignore`.
  The harness uses local git state and the warning did not affect validation.

## Next Recommendations

- Align uppercase compatibility scripts with the newer lowercase gate-aware
  scripts or mark them legacy wrappers.
- Build richer recovery enforcement around handoff, compact, and resume.
- Add a global `ai-loop.ps1` command surface after the gate-aware scripts settle.
- Add broader validation coverage for old projects missing the new ledgers.

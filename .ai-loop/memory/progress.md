# Progress

## Completed

- Built `loop-standard/` package with scripts, prompts, docs, templates.
- Created `pilot-project/` fixture and completed phase-001 loop trial.
- Audited pilot result and accepted it with durable evidence.
- Hardened scripts with state checks and changed file splitting.
- Converted `pilot-project/` from embedded git repo to root-tracked fixture.
- Added global install planning and dry install script.
- Added control-plane build plan.
- Created root `.ai-loop/` memory and constraint control plane.
- Added root `AGENTS.md` bootstrap.
- Added role contracts, gates, event schema, prompts, templates, and bootstrap
  report.
- Merged duplicate `agent.md` into `.ai-loop/` memory and kept `AGENTS.md` as
  the single root bootstrap.
- Synchronized reusable `.ai-loop` control-plane structure into
  `loop-standard/templates/.ai-loop/`.
- Added `.agents/` vs `.ai-loop/` boundary documentation.
- Added evidence ledger, artifact index, command log, test log, and provenance
  map.
- Added skill trigger matrix, skill usage ledger, and skill artifact map.
- Added project-local loop evolution file under `.ai-loop/evolution/`.
- Added `validate-phase-gates.ps1` and wired it into audit preparation and
  phase acceptance.
- Added required `phase_requirements.json` generation with task kind, claim IDs,
  evidence requirements, and required skill artifacts.
- Verified ordinary fullstack phase gate passes, physics-research missing skill
  artifacts block audit readiness, and force accept requires an override event.
- Added unified `ai-loop.ps1` command wrapper for init, start, collect,
  audit-pack, validate, accept, resume, link-skills, and doctor.
- Added `link-skills.ps1` with Windows-first directory junctions, symlink
  fallback, mapped-only fallback, source-map recording, and profile support for
  research-core, physics-sim, manuscript, and full-research.
- Added `plugins/codex-loop-harness/` Codex plugin scaffold with Supervisor,
  Auditor, Recovery, and Research Orchestrator workflow skills.
- Verified wrapper behavior in a temporary project: init creates `.ai-loop/` and
  `.agents/skills/`, full-research links 8 skills, fullstack phase can pass
  ordinary gates, physics-research blocks on missing skill artifacts, force
  accept records an override, and broken skill links block validation.

## In Progress

- Hardening recovery, state validation, global installation, and plugin
  packaging flow.

## Pending

- Recovery protocol enforcement.
- Stable PATH/plugin install packaging for `ai-loop.ps1`.
- Uppercase compatibility script alignment.
- Broader validation CLI coverage.

## Last Updated

2026-06-24

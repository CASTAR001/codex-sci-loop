# Fixed Wrapper And Plugin Bootstrap Report

Date: 2026-06-24

## Scope

This phase fixed the loop harness into a two-layer operating model:

1. `loop-standard/scripts/ai-loop.ps1` is the recommended script entrypoint for
   any project.
2. `plugins/codex-loop-harness/` is the first Codex plugin scaffold for
   workflow discovery, role guidance, research orchestration, and future install
   or hook distribution.

Project state remains local to each target project's `.ai-loop/`. Plugin code
and wrapper scripts do not store project-local status.

## Created Or Updated

- `loop-standard/scripts/ai-loop.ps1`: unified command wrapper for `init`,
  `start`, `collect`, `audit-pack`, `validate`, `accept`, `resume`,
  `link-skills`, and `doctor`.
- `loop-standard/scripts/link-skills.ps1`: links research skills into a
  project's `.agents/skills/`, preferring directory junctions on Windows and
  falling back to symbolic links or mapped-only source records.
- `loop-standard/scripts/start-phase.ps1`: supports `-SkillProfile` and merges
  task-kind skills, profile skills, and explicitly required skills into
  `phase_requirements.json`.
- `loop-standard/scripts/validate-phase-gates.ps1`: checks required skill
  availability through `.agents/skills/<skill>/SKILL.md` and
  `.ai-loop/skills/skill-source-map.md`.
- `.ai-loop/skills/skill-source-map.md` and matching template/compat files:
  record project skill source path, link type, version or hash, and status.
- `loop-standard/templates/.ai-loop/loop.config.json`: records skill profiles.
- `plugins/codex-loop-harness/.codex-plugin/plugin.json`: plugin manifest.
- `plugins/codex-loop-harness/skills/loop-supervisor/SKILL.md`: Supervisor
  workflow entry skill.
- `plugins/codex-loop-harness/skills/loop-auditor/SKILL.md`: audit workflow
  skill.
- `plugins/codex-loop-harness/skills/loop-recovery/SKILL.md`: recovery and
  resume workflow skill.
- `plugins/codex-loop-harness/skills/research-loop-orchestrator/SKILL.md`:
  research profile and 8-skill orchestration skill.
- `plugins/codex-loop-harness/scripts/ai-loop.ps1`: thin plugin wrapper that
  locates the repository wrapper.

## Research Skill Profiles

- `research-core`: `research-task-tree`, `invariant-contract`,
  `deterministic-verification`, `skill-compliance-audit`.
- `physics-sim`: `research-task-tree`, `invariant-contract`,
  `bounded-experiment-loop`, `deterministic-verification`,
  `independent-crosscheck`, `result-provenance-audit`,
  `skill-compliance-audit`.
- `manuscript`: `research-task-tree`, `deterministic-verification`,
  `result-provenance-audit`, `manuscript-consistency-audit`,
  `skill-compliance-audit`.
- `full-research`: all 8 scientific workflow skills.

The harness references the 8 skills by name and project link, not by copying
skill packages into every project.

## How Codex Should Use It

For a target project:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 -Command init -ProjectRoot E:\some-project -CreateAgentsBootstrap
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 -Command link-skills -ProjectRoot E:\some-project -Profile full-research
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 -Command start -ProjectRoot E:\some-project -PhaseId phase-001 -TaskKind physics-research -Profile physics-sim
```

Normal full-stack work can use `-TaskKind fullstack` without scientific skill
artifacts unless the task makes correctness-sensitive claims. Physics or
numerical work should use `physics-research` and a research profile.

## Verification

Commands run:

```powershell
Get-ChildItem .\loop-standard\scripts -Filter *.ps1 | parse with PowerShell AST
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-LoopStandard.ps1 -AllowPilotProject
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\ai-loop.ps1 doctor
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\plugins\codex-loop-harness\scripts\ai-loop.ps1 doctor
```

Results:

- PowerShell parse check: OK.
- `Test-LoopStandard.ps1 -AllowPilotProject`: OK, 71 checked paths.
- `ai-loop.ps1 doctor`: OK; found kit root, templates, plugin manifest, and
  all 8 required research skills under `E:\codexfiles\test\.agents\skills`.
- Plugin wrapper `scripts/ai-loop.ps1 doctor`: OK; resolved the repository
  wrapper and reported the same doctor result.
- Temporary project behavior: `init` created `.ai-loop/`, `.agents/skills/`,
  and optional `AGENTS.md`; `link-skills -Profile full-research` linked all 8
  skills; full-stack phase passed ordinary gates; physics-research phase blocked
  audit readiness when required skill artifacts were missing; force accept
  required an override reason; broken skill link caused validation to fail with
  required skill unavailable.

Plugin validator note: the plugin-creator validator script was available but
could not run in this environment because its Python `yaml` dependency is not
installed. The plugin manifest was instead parsed as JSON and plugin skill
`SKILL.md` files were checked by the loop self-check.

## Remaining Work

- Package or install the plugin into the global Codex plugin location.
- Create a stable global PATH shim for `ai-loop.ps1`, or make plugin wrapper
  discovery the primary global entrypoint.
- Harden recovery protocol automation.
- Align or retire uppercase compatibility scripts.
- Add broader validation CLI coverage for install, profile, and broken-link
  scenarios.

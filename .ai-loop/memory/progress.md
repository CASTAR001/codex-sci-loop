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
- Added UTF-8 Chinese root `README.md` and English `README_EN.md`.
- Upgraded `install-global.ps1` to install `loop-standard/`, optional plugin
  source, and a `bin/ai-loop.ps1` shim without modifying PATH.
- Enhanced `ai-loop doctor` to validate plugin manifest, plugin skill
  frontmatter, plugin wrapper, required research skills, and shim status.
- Enhanced `ai-loop resume` to report current phase, phase status, required
  skills, missing evidence, next safe action, and BLOCKED/RESUMABLE decision.
- Converted uppercase compatibility scripts into thin wrappers around the
  canonical `ai-loop.ps1` workflow.
- Verified installed shim doctor, installed project init/link-skills, fullstack
  gates, physics artifact blocking, force override, broken skill link blocking,
  missing-status recovery blocking, and compatibility wrapper smoke flow.
- Added dual-track artifact integrity: Markdown artifact index for human audit
  and `artifact-manifest.json` for machine validation.
- `collect-evidence.ps1` now records SHA256, size, mtime, phase, path, producer,
  and status for required phase evidence.
- `validate-phase-gates.ps1` now blocks missing manifests, missing rows, empty
  evidence, stale hashes, and artifact size mismatches.
- `prepare-audit-pack.ps1` now includes an Artifact Integrity Summary.
- Verified hash mismatch, missing manifest row, missing file, empty file, and
  missing manifest all block validation.
- Created ignored dogfood project `.tmp-ai-loop-dogfood/` with an independent
  git repo, initialized `.ai-loop/`, linked all 8 research workflow skills as
  project-local junctions, started phase-001, and generated a Kimi Worker
  prompt.
- Verified the dogfood failure path: Kimi CLI is configured, but executing it
  from this Codex environment is blocked by sandbox/policy; Codex did not
  perform the Worker business edit, collected evidence, prepared an audit pack,
  and recorded `BLOCKED`.
- Completed the dogfood success path after the user ran Kimi externally:
  evidence collection, artifact integrity, phase gates, audit pack, Codex audit,
  and `accept` all succeeded for `.tmp-ai-loop-dogfood` phase-001.
- Added a Worker-agnostic external invocation layer with `worker-preflight`,
  `invoke-worker`, Kimi Code as a thin profile, project-local runtime state
  under `.ai-loop/runtime/`, and docs/templates for external Worker policy.
- Recorded the knowledge-placement rule: durable harness principles go to
  long-term memory, project-local proposals go to evolution files, and reusable
  procedures/tool practices should be distilled into skills.
- Committed the external Worker preflight layer as
  `c5dfc69 Add external worker invocation preflight`.
- Ran a self-loop optimization phase under `loop-standard/.ai-loop`:
  phase-002 exposed `-TargetStatus` on the unified `ai-loop validate` command,
  collected evidence, passed gates, wrote an ACCEPTED audit, and accepted the
  phase.
- Ran self-loop phase-003 under `loop-standard/.ai-loop`: normalized git changed
  paths relative to `ProjectRoot` before classification, so `.ai-loop/*`
  evidence files are separated from business files in subdirectory project
  roots.
- Ran root self-loop phase-001 under the repository root `.ai-loop`: added
  non-destructive initialization for existing control planes, made optional
  `.agents/skills` creation recoverable, added root runtime state/templates,
  included untracked files in changed-file evidence, made collect-time Markdown
  evidence rows idempotent per phase, validated gates, prepared an audit pack,
  wrote `Decision: ACCEPTED`, and accepted the phase.
- Ran root self-loop phase-002 under the repository root `.ai-loop`: added
  `Test-PluginInstall.ps1`, extended `install-global.ps1` with
  `-CreateMarketplace`, validated a temporary install root with a local Codex
  marketplace file, installed plugin manifest, plugin skills, shim `doctor`,
  plugin wrapper `doctor`, and removed development-only absolute paths from
  plugin workflow skills.

## In Progress

- Decide whether to run a live global Codex plugin install/discovery test, which
  requires explicit user approval because it modifies real Codex/plugin
  configuration.

## Pending

- Choose final non-temporary global install root.
- Expand skill trigger matrix for full-stack and physics workflows.
- Add stricter state transition logs and recovery paths.
- Decide whether skill artifacts should become required manifest entries in the
  next evidence hardening phase.
- Validate plugin discovery in real global Codex configuration after explicit
  approval, if plugin-form stability must be claimed beyond repo-local smoke
  tests.
- Run dogfood phase-002 through `worker-preflight` and `invoke-worker` once the
  external-service invocation is explicitly approved for that phase.
- Decide whether start-time Markdown ledger rows should be made idempotent like
  collect-time evidence rows.

## Last Updated

2026-06-27

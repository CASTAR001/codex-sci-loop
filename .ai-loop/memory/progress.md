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
- Ran root self-loop phase-003 under the repository root `.ai-loop`: added
  `validate-loop.ps1`, exposed it as `ai-loop -Command validate-loop`, included
  it in generated install shims, documented it, updated plugin recovery
  guidance, and verified it against the root control plane.
- Ran root self-loop phase-004 under the repository root `.ai-loop`: added
  `Test-ValidateLoopFailures.ps1` and `Test-Phase004.ps1`, wired them into the
  canonical self-check, and verified that `validate-loop.ps1` rejects duplicate
  phase IDs, broken current phase references, illegal statuses, missing
  accepted audits, stale artifact hashes, and missing recovery-critical files.
- Extended root self-loop phase-004 after collect exposed real failure modes:
  `collect-evidence.ps1` now rewrites filtered Markdown ledger rows with
  `Set-Content -Value`, captures non-fatal verification stderr into
  `verify.log`, and `Test-CollectLedgerIdempotence.ps1` proves repeated collect
  refreshes do not duplicate ledger rows.
- Ran root self-loop phase-005 under the repository root `.ai-loop`: added
  schema manifests and migration logs to root `.ai-loop`,
  `loop-standard/templates/.ai-loop`, and `loop-standard/.ai-loop`; extended
  `validate-loop.ps1` and `ai-loop doctor` with schema checks; added
  `Test-SchemaVersioning.ps1` for missing schema, old/future config schemas,
  config/manifest mismatch, missing schema property, and status schema mismatch;
  and added `Test-Phase005.ps1` as the current non-global verification matrix.
- Ran root self-loop phase-006 under the repository root `.ai-loop`: added
  `decide-phase.ps1` and `ai-loop -Command decide` for durable `REWORK` and
  `BLOCKED` outcomes, updated the installed shim command surface, made
  `validate-loop.ps1` require matching audits and `rework.txt` / `blocked.txt`,
  added `Test-PhaseDecisions.ps1`, and documented non-accepted decisions in the
  README files and plugin skills.
- Ran root self-loop phase-007 under the repository root `.ai-loop`: added
  `migrate-loop.ps1` and `ai-loop -Command migrate` for non-destructive upgrades
  of existing `.ai-loop` projects, updated installed shims and docs, added
  `Test-MigrateLoop.ps1` covering old-project repair, project memory
  preservation, future-schema blocking, and missing `.ai-loop` rejection, and
  added `Test-Phase007.ps1` as the current non-global verification matrix.
- Ran root self-loop phase-008 under the repository root `.ai-loop`: added
  append-only state transition logging through
  `.ai-loop/events/state-transitions.ndjson`, wired canonical status-changing
  scripts to `record-state-transition.ps1`, bumped the control-plane schema to
  `1.3`, extended `validate-loop.ps1` to reject latest-transition/status
  mismatches, and added `Test-StateTransitions.ps1` plus `Test-Phase008.ps1`.
- Ran root self-loop phase-009 under the repository root `.ai-loop`: added
  `scaffold-rework-phase.ps1` and `ai-loop -Command scaffold-rework` so durable
  `REWORK` decisions can be converted into bounded follow-up phases using the
  source audit and `rework.txt` as fixed scope inputs, added
  `Test-ReworkScaffold.ps1`, and documented the workflow in README files and
  plugin skills.
- Ran root self-loop phase-010 under the repository root `.ai-loop`: extended
  `collect-evidence.ps1` to record declared required skill artifacts as
  `skill-artifact` rows in both `artifact-index.md` and
  `artifact-manifest.json`, added `Test-SkillArtifactManifest.ps1` for
  recorded, tampered, and missing skill artifact cases, and added
  `Test-Phase010.ps1` as the current non-global verification matrix.
- Ran root self-loop phase-011 under the repository root `.ai-loop`: added
  `test-temp-root.ps1` and `Test-TempIsolation.ps1`, updated fixture tests to
  use per-run `.tmp-ai-loop-*/run-<prefix>-<pid>-<guid>` directories, preserved
  explicit `Test-PluginInstall.ps1 -InstallRoot` behavior, and verified
  concurrent plugin install smoke tests no longer contend over one fixed temp
  root.
- Ran root self-loop phase-012 under the repository root `.ai-loop`: made
  `start-phase.ps1 -Force` refresh same-phase metadata, prompt, requirements,
  `status.json.phases`, and start-time Markdown ledger rows instead of
  duplicating status or ledger entries; added `Test-StartPhaseIdempotence.ps1`
  and `Test-Phase012.ps1`.
- Ran root self-loop phase-013 under the repository root `.ai-loop`: enhanced
  `ai-loop resume` with transition-log diagnostics, latest/recent transition
  reporting, transition consistency checks, next safe command output, and
  BLOCKED recovery on transition/status mismatch; added
  `Test-ResumeDiagnostics.ps1` and `Test-Phase013.ps1`.
- Ran root self-loop phase-014 under the repository root `.ai-loop`: added
  `-RequireExternalWorkerEvidence` for phases that declare external Worker
  usage, recorded required Worker preflight/invocation artifacts in
  `phase_requirements.json`, extended `collect-evidence.ps1` to hash and
  ledger additional required evidence, added audit-pack Worker evidence
  summaries, fixed audit-pack Markdown code fences, and added
  `Test-ExternalWorkerEvidence.ps1` plus `Test-Phase014.ps1`.
- Ran root self-loop phase-015 under the repository root `.ai-loop`: added
  structured audit finding extraction through `extract-audit-findings.ps1` and
  `ai-loop -Command extract-audit-findings`; `decide-phase.ps1` now writes
  `.ai-loop/audits/<phase>-findings.json`; `scaffold-rework-phase.ps1` uses
  structured findings for bounded follow-up scope; `validate-loop.ps1` requires
  findings JSON for terminal `rework` and `blocked` phases; and
  `Test-AuditFindingExtraction.ps1` covers extraction, durable decision state,
  structured rework scaffolding, and missing findings validation.

## In Progress

- Continue 1.0 hardening without modifying real global Codex configuration.

## Pending

- Choose final non-temporary global install root.
- Expand skill trigger matrix for full-stack and physics workflows.
- Use append-only state transition logs for richer recovery paths beyond durable
  non-accepted decisions.
- Validate plugin discovery in real global Codex configuration after explicit
  approval, if plugin-form stability must be claimed beyond repo-local smoke
  tests.
- Run dogfood phase-002 through `worker-preflight` and `invoke-worker` once the
  external-service invocation is explicitly approved for that phase.
- Add a temp-fixture prune command if ignored `.tmp-ai-loop-*` accumulation
  becomes noisy during repeated local dogfooding.
- Decide whether future schema upgrades require deep semantic migration
  transforms beyond phase-007's top-level JSON merge and template repair.
- Use the state transition log to improve `resume` with richer recovery
  explanations and stale-state diagnosis.
- Add optional machine-readable resume output.

## Last Updated

2026-06-28

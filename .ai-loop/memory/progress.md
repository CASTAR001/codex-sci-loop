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
- Ran root self-loop phase-016 under the repository root `.ai-loop`: added
  machine-readable `ai-loop resume -Json` output for scripts, plugins, and
  hooks; preserved the default human-readable resume output; included current
  phase, missing evidence, artifact manifest status, transition diagnostics,
  next safe action, next safe command, blocked flag, and recovery decision in
  the JSON; and added `Test-ResumeJson.ps1` plus `Test-Phase016.ps1`.
- Ran root self-loop phase-017 under the repository root `.ai-loop`: added
  `prune-temp-fixtures.ps1` and `ai-loop -Command prune-temp` for safe
  dry-run-first cleanup of ignored `.tmp-ai-loop-*` fixture run directories;
  deletion requires `-Force`, only `run-*` children under `.tmp-ai-loop-*`
  parents are candidates, newest runs are retained, reparse-point directories
  are skipped, and `Test-PruneTempFixtures.ps1` plus `Test-Phase017.ps1`
  cover dry-run, deletion, namespace protection, and idempotence.
- Ran root self-loop phase-018 under the repository root `.ai-loop`: added
  `migrate -DryRun` and `migrate -DryRun -Json` so Supervisors, scripts,
  plugins, and hooks can inspect planned schema/template repair actions before
  modifying a project. Dry-run does not create migration records, modify JSON,
  copy template files, or append event logs; future schemas still block unless
  `-Force` is explicit. `Test-MigrateDryRun.ps1` and `Test-Phase018.ps1`
  cover JSON planning, text planning, no-write behavior, real migration after
  planning, and future-schema blocking.
- Ran root self-loop phase-019 under the repository root `.ai-loop`: added
  `prune-temp -Json` and `prune-temp -Force -Json` so cleanup candidates and
  deletion results can be consumed by scripts, hooks, CI, and plugins. JSON
  output includes mode, retention settings, cutoff, candidates, deleted rows,
  skipped paths, and counts, while existing text output remains covered.
  `Test-PruneTempJson.ps1` and `Test-Phase019.ps1` cover parseable dry-run and
  force JSON output without mixed human-readable text.
- Ran root self-loop phase-020 under the repository root `.ai-loop`: added
  `check-readiness.ps1` and `ai-loop -Command readiness` with text and JSON
  output. The read-only command maps the 1.0 delivery goal to current kit and
  project evidence, reports blocking gaps versus warnings, runs loop-wide
  validation, and treats real global Codex plugin discovery as a warning until
  the user explicitly approves modifying global configuration. `Test-Readiness.ps1`
  and `Test-Phase020.ps1` cover root readiness, parseable JSON, missing
  `.ai-loop` blocked JSON, and the previous non-global matrix.
- Ran root self-loop phase-021 under the repository root `.ai-loop`: added
  `loop-standard/docs/RELEASE_NOTES_1.0.md` and
  `loop-standard/docs/OPERATOR_CHECKLIST_1.0.md`, linked them from the Chinese
  and English root README files and `loop-standard/README.md`, extended
  readiness checks for the release/operator docs, and added
  `Test-ReleaseDocs.ps1` plus `Test-Phase021.ps1`. The release notes preserve
  `PLUGIN-GLOBAL` as a warning because live global Codex plugin discovery has
  not been approved for real global configuration.
- Ran root self-loop phase-022 under the repository root `.ai-loop`: added a
  declarative semantic migration transform registry in
  `.ai-loop/schema/migration-transforms.json`, `loop-standard/.ai-loop/`, and
  `loop-standard/templates/.ai-loop/`; extended `migrate-loop.ps1` so dry-run
  plans and migration records include `semantic_transforms`; and added
  `Test-MigrateSemanticTransforms.ps1` plus `Test-Phase022.ps1`. The first
  transform set repairs legacy `required_evidence`, hydrates `current_phase`
  from `current_phase_id`, and maps legacy `completed` statuses to `accepted`.
- Ran root self-loop phase-023 under the repository root `.ai-loop`: added
  `Test-TaskKindSkillTriggers.ps1` and `Test-Phase023.ps1` to verify start-time
  skill requirements for `fullstack`, `physics-research`, `data-analysis`,
  `research-writing`, the `physics-sim` profile, and manual skill overrides.
  This preserves a light full-stack default while proving physics/research work
  automatically declares the required scientific workflow skills.
- Ran root self-loop phase-024 under the repository root `.ai-loop`: added the
  read-only `release-check.ps1` script and `ai-loop -Command release-check`.
  The command aggregates readiness, loop-wide validation, and a bounded matrix
  script, emits text or JSON, supports `-SkipMatrix` for quick diagnostics, and
  keeps final release sign-off oriented around a full matrix run.

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
- Decide whether future schema upgrades require deep semantic migration
  transforms beyond the current dry-run/top-level JSON merge/template repair
  migration model.
- Use the state transition log to improve `resume` with richer recovery
  explanations and stale-state diagnosis.
- Expand task-kind fixtures further only when new task kinds or skill profiles
  are added.
- Use `release-check` as the compact 1.0 sign-off entrypoint before claiming
  delivery.
- Add new semantic migration transform types only when future schema changes
  require them, with fixture coverage before use.

## Last Updated

2026-06-29

# Handoff Summary

## Current Phase

External Worker invocation hardening is implemented; dogfood phase-001 has been
accepted.

## Last Verified State

`loop-standard/` exists with scripts, docs, prompts, templates, pilot fixture,
and e2e validation. `pilot-project/` is a root-tracked fixture, not a nested git
repository. The latest self-check reports 75 required paths.

Dogfood setup succeeded: the temporary project has its own git repo, `.ai-loop/`
control plane, project-local `AGENTS.md`, `.agents/skills/` junctions for all 8
research workflow skills, and phase-001 evidence files.

Dogfood phase-001 was completed after the user ran Kimi Code externally. Codex
then collected evidence, validated gates, prepared an audit pack, wrote
`Decision: ACCEPTED`, and ran `accept` successfully.

The harness now has a generic external Worker layer: `worker-preflight` records
safety/feasibility review, and `invoke-worker` only runs after a safe preflight.
Kimi Code is represented as a thin Worker profile, not as a hard-coded route.
`-Yolo` is allowed without a separate stop, but external service invocation,
sensitive prompt content, and long-term memory/governance upgrades still require
explicit user confirmation.

Root `AGENTS.md` is the only bootstrap file. Former `agent.md` content was
merged into `.ai-loop/` memory and the file was removed.

## Current Focus

Use the root `.ai-loop/` control plane before further changes. New required
files include `.ai-loop/evidence/*`, `.ai-loop/skills/*`,
`.ai-loop/skills/skill-source-map.md`, and
`.ai-loop/evolution/project-loop-evolution.md`.

Reusable control-plane templates under `loop-standard/templates/.ai-loop/` now
include evidence ledgers, skill ledgers, the skill source map, and the
project-local evolution file. `loop-standard/scripts/ai-loop.ps1` is the
recommended user-facing command. `install-global.ps1` can create
`<InstallRoot>/bin/ai-loop.ps1`, copy `loop-standard/`, and optionally copy
`plugins/codex-loop-harness/`. The plugin scaffold stores no project-local
`.ai-loop` state.

Evidence now uses a dual-track model: Markdown ledgers are the human-readable
surface, while `.ai-loop/evidence/artifact-manifest.json` is the gate-validated
integrity source for required phase evidence.

## Must Preserve

- Worker must not own the global route.
- Evidence beats prose.
- Governance files are read-mostly unless in harness maintenance.
- Scientific correctness skills must not be skipped for correctness-sensitive
  work.
- Required skill artifacts block acceptance unless a Supervisor override reason
  is recorded.
- Required skill availability is checked through project `.agents/skills/` and
  `.ai-loop/skills/skill-source-map.md`.
- Root entrypoint is `AGENTS.md`; detailed rules live in `.ai-loop/`.
- `.agents/` is for agent runtime assets, not durable project memory.
- Uppercase compatibility scripts must remain thin wrappers and must not contain
  independent legacy state logic.
- Required phase evidence must have a matching artifact manifest row and current
  SHA256 hash before audit/accept can pass.
- Do not use this MVP repository's `.ai-loop/evolution/` for dogfood-specific
  project evolution content. Project evolution files belong to the target
  project using the harness.
- Classify reusable lessons before writing: durable governance goes to memory,
  project-local proposals go to evolution, reusable procedures go to skills.

## Next Safe Action

For plugin stability, run a separate install/discovery smoke test; source-level
`doctor` is not enough to claim Codex plugin runtime stability. After that, run
dogfood phase-002 through `worker-preflight` and `invoke-worker` to validate the
new external Worker path.

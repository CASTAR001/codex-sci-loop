# Handoff Summary

## Current Phase

Evidence ledger, skill trigger matrix, and phase gate automation implemented.
Next phase is recovery enforcement, global entrypoint hardening, or compatibility
script alignment.

## Last Verified State

`loop-standard/` exists with scripts, docs, prompts, templates, pilot fixture,
and e2e validation. `pilot-project/` is a root-tracked fixture, not a nested git
repository. The latest self-check reports 61 required paths.

Root `AGENTS.md` is the only bootstrap file. Former `agent.md` content was
merged into `.ai-loop/` memory and the file was removed.

## Current Focus

Use the root `.ai-loop/` control plane before further changes. New required
files include `.ai-loop/evidence/*`, `.ai-loop/skills/*`, and
`.ai-loop/evolution/project-loop-evolution.md`.

Reusable control-plane templates under `loop-standard/templates/.ai-loop/` now
include evidence ledgers, skill ledgers, and the project-local evolution file.

## Must Preserve

- Worker must not own the global route.
- Evidence beats prose.
- Governance files are read-mostly unless in harness maintenance.
- Scientific correctness skills must not be skipped for correctness-sensitive
  work.
- Required skill artifacts block acceptance unless a Supervisor override reason
  is recorded.
- Root entrypoint is `AGENTS.md`; detailed rules live in `.ai-loop/`.
- `.agents/` is for agent runtime assets, not durable project memory.

## Next Safe Action

Run `Test-LoopStandard.ps1 -AllowPilotProject`, then choose whether to harden
recovery prompts, build the global `ai-loop.ps1` entrypoint, or align uppercase
compatibility scripts with the newer lowercase gate-aware scripts.

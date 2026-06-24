# Handoff Summary

## Current Phase

Memory + constraint system bootstrap completed. Next phase is evidence ledger
and skill dispatcher planning/implementation.

## Last Verified State

`loop-standard/` exists with scripts, docs, prompts, templates, pilot fixture,
and e2e validation. `pilot-project/` is a root-tracked fixture, not a nested git
repository.

Root `AGENTS.md` is the only bootstrap file. Former `agent.md` content was
merged into `.ai-loop/` memory and the file was removed.

## Current Focus

Use the new root `.ai-loop/` control plane before further changes. Next likely
work: add evidence ledger, skill trigger matrix, and skill usage ledger.

Reusable memory/control-plane templates now exist under
`loop-standard/templates/.ai-loop/`.

## Must Preserve

- Worker must not own the global route.
- Evidence beats prose.
- Governance files are read-mostly unless in harness maintenance.
- Scientific correctness skills must not be skipped for correctness-sensitive
  work.
- Root entrypoint is `AGENTS.md`; detailed rules live in `.ai-loop/`.
- `.agents/` is for agent runtime assets, not durable project memory.

## Next Safe Action

Review the bootstrap report, then decide whether to copy the new memory and
constraint structures into `loop-standard/templates/.ai-loop/` before building
evidence and skill ledgers.

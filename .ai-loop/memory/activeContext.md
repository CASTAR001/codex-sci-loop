# Active Context

## Current Phase

Memory + constraint system bootstrap completed.

## Current Objective

Root-level `.ai-loop/` control plane has been created for this repository. The
system is local-first, markdown-first, git-trackable, human-readable, and
suitable for later global Codex installation.

## Active Plan

The next build plan is:

```text
loop-standard/docs/CONTROL_PLANE_BUILD_PLAN.md
```

The near-term build order remains:

1. Memory + constraints.
2. Evidence ledger + skill dispatcher.
3. State machine + role contracts.
4. Recovery protocol + change control.
5. Global entrypoint + validation CLI.

## Current Work Boundary

The first-stage memory and constraint layer plus role contracts, gates, event
schema, prompts, templates, and bootstrap report are now in place.

Do not install external memory dependencies.
Do not delete or rewrite existing `loop-standard/` or `pilot-project/` evidence.
Keep reusable framework code under `loop-standard/` and pilot fixture work under
`pilot-project/`.

## Next Safe Action

Proceed to evidence ledger and skill dispatcher only after reviewing:

- `.ai-loop/memory/handoff-summary.md`
- `.ai-loop/memory/constraint-ledger.md`
- `.ai-loop/gates/pre-action-check.md`

## Open Questions

- Should future global installation write an `ai-loop.ps1` wrapper into a PATH
  directory, or keep absolute script invocation?
- Should the new root `.ai-loop/` control-plane files be copied into
  `loop-standard/templates/.ai-loop/` next, or should template migration wait
  until evidence and skill ledgers are added?

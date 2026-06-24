# AI Loop Control Plane

This `.ai-loop/` directory is the local, git-trackable control plane for this
repository. It stores memory, constraints, roles, gates, events, prompts, and
templates for a reusable Supervisor-Worker loop harness.

## Bootstrap Read Order

Before planning or modifying files, an agent must read:

1. `.ai-loop/README.md`
2. `.ai-loop/memory/activeContext.md`
3. `.ai-loop/memory/constraint-ledger.md`
4. `.ai-loop/gates/pre-action-check.md`

## Design Influences

- Cline Memory Bank: layered project memory.
- Roo Code Memory Bank: mode-specific role contracts.
- AGENTS.md: short bootstrap file, not a giant constitution.
- Aider / Continue rules: governance files are read-mostly.
- projectmem: local-first, event-sourced, decision/failure tracking.

## Governance Files

Governance files define loop behavior. Ordinary Workers must not edit them
unless the Supervisor explicitly declares a harness maintenance phase.

Governance directories:

- `.ai-loop/memory/`
- `.ai-loop/roles/`
- `.ai-loop/gates/`
- `.ai-loop/events/`
- `.ai-loop/prompts/`
- `.ai-loop/templates/`

## Current Phase

Current phase: memory and constraint system bootstrap.

The next systems after this phase are evidence ledger, skill trigger matrix,
phase gate automation, and richer state-machine enforcement.

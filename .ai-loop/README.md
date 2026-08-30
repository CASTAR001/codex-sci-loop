# AI Loop Control Plane

This `.ai-loop/` directory is the local, git-trackable control plane for this
repository. It stores current memory, constraints, gates, events, evidence,
prompts, and recovery state for the native Codex loop plugin.

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
- `.ai-loop/evidence/`
- `.ai-loop/skills/`
- `.ai-loop/evolution/`
- `.ai-loop/prompts/`
- `.ai-loop/templates/`
- `.ai-loop/workers/`

## Current Phase

Current phase: native `codex-sci-loop` 1.0 source certification.

The active path uses the native Codex execution thread, an isolated native
completion auditor, capability ABI checks, signed receipts, evidence
integrity, and recovery state. The PowerShell toolkit is compatibility-only;
historical run evidence is not current execution guidance.

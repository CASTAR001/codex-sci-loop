# Memory And Constraint Bootstrap Report

## Summary

Created the first-stage `.ai-loop/` memory and constraint control plane for this
repository. The system is local-first, markdown-first, git-trackable, and
worker-agnostic.

## Open Source Patterns Borrowed

- Cline Memory Bank: borrowed layered memory files such as project brief,
  product context, active context, system patterns, tech context, and progress.
- Roo Code Memory Bank: borrowed mode-specific contracts for Supervisor,
  Worker, Auditor, Verifier, and Recovery.
- AGENTS.md: used a short root bootstrap file that points agents to `.ai-loop/`
  instead of becoming a giant rulebook.
- Aider / Continue rules: borrowed read-mostly governance conventions so normal
  Workers do not casually change rule files.
- projectmem: borrowed local-first event-sourced memory, decision/failure
  tracking, and pre-action gate ideas using Markdown and NDJSON only.

## Created Or Modified Files

- `AGENTS.md`
- `.ai-loop/README.md`
- `.ai-loop/memory/projectbrief.md`
- `.ai-loop/memory/productContext.md`
- `.ai-loop/memory/activeContext.md`
- `.ai-loop/memory/systemPatterns.md`
- `.ai-loop/memory/techContext.md`
- `.ai-loop/memory/progress.md`
- `.ai-loop/memory/decision-log.md`
- `.ai-loop/memory/constraint-ledger.md`
- `.ai-loop/memory/failure-ledger.md`
- `.ai-loop/memory/handoff-summary.md`
- `.ai-loop/roles/supervisor-contract.md`
- `.ai-loop/roles/worker-contract.md`
- `.ai-loop/roles/auditor-contract.md`
- `.ai-loop/roles/verifier-contract.md`
- `.ai-loop/roles/recovery-contract.md`
- `.ai-loop/gates/pre-action-check.md`
- `.ai-loop/gates/phase-gates.md`
- `.ai-loop/gates/stop-rules.md`
- `.ai-loop/events/event-schema.md`
- `.ai-loop/events/event-log.ndjson`
- `.ai-loop/prompts/update-memory.prompt.md`
- `.ai-loop/prompts/resume-loop.prompt.md`
- `.ai-loop/prompts/pre-action-check.prompt.md`
- `.ai-loop/prompts/supervisor-next-step.prompt.md`
- `.ai-loop/templates/decision-entry.template.md`
- `.ai-loop/templates/failure-entry.template.md`
- `.ai-loop/templates/handoff-summary.template.md`
- `.ai-loop/templates/worker-report.template.md`
- `.ai-loop/reports/memory-constraint-bootstrap-report.md`

## How Codex Should Use This System

Codex should read `AGENTS.md`, then follow its bootstrap read order. Before
acting, Codex should run the pre-action check mentally or explicitly. After
meaningful work, Codex should update active context, progress, handoff summary,
and event log.

## How A New Session Recovers

Use `.ai-loop/prompts/resume-loop.prompt.md`. The new session reads the handoff
summary, active context, constraint ledger, decision log, failure ledger, and
phase gates before modifying files.

## Governance Files

The following are governance files and are read-only for normal Workers:

- `.ai-loop/memory/`
- `.ai-loop/roles/`
- `.ai-loop/gates/`
- `.ai-loop/events/`
- `.ai-loop/prompts/`
- `.ai-loop/templates/`

They may be changed only during an explicit harness maintenance phase.

## Follow-Up Recommendations

Next stage should add:

- evidence ledger and artifact index;
- skill trigger matrix and skill usage ledger;
- phase gate automation;
- validation scripts for memory/evidence/state;
- stronger integration with `loop-standard/templates/.ai-loop/`.

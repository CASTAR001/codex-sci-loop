# `.agents/` vs `.ai-loop/` Boundary

This repository uses two similarly named areas with different responsibilities.
They should not be merged.

## Short Answer

- `AGENTS.md` is the root bootstrap file for agents.
- `.ai-loop/` is durable project loop state and governance.
- `.agents/` is for agent-runtime assets, experiments, or implementation
  support files that are not project truth.

## `AGENTS.md`

Purpose:

- Tell any agent what to read first.
- Stay short.
- Point into `.ai-loop/`.

Do not place full policies, long memories, or phase evidence here.

## `.ai-loop/`

Purpose:

- Project-local source of truth.
- Memory, constraints, roles, gates, events, prompts, templates, evidence,
  audits, and recovery state.
- Git-trackable, human-readable, local-first governance.

Place here:

- decisions;
- constraints;
- handoff summaries;
- evidence ledgers;
- skill usage ledgers;
- phase states;
- audit inputs and audit decisions;
- recovery prompts.

Do not place tool caches, generated dependencies, or private agent runtime
implementation details here.

## `.agents/`

Purpose:

- Agent support assets that are not project truth.
- Optional runtime experiments, helper notes, generated scratch material, or
  per-agent implementation support.

Place here only when a file is useful to agents but should not be treated as
authoritative loop memory.

Examples:

- scratch analysis for a single agent implementation;
- temporary generated helper assets;
- local-only agent experiments;
- non-canonical drafts before promotion into `.ai-loop/`.

## Promotion Rule

If a file in `.agents/` becomes durable truth, promote it into `.ai-loop/` and
record the decision in `.ai-loop/memory/decision-log.md` or
`.ai-loop/events/event-log.ndjson`.

## Common Mistakes

- Mistake: putting all policies in `AGENTS.md`.
  Fix: keep `AGENTS.md` as bootstrap and put policies in `.ai-loop/`.

- Mistake: putting project facts in `.agents/`.
  Fix: project facts belong in `.ai-loop/memory/fact-ledger.md` once that file
  exists.

- Mistake: letting Workers edit `.ai-loop/` during normal execution.
  Fix: `.ai-loop/` governance files are read-mostly unless Supervisor declares a
  harness maintenance phase.

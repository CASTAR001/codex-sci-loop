# System Patterns

## Layered Memory

Borrowed from Cline Memory Bank:

- `projectbrief.md`: stable project identity.
- `productContext.md`: why the harness exists.
- `activeContext.md`: current phase and next safe action.
- `systemPatterns.md`: durable architecture patterns.
- `techContext.md`: tool and platform constraints.
- `progress.md`: completed, active, and pending work.

## Role Separation

Borrowed from Roo Code mode-specific rules:

- Supervisor plans and gates.
- Worker executes current phase only.
- Auditor evaluates evidence.
- Verifier runs or checks reproducible commands.
- Recovery reconstructs state after interruption.

## Governance Files

Borrowed from Aider / Continue read-only convention:

Governance files are read-mostly. A Worker may cite them, but must not alter
them unless the Supervisor declares a harness maintenance phase.

## Event-Sourced Memory

Borrowed from projectmem:

Important decisions, attempts, failures, fixes, verifications, handoffs, and
constraint updates are append-only events in `.ai-loop/events/event-log.ndjson`.

## Pre-Action Gate

Before edits, an agent checks constraints, known failures, and skill triggers.
If a gate fails, stop before changing files.

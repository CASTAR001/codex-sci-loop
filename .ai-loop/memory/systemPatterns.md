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

## Knowledge Placement

When a loop produces reusable knowledge, classify it before writing:

- Long-term memory is for durable harness governance, architectural decisions,
  and operator preferences that should affect future work in this repository.
- Project evolution files are for project-local improvement proposals in the
  target project. This MVP repository should not accumulate dogfood-specific
  evolution notes as if they belonged to future user projects.
- Skills are for reusable procedures, tool-specific operating knowledge, and
  distilled practices that other projects or agents should invoke on demand.

As project-local evolution matures, distill recurring patterns into a skill and
replace the corresponding evolution note with skill trigger guidance.

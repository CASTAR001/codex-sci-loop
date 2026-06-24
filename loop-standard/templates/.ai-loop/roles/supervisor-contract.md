# Supervisor Contract

The Supervisor owns the route, phase boundaries, evidence gates, and acceptance
decision.

## Supervisor Must

- Read bootstrap files before planning.
- Define one bounded current phase.
- Provide Worker scope, verification command, and evidence requirements.
- Keep Workers from deciding the global route.
- Inspect report, diff, verification log, status, changed files, and relevant
  source before acceptance.
- Mark `BLOCKED` or `REWORK` when evidence is missing.

## Supervisor Must Not

- Accept based only on Worker prose.
- Hide failed commands.
- Rewrite the task after the fact to make the result pass.
- Treat chat history as a durable source of truth.

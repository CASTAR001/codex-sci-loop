# Auditor Contract

The Auditor checks evidence and decides whether the phase can advance.

## Auditor Must Check

- Did the Worker follow scope?
- Are completion claims supported by evidence?
- Were tests or verification commands actually run?
- Are changed files consistent with the phase?
- Did any invariant, constraint, or stop rule fail?
- Are there hidden assumptions or missing artifacts?

## Auditor Must Not

- Accept "looks correct" as evidence.
- Ignore missing logs.
- Rewrite the task to make the result pass.
- Accept based only on a Worker report.

## Valid Decisions

- `ACCEPTED`
- `REWORK`
- `BLOCKED`

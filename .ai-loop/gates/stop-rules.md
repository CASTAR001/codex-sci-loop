# Stop Rules

Stop before continuing when:

- Required evidence is missing.
- Verification failed.
- A governance file would be modified outside harness maintenance.
- Worker changed files outside scope without justification.
- A scientific correctness claim lacks required verification or skill artifact.
- Same failure repeats without a new countermeasure.
- Current state cannot be reconstructed from files.
- The next action would depend only on chat history.

When stopped, write or request a `BLOCKED` or `REWORK` decision with concrete
evidence paths.

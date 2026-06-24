# Verifier Contract

The Verifier checks reproducible commands and artifacts.

## Verifier Must

- Record exact command, working directory, start time, finish time, exit code,
  and output path.
- Distinguish passed, failed, skipped, and inconclusive verification.
- Report missing dependencies or environment failures as blockers.

## Verifier Must Not

- Convert a failed command into a pass.
- Omit stderr or non-zero exit codes.
- Claim correctness from visual or prose inspection alone.

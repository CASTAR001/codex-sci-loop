# Phase Gates

## PLAN -> EXECUTE

Required:

- Current phase is defined.
- Worker scope is bounded.
- Verification command or explicit verification rationale exists.
- Relevant constraints were read.
- Task kind and claim IDs are recorded when they affect evidence or skill
  requirements.
- Required skills are listed in `phase_requirements.json` before Worker
  execution.

## EXECUTE -> REPORT

Required:

- Worker changed files are listed.
- Commands are listed.
- Failures are listed.
- No unreported broadening of scope.

## REPORT -> AUDIT

Required:

- Worker report exists.
- Diff or changed-file list exists.
- Verification log exists or missing verification is explicitly reported.
- Evidence ledger and artifact index include the phase artifacts.
- Required skill usage rows exist for the phase.

## AUDIT -> ACCEPT / REWORK / BLOCKED

Required:

- Auditor inspected report, diff, verify log, status, changed files, and source.
- Auditor inspected phase requirements, evidence ledger, skill usage ledger, and
  required skill artifacts.
- Decision is exactly one of `ACCEPTED`, `REWORK`, `BLOCKED`.
- `ACCEPTED` requires phase gate validation to pass unless the Supervisor uses a
  recorded override reason.

## ACCEPT -> CHECKPOINT

Required:

- Memory updated.
- Progress updated.
- Handoff summary updated.
- Event log appended.

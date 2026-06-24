# Phase Gates

## PLAN -> EXECUTE

Required:

- Current phase is defined.
- Worker scope is bounded.
- Verification command or explicit verification rationale exists.
- Relevant constraints were read.

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

## AUDIT -> ACCEPT / REWORK / BLOCKED

Required:

- Auditor inspected report, diff, verify log, status, changed files, and source.
- Decision is exactly one of `ACCEPTED`, `REWORK`, `BLOCKED`.

## ACCEPT -> CHECKPOINT

Required:

- Memory updated.
- Progress updated.
- Handoff summary updated.
- Event log appended.

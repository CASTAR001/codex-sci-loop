# Failure Ledger

| ID | Failure Mode | Trigger | Countermeasure | Status |
|---|---|---|---|---|
| F001 | Compact loses constraints | Long-running thread or resumed session | Read `constraint-ledger.md` and `handoff-summary.md` before action | Active |
| F002 | Worker broadens scope | Worker self-assigns global planning | Worker contract forbids route decisions | Active |
| F003 | Prose completion without evidence | Report says done but lacks diff/log/test | Auditor rejects or marks `REWORK` | Active |
| F004 | Repeated failed repair | Same bug fixed repeatedly without ledger entry | Add failure and fix to event log | Active |
| F005 | Verification skipped | Worker claims success without command log | Stop at pre-action/audit gate | Active |
| F006 | Governance drift | Worker edits rules during normal execution | Treat governance files as read-mostly | Active |
| F007 | Scientific hallucination | Model says result is correct without deterministic evidence | Require correctness skill and verification artifact | Active |
| F008 | Auditor becomes polite approver | Audit praises report without checking files | Auditor contract requires evidence inspection | Active |
| F009 | StrictMode hides validator root cause | An older or incomplete loop JSON omits a property read directly by `validate-loop.ps1` | Guard all external JSON reads, emit the exact missing field, retain a bounded multi-line hook failure tail, and run malformed-property fixtures | Fixed 2026-08-19 |

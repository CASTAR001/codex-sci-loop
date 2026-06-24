# Supervisor Next Step Prompt

Use this after reading a Worker report or audit report.

Read:

1. `.ai-loop/memory/activeContext.md`
2. `.ai-loop/memory/constraint-ledger.md`
3. `.ai-loop/gates/phase-gates.md`
4. Worker report
5. Diff or changed files
6. Verification log
7. Relevant source files
8. Audit report if present

Decide one next step:

- `ACCEPTED`: evidence complete, verification passed, scope followed.
- `REWORK`: Worker must fix concrete issues.
- `BLOCKED`: missing evidence, missing access, failed invariant, or unclear
  state prevents safe progress.

Write the decision with evidence paths. Do not accept based on prose alone.

# Supervisor Next Step Prompt

Use this after reading a Worker report or audit report.

Read:

1. `.ai-loop/memory/activeContext.md`
2. `.ai-loop/memory/constraint-ledger.md`
3. `.ai-loop/gates/phase-gates.md`
4. `.ai-loop/evidence/evidence-ledger.md`
5. `.ai-loop/skills/skill-usage-ledger.md`
6. `.ai-loop/skills/skill-source-map.md`
7. Phase requirements
8. Worker report
9. Diff or changed files
10. Verification log
11. Relevant source files
12. Audit report if present

Decide one next step:

- `ACCEPTED`: evidence complete, verification passed, required skill artifacts
  present or explicitly overridden, scope followed.
- `REWORK`: Worker must fix concrete issues.
- `BLOCKED`: missing evidence, missing access, failed invariant, or unclear
  state prevents safe progress.

Write the decision with evidence paths. Do not accept based on prose alone.

# Resume Loop Prompt

You are resuming a previously interrupted Supervisor-Worker loop.

Read in order:

1. `.ai-loop/README.md`
2. `.ai-loop/memory/handoff-summary.md`
3. `.ai-loop/memory/activeContext.md`
4. `.ai-loop/memory/constraint-ledger.md`
5. `.ai-loop/memory/decision-log.md`
6. `.ai-loop/memory/failure-ledger.md`
7. `.ai-loop/gates/pre-action-check.md`
8. `.ai-loop/gates/phase-gates.md`
9. `.ai-loop/evidence/evidence-ledger.md`
10. `.ai-loop/skills/skill-usage-ledger.md`
11. `.ai-loop/skills/skill-source-map.md`
12. `.ai-loop/evolution/project-loop-evolution.md`

Then output:

- current phase;
- last verified evidence;
- required skill artifacts and their status;
- open blockers;
- next safe action;
- files to inspect before modifying anything.

Do not modify files until the next safe action is clear.

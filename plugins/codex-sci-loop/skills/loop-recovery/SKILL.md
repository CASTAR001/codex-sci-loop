---
name: loop-recovery
description: "Recover a codex-sci-loop phase after interruption, compaction, restart, or handoff by reading durable project state instead of relying on chat history."
---

# Loop Recovery

Recover from files in this order:

```bash
python3 <plugin-root>/scripts/sci_loop.py validate --project-root <git-root>
python3 <plugin-root>/scripts/sci_loop.py resume --project-root <git-root> --json
```

Then inspect the reported phase, phase prompt, status, evidence, constraints,
verification log, structured audit inputs, canonical snapshot and host gate
state before acting. Continue the recorded phase without broadening it. Never
reuse a receipt after any protected input or workspace evidence changed. If
durable state is inconsistent or required evidence is missing, fail closed and
prepare rework or a genuine user-required block; do not synthesize acceptance.

---
name: loop-goal-bootstrap
description: "Initialize and validate codex-sci-loop before a durable goal, loop phase, goal creation, goal update, or goal recovery in a Git repository."
---

# Loop Goal Bootstrap

Use this skill before planning or editing for a durable goal.

1. Resolve the exact Git root with `git rev-parse --show-toplevel`.
2. Locate the bundled entrypoint at `<plugin-root>/scripts/sci_loop.py`.
3. If `.ai-loop` is absent and the user explicitly requested a durable goal,
   initialize it with:

   ```bash
   python3 <plugin-root>/scripts/sci_loop.py init --project-root <git-root>
   ```

4. Validate and recover durable state:

   ```bash
   python3 <plugin-root>/scripts/sci_loop.py validate --project-root <git-root>
   python3 <plugin-root>/scripts/sci_loop.py resume --project-root <git-root> --json
   ```

Do not initialize a parent directory, overwrite existing state, create a goal
without user authorization, or continue when validation fails. The active
Codex thread remains the executor; this plugin manages evidence and gates, not
the agent runtime.

In LumiForge Goal mode, the runtime adapter captures the exact triggering
prompt before model execution. Use only the host-bound request envelope for the
goal; never reconstruct or paraphrase the original request from chat memory.

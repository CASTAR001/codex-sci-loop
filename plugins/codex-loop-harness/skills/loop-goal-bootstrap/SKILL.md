---
name: loop-goal-bootstrap
description: "Bootstrap and validate codex-sci-loop before work involving a loop, Supervisor/Worker flow, durable Codex goal, long-running goal, goal creation/update/resume, or explicit .ai-loop request. Use before creating or updating a goal and before planning or editing for any loop-driven task."
---

# Loop Goal Bootstrap

Prepare the repository before the requested loop or goal work begins.

## Bootstrap

1. Resolve the current Git root with `git rev-parse --show-toplevel`. Do not run
   `git init` and do not treat a parent directory as the project. Outside a Git
   repository, report that project initialization is not applicable and
   continue only if the requested goal does not require repository state.
2. Resolve `ai-loop` from `PATH`, falling back to `/usr/local/bin/ai-loop`. If
   neither exists, stop before goal creation or loop work and report that the
   system-wide harness is missing.
3. If `<git-root>/.ai-loop/status.json` is absent, run:

   ```bash
   ai-loop -Command init -ProjectRoot <git-root> -CreateAgentsBootstrap
   ```

4. If `.ai-loop` exists but validation reports an older or incomplete schema,
   run a migration dry-run first, then apply the migration only when it is
   non-destructive and preserves user files.
5. Run `ai-loop -Command validate-loop -ProjectRoot <git-root>`. Do not begin
   goal creation, planning, edits, or Worker invocation until bootstrap and
   validation succeed.

## Goal And Worker Defaults

- Create or update a Codex goal only when the user explicitly requests a goal;
  this skill is a prerequisite and does not broaden goal authorization.
- Use `claude-mimo` as the default external Worker profile. Never substitute
  the `claude` command.
- When a phase uses the Worker, start it with
  `-WorkerProfile claude-mimo -RequireExternalWorkerEvidence`.
- Run Worker preflight before invocation. Require explicit authorization before
  passing prompt content to the external service.
- Do not enable `-Yolo` unless the user requests it or the current instructions
  explicitly authorize it.

## Safety

- Preserve existing uncommitted changes and existing `.ai-loop` state.
- Do not read the `claude-mimo` wrapper, LiteLLM configuration or historical
  logs, environment variables, or files likely to contain credentials.
- Do not commit or push unless explicitly requested.
- If bootstrap fails, report `BLOCKED` with the failing check and the smallest
  safe next action.

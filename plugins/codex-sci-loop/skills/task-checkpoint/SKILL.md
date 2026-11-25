---
name: task-checkpoint
description: "Save an ongoing project's decisions and next action when the user stops for now with work outstanding, even without an explicit save request. Use for handoffs, resuming a plan or revising its constraints. One-off answers stay in chat."
---

# Task checkpoint

Use the user's task folder. Locate `../../scripts/checkpoint.py` from the directory containing the resolved `SKILL.md`. Run it with Python 3 from the task folder, or pass `--project-root <folder>` after the command. In a Git project use the worktree root. Use the same task ID throughout (default `main`).

1. At a pause or handoff with an unresolved action, write the checkpoint in the task folder before acknowledging the pause. Honor a request to keep the discussion in chat. For a new task, run `start --request-file -` with the user's wording on stdin. Record the agreed decision and open action with `note --note '…' --next '…'`. Report it as saved only after the writes succeed.
2. To resume or change an existing task, read `show` first. Use `show --full` when the request or notes are truncated. For changed constraints, use `revise --from-revision N --request-file …` with the full effective request. A revision clears the old next action and scopes the notes to the new revision. Carry forward still-applicable decisions and set the current next action before handing over.
3. When the task is reported done, clear a resolved pending action with `note --next ''`. Use `close` for a tracking-only task. This records the operator's statement. To pause or cancel, use `set-state --state paused|cancelled --reason '…'`.

For tasks with an objective acceptance rule, declare `--verify-command '…'` at start or revision. Run `verify` on the intended inputs. Outside Git, explicitly name the files the check depends on, including its script, with repeated `--input`. Use `--require-review` when an independent judgment is part of the task agreement. `show --for-review --full` identifies the subject before review; `review --subject … --reviewer … --outcome … --file …` records the report. `finish` checks the agreed evidence and pending action. Reopen with `set-state --state active --reason '…'` if further work is needed.

Use `show` after a handoff or a genuine loss of context. One-off requests can use native Codex directly. For older phase projects, follow the project's original recovery entry point.

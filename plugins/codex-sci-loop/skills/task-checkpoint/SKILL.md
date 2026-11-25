---
name: task-checkpoint
description: "Save or resume an everyday task when the user wants a checkpoint, a handoff, or continuity across sessions."
---

# Task checkpoint

Use the user's working folder. The CLI is `../../scripts/checkpoint.py` relative to this skill. Supply the same `--task <id>` after each command (default `main`). An ordinary folder works for a checklist. In a Git project use its root.

1. To save a task, run `start --request-file <UTF-8-file-or-stdin-dash>`. Preserve the supplied wording and constraints. Use `note --note '…' --next '…'` for a meaningful decision or pending action.
2. To resume, run `show`. If the request is truncated, use `show --full`. Respect the current revision, mode and pending action. On a scope change, `revise --from-revision N --request-file …` preserves the old text and replaces the full effective request.
3. When the task is reported done, clear a resolved pending action with `note --next ''`. Use `close` for a tracking-only task. This records the operator's statement. To pause or cancel, use `set-state --state paused|cancelled --reason '…'`.

For tasks with an objective acceptance rule, declare `--verify-command '…'` at start or revision. Run `verify` on the intended inputs. Outside Git, explicitly name the files the check depends on, including its script, with repeated `--input`. Use `--require-review` when an independent judgment is part of the task agreement. `show --for-review --full` identifies the subject before review; `review --subject … --reviewer … --outcome … --file …` records the report. `finish` checks the agreed evidence and pending action. Reopen with `set-state --state active --reason '…'` if further work is needed.

Use `show` after a handoff or a genuine loss of context. One-off requests can use native Codex directly. For older phase projects, follow the project's original recovery entry point.

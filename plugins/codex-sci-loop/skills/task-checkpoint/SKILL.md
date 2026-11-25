---
name: task-checkpoint
description: "Save, revise or recover a durable project task in native Codex. Use for an explicitly requested checkpoint, a handoff or an interrupted long task with existing Sci Loop state."
---

# Task checkpoint

From this skill directory the CLI is `../../scripts/checkpoint.py`. Run it with Python 3 in the task's Git root or pass `--project-root` after the command. Use the same `--task <id>` throughout. The default ID is `main`.

- For a fresh task that needs durable state, run `start --request-file <UTF-8-file-or-stdin-dash>`. Preserve the user's exact wording, constraints and acceptance conditions from the supplied source. Identify any operator transcription. If a repeatable check is in scope, supply `--verify-command '<command>'`. Add `--require-review` if the task needs an independent review before closure. Use the default Git HEAD binding for history-dependent checks. Declare ignored research inputs with repeated `--input <relative-file>`.
- On recovery, run `show`. If the request is truncated, use `show --full`. Honor the recorded mode, current revision and pending action. For older projects with `.ai-loop/loop.config.json`, follow their existing phase protocol and instructions. Old native phase state uses `../../scripts/sci_loop.py resume --project-root <root> --json`.
- When the user changes scope, `revise --from-revision N --request-file <file-or-dash>` replaces the full effective contract and preserves old revisions. Retain still-applicable constraints. If the change is ambiguous, preserve the original and resolve the ambiguity. Use `note --kind decision --note '…' --next '…'` at meaningful changes. A note is a reported decision or observation.
- Run `verify` to execute the recorded command after inspecting it and its inputs. A current exit-zero record covers that check. If inputs changed, re-run it. For an interrupted command, inspect possible side effects first.
- Use `set-state --state paused|blocked|active|cancelled --reason '…'` for an actual change of task state. To pause a running verifier, interrupt its command first. Cancellation closes that task ID.
- Close completed work with `finish` after clearing the pending action. It checks current evidence against the contract. A changed project can reopen a recorded finish as `needs_recheck`. Reopen explicitly, then repeat the affected checks.
- Use native Codex planning, compaction and agent tools while working. Read the checkpoint after a handoff, a genuine loss of context or a scope conflict. Keep routine turns and compactions free of repeated checkpoint output.

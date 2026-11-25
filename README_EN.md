# codex-sci-loop

Use project-local checkpoints to pick up an everyday task where you left it. Native Codex handles execution, planning, compaction and delegation. The plugin exposes two skills and registers zero lifecycle hooks. macOS and Linux are the primary platforms, with secondary Windows support.

## Install

Run `./install.sh` from this checkout or use the CLI commands below. Windows users can also run `install.ps1`. Keep the registered marketplace directory available for updates.

```sh
codex plugin marketplace add .
codex plugin add codex-sci-loop@codex-sci-loop-local
```

## Daily tasks

Ask Codex to keep a checkpoint for a trip, a checklist or a writing project. The CLI at `plugins/codex-sci-loop/scripts/checkpoint.py` runs with Python 3.9+ in an ordinary task folder. In a Git project, use the worktree root. Each task has one JSON file in `.ai-loop/checkpoints/`. The default task ID is `main`.

| Command | Purpose |
| --- | --- |
| `start --request-file spec.md` | Preserve the supplied request and constraints. Use `-` to read UTF-8 from stdin. |
| `note --note '…' --next '…'` | Record a decision and the pending action. |
| `revise --from-revision N --request-file revised.md` | Replace the active contract and preserve prior versions. |
| `show` | Read the current contract, decisions, pending work and evidence. Use `--full` for the full current request. |
| `close` | Close a tracking-only task after clearing the pending action with `note --next ''`. Verification remains unverified. |
| `set-state --state paused --reason '…'` | Pause a task. Other operator states are active, blocked and cancelled. |

## Evidence when needed

For tasks with measurable acceptance conditions, declare a repeatable command with `--verify-command`. Use `verify` to execute it and `finish` to check the agreed conditions. For independent judgment add `--require-review`, obtain the subject with `show --for-review --full`, and submit a report using `review`. Changed evidence can reopen a finished task as `needs_recheck`.

In an ordinary folder, declare every relevant file including the verifier script using repeated `--input`. Git projects additionally bind the worktree, index and normally HEAD. Operators are responsible for undeclared dependencies, review attribution and the accuracy of the supplied request.

The research-verification skill applies when evaluating a scientific claim. It helps choose an appropriate check and interpret what the evidence supports. Routine tasks use the general checkpoint skill.

For an old Python phase project, use `sci_loop.py resume --project-root <root> --json` for read-only recovery. Older PowerShell projects retain their toolkit under `loop-standard/`.

[Chinese guide](README.md) · [Architecture and test results](docs/native-codex-review.md)

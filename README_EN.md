# codex-sci-loop

Version `1.4.0-alpha.1`. Use project-local checkpoints to pick up an everyday task where you left it. Native Codex handles execution, planning, compaction and delegation. The plugin exposes two skills and registers zero lifecycle hooks. macOS and Linux are the primary platforms, with secondary Windows support.

## Install

Run `./install.sh` from this checkout or use the CLI commands below. Windows users can also run `install.ps1`. Keep the registered marketplace directory available for updates.

```sh
codex plugin marketplace add .
codex plugin add codex-sci-loop@codex-sci-loop-local
```

## Share updates between chats

Open the same local project directory or Git worktree in both chats. This works between two Codex chats or with the [OpenCode long-conversation-loop plugin](https://github.com/CASTAR001/opencodex/tree/main/projects/long-conversation-loop) version 0.2.0-alpha.1 or compatible.

Ask each chat to join the same task under a different alias. Once both have joined, ask each to pair with the other. You can then leave a question, close a chat, and pick up the reply later. By default the mailbox carries explicit messages. When pairing, the owner can choose to share fields from a bound checkpoint, such as its next action or artifact references.

The first join creates `.ai-loop/exchange/v1/mailbox.sqlite3`. Use a local disk and Python 3 with SQLite. Normal installation provides manual sync. A trusted project-specific SessionStart hook can optionally call the installed `scripts/exchange.py --codex-hook` with Python to notify a resumed or compacted chat. The hook emits a fixed reminder and the chat retrieves message contents through sync. [Cross-platform checks](https://github.com/CASTAR001/codex-sci-loop/actions/runs/46139614537)

## Daily tasks

When you pause an ongoing project with an open action, Codex can save the decisions and next step in your task folder. For example, leave a moving plan pending a second quote, then point a fresh chat to the same folder and ask what comes next. The CLI at `plugins/codex-sci-loop/scripts/checkpoint.py` runs with Python 3.9+ in an ordinary task folder. In a Git project, use the worktree root. Each task has one JSON file in `.ai-loop/checkpoints/`. The default task ID is `main`.

| Command | Purpose |
| --- | --- |
| `start --request-file spec.md` | Preserve the supplied request and constraints. Use `-` to read UTF-8 from stdin. |
| `note --note '…' --next '…'` | Record a decision and the pending action. |
| `revise --from-revision N --request-file revised.md` | Replace the active contract and preserve prior versions. |
| `note --kind action --note '…' --artifact result.txt` | Record a completed action and observe the file’s size and SHA-256. The same flags plus `--next` work on `start` and `revise` in one write. |
| `history --limit 5` | Read revisions with past actions, decisions, pending changes and evidence. Continue with `--before N` or use `--revision N --full`. |
| `show` | Read the current contract, decisions, pending work and evidence. Use `--full` for the full current request. |
| `close` | Close a tracking-only task after clearing the pending action with `note --next ''`. Verification remains unverified. |
| `set-state --state paused --reason '…'` | Pause a task. Other operator states are active, blocked and cancelled. |

For a long-running project, its existing Codex instructions can ask for checkpoints at material changes, completed milestones and pauses with an open action. Point a new chat to that project. Implicit skill selection can miss a pause. A successful write makes the recorded facts available to later chats.

## Evidence when needed

For tasks with measurable acceptance conditions, declare a repeatable command with `--verify-command`. Use `verify` to execute it and `finish` to check the agreed conditions. For independent judgment add `--require-review`, obtain the subject with `show --for-review --full`, and submit a report using `review`. Changed evidence can reopen a finished task as `needs_recheck`.

In an ordinary folder, declare every relevant file including the verifier script using repeated `--input`. Git projects additionally bind the worktree, index and normally HEAD. Operators are responsible for undeclared dependencies, review attribution and the accuracy of the supplied request.

The research-verification skill applies when evaluating a scientific claim. It helps choose an appropriate check and interpret what the evidence supports. Routine tasks use the general checkpoint skill.

For an old Python phase project, use `sci_loop.py resume --project-root <root> --json` for read-only recovery. Older PowerShell projects retain their toolkit under `loop-standard/`.

[Chinese guide](README.md) · [Architecture and test results](docs/native-codex-review.md)

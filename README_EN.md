# codex-sci-loop

Sci Loop gives native Codex on macOS and Linux an opt-in, project-local checkpoint for long tasks. Windows is a secondary platform. Codex owns planning, execution, compaction and subagents. The plugin exposes two skills and registers zero lifecycle hooks in a normal installation.

## Install

Run `./install.sh` from this checkout on macOS or Linux, or use the Codex CLI directly. Keep the registered marketplace directory available for future updates.

```sh
codex plugin marketplace add .
codex plugin add codex-sci-loop@codex-sci-loop-local
```

In a new session, ask Codex to save a task checkpoint or resume one. Windows users can use the same Codex commands or `install.ps1`.

## Checkpoints

The CLI at `plugins/codex-sci-loop/scripts/checkpoint.py` requires Python 3.9+ and Git. Run it in the target Git root. Commands accept `--project-root` and `--task` after the action. Each task owns one JSON file under `.ai-loop/checkpoints/`. A shared process lock serializes updates.

| Action | Result |
| --- | --- |
| `start --request-file spec.md --verify-command 'bash tests/check.sh'` | Saves the complete effective request. Optional `--input file` binds ignored data and `--require-review` sets a review condition. |
| `revise --from-revision N --request-file revised.md` | Preserves previous versions and replaces the active contract. Old verification becomes stale. |
| `note --kind decision --note '…' --next '…'` | Records an attributed statement and the pending action. Hypotheses and ruled-out approaches have separate kinds. |
| `verify` | Runs the declared command, hashes the relevant workspace and captures the exit code, input hashes, output hash and last 8 KiB. |
| `show` | Recovers the effective contract, current notes, pending action, verification and review freshness. Use `--full` for the complete current request. |
| `show --for-review --full` | Identifies a review subject for an independent reader. Submit the report with `review --subject … --reviewer … --outcome … --file …`. |
| `finish` | Requires current evidence and an empty pending action. A changed subject can reopen a recorded finish as `needs_recheck`. |
| `set-state --state paused --reason '…'` | Records an operator transition. Other choices are active, blocked and cancelled. |

By default, verification binds Git HEAD. Declare `--tree-only` only when the check is independent of commit identity and history. Local checks assume cooperating writers. Review attribution relies on the operator. External services, undeclared ignored files and machine-specific environments need their own provenance. Keep long-lived measurements, significant failed experiments and primary evidence in their project locations.

## Existing projects

Existing phase projects keep their original state and recovery tools. The legacy Python CLI is `sci_loop.py`. The PowerShell toolkit lives under `loop-standard/`. The managed signed-receipt integration requires an explicitly configured, recertified host and has no default lifecycle registration.

[Chinese guide](README.md) · [Architecture review and test results](docs/native-codex-review.md)

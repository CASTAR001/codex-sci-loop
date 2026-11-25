# Codex Scientific Loop

For long tasks in a native Codex session, use `task-checkpoint` to capture the effective request and recover project state. Use `research-verification` for repeatable checks and independent review. The installed package declares no automatic lifecycle hooks.

Run `python3 scripts/checkpoint.py --help` from this package to see the CLI. In a target Git project use the absolute script path with `start --request-file …`, `show`, `verify` or `finish`. The checkpoint is operator-writable. A passing command supports the property it actually tested. Record assumptions and review any broader claim separately.

## Older phase projects

`scripts/sci_loop.py` reads native v1 phase state. Old evidence without a verification binding needs a fresh `collect` and `audit-pack` for a new signed decision. A recorded terminal decision is historical. A compatible host can recheck it using `audit_protocol.py gate` and the original protected receipt.

Managed integration assets include the explicit template `adapters/lumiforge/hooks.json`, its reviewer skill under `adapters/lumiforge/skills/`, the adapter executable under `hooks/`, and the signed audit and capability protocols. A host projecting these assets must certify the final projected tree and enforce its own external write boundary. The ordinary Codex installation has no signing authority. Host operation and PowerShell project migration are outside the checkpoint workflow.

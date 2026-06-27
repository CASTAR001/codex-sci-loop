# External Worker Protocol

The loop harness is Worker-agnostic. Codex may supervise Kimi Code, another
agent CLI, or a local Worker process, but every external invocation must pass
through a recorded preflight.

## Preflight Decisions

- `SAFE_TO_INVOKE`: the invocation can run automatically.
- `NEEDS_USER_APPROVAL`: the Supervisor must stop and get user confirmation
  before invoking the Worker.
- `BLOCKED`: the invocation must not run until the blocker is resolved.

## What Preflight Records

- Project root, phase ID, Worker profile, prompt path, and prompt SHA256.
- Whether the Worker uses an external service.
- Whether yolo mode is enabled.
- Worker state root and state environment variable.
- Project skill directory.
- Prompt risk hits such as secrets, `.env`, credentials, or private keys.
- Current git status summary.
- Final decision and reasons.

## Confirmation Rules

- External service invocation requires explicit approval per invocation.
- Sensitive prompt content requires explicit approval per invocation.
- Yolo mode is allowed without a separate confirmation, but must be recorded.
- Long-term memory or governance upgrades discovered during Worker use require
  a separate confirmation before being promoted.

## Kimi Code

The first Worker profile is `kimi-code`. It uses `kimi.cmd`, supports
`--skills-dir`, and can use `KIMI_CODE_HOME` to keep runtime state out of
`~/.kimi-code`.

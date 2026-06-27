# Worker Profile: kimi-code

This profile describes how the generic external Worker protocol invokes Kimi
Code. The harness must not treat Kimi as the only Worker; this file is only one
thin adapter profile.

## Invocation

- Command: `kimi.cmd`
- Prompt argument: `-p`
- Skill directory argument: `--skills-dir`
- Yolo argument: `-y`
- State environment variable: `KIMI_CODE_HOME`
- Default project-local state root: `.ai-loop/runtime/kimi-code`

## Policy

- Kimi is an external Worker service, so the preflight decision is
  `NEEDS_USER_APPROVAL` unless the caller explicitly records
  `-AllowExternalService`.
- `-Yolo` may be used without an additional stop-for-user confirmation, but it
  must be recorded in the preflight and invocation logs.
- Long-term memory or governance upgrades learned from Kimi behavior require a
  separate user confirmation before being promoted.

## Known Facts

- `--prompt` / `-p` cannot be combined with `--auto`.
- `--skills-dir` can load project-local `.agents/skills`.
- If `KIMI_CODE_HOME` is not set, Kimi falls back to `~/.kimi-code`.

# Worker Profile: claude-mimo

This profile invokes the server-local `claude-mimo` command, which is already
configured to use the LiteLLM service listening on `127.0.0.1:4000`.

## Invocation

- Command: `claude-mimo`
- Prompt argument: `-p`
- Base argument: `--no-session-persistence`
- Yolo argument: `--dangerously-skip-permissions`
- Default runtime path recorded by the harness: `.ai-loop/runtime/claude-mimo`

The harness deliberately does not copy, inspect, or override Claude/LiteLLM
credentials or configuration. Authentication and endpoint routing remain owned
by the existing `claude-mimo` wrapper.

## Policy

- The model request leaves the loop process through LiteLLM, so the profile is
  treated as an external service and requires `-AllowExternalService`.
- Project skills are discovered by Claude Code from the project; this adapter
  does not pass a separate skill directory argument.
- `-Yolo` enables `--dangerously-skip-permissions` and is always recorded in
  phase evidence.

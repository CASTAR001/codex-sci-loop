# External Workers

This project uses a Worker-agnostic external invocation protocol. External
Worker calls must pass through a recorded preflight before invocation.

Yolo mode may be enabled without a separate confirmation. External service use,
sensitive prompt content, and long-term memory or governance upgrades require
explicit user confirmation before being promoted or executed.

Runtime state belongs under `.ai-loop/runtime/` and is ignored by git.

# External Workers

This directory stores project-local policy notes for external Worker
invocation. Runtime state is not stored here; `.ai-loop/runtime/` is ignored by
git.

External Worker calls must pass through a preflight review before invocation.
The preflight writes phase-local evidence under `.ai-loop/runs/<phase-id>/`.

Yolo mode may be enabled without a separate confirmation, but external service
use, sensitive prompt content, and long-term memory/governance upgrades require
explicit user confirmation.

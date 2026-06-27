# Schema Migration Log

This log records control-plane schema changes for project-local `.ai-loop/`
directories. It is human-readable governance; the machine-readable compatibility
policy lives in `schema-version.json`.

## 1.2

- Added evidence artifact integrity manifest and hash validation.
- Added skill source maps and Worker-agnostic external invocation metadata.
- Added loop-wide validation through `validate-loop.ps1`.
- Added schema manifest and migration log as required control-plane files.

Migration status: current.

## 1.1

- Added durable status state with phase list, current phase, and last decision.
- Kept status schema version separate from control-plane schema version.

Migration status: supported status format.

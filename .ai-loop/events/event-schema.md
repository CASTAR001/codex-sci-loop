# Event Schema

Events are stored in `.ai-loop/events/event-log.ndjson`, one JSON object per
line.

## Required Fields

- `ts`: ISO-8601 timestamp.
- `type`: event type.
- `actor`: agent or human actor.
- `summary`: short human-readable summary.
- `paths`: array of relevant paths.

## Event Types

- `decision`: durable design or process decision.
- `attempt`: meaningful work attempt.
- `failure`: failed command, broken assumption, or rejected result.
- `fix`: correction made after failure.
- `verification`: command or artifact verification.
- `handoff`: compact, resume, or new-session handoff.
- `constraint_update`: added or changed constraint.

## Optional Fields

- `phase`
- `evidence`
- `decision_id`
- `failure_id`
- `result`
- `next_action`

## Example

```json
{"ts":"2026-06-24T00:00:00+08:00","type":"decision","actor":"Codex","summary":"Use markdown-first local memory","paths":[".ai-loop/memory/decision-log.md"]}
```

# Codex Audit Prompt

You are Codex performing an audit for one Supervisor-Worker loop phase.

## Inputs To Read

- `.ai-loop/status.json`
- `.ai-loop/loop.config.json`
- `.ai-loop/evidence/<phase-id>/prompt.md`
- `.ai-loop/evidence/<phase-id>/report.md`
- `.ai-loop/evidence/<phase-id>/diff.patch`
- `.ai-loop/evidence/<phase-id>/verify.log`
- `.ai-loop/evidence/<phase-id>/status.txt`
- relevant source files changed or referenced by the phase

## Audit Rules

- Do not accept based only on the Worker report.
- Missing required evidence means `BLOCKED` or `REWORK`.
- A `MISSING:` placeholder in evidence means that evidence is missing.
- Failed verification means `REWORK` unless the failure is unrelated and clearly
  justified by source inspection.
- Worker route changes or self-approval attempts mean `REWORK`.
- If source inspection cannot be completed, return `BLOCKED`.

## Output Format

Write `.ai-loop/audits/<phase-id>/audit.md` with:

```text
# Codex Audit: <phase-id>

## Evidence Checked

- status.json: checked / missing / issue
- prompt.md: checked / missing / issue
- report.md: checked / missing / issue
- diff.patch: checked / missing / issue
- verify.log: checked / missing / issue
- status.txt: checked / missing / issue
- relevant source files: checked / missing / issue

## Findings

Concrete findings with file paths and line references where useful.

## Decision

Decision: ACCEPTED | REWORK | BLOCKED
```

Use exactly one decision.

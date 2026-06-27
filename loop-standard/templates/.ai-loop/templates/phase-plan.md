# Phase Plan Template

## Phase

- Phase ID:
- Title:
- Objective:
- Task kind:
- Skill profile:

## Scope

- Files/directories allowed:
- Files/directories forbidden:

## Verification

```powershell

```

## Required Evidence

- `.ai-loop/runs/<phase-id>/prompt.md`
- `.ai-loop/runs/<phase-id>/report.md`
- `.ai-loop/runs/<phase-id>/diff.patch`
- `.ai-loop/runs/<phase-id>/verify.log`
- `.ai-loop/runs/<phase-id>/changed_files.txt`
- `.ai-loop/runs/<phase-id>/phase_requirements.json`

## Acceptance

Codex must inspect report, diff, verify log, status, artifact manifest, changed
files, and relevant source before writing `ACCEPTED`, `REWORK`, or `BLOCKED`.

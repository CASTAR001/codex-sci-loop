# Phase 001 Acceptance Criteria

Codex may accept phase 001 only if all criteria below are satisfied.

## Required Business Result

- `src/greeting.txt` contains `message=hello`.
- `src/greeting.txt` contains `phase=worker-complete`.
- `src/greeting.txt` no longer contains `phase=baseline`.
- No business file other than `src/greeting.txt` was changed.

## Required Verification

The verification log must show this command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\verify.ps1 -ExpectedPhase worker-complete
```

The verification log must show exit code `0` and output containing:

```text
verify: OK
phase: worker-complete
```

## Required Evidence

All files must exist:

- `.ai-loop/runs/phase-001/prompt.md`
- `.ai-loop/prompts/phase-001-kimi-prompt.md`
- `.ai-loop/context/phase-001-context.md`
- `.ai-loop/runs/phase-001/report.md`
- `.ai-loop/runs/phase-001/status_after.txt`
- `.ai-loop/runs/phase-001/diff.patch`
- `.ai-loop/runs/phase-001/verify.log`
- `.ai-loop/runs/phase-001/changed_files.txt`

None may contain a `MISSING:` placeholder.

## Required Audit Behavior

Codex must inspect the report, diff, verify log, status files, changed file
list, and `src/greeting.txt`. Codex must not accept based only on the Kimi
report.

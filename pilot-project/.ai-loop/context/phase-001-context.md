# Phase 001 Context Package

## Discovery

Project root:

`E:\codexfiles\loop\pilot-project`

This pilot project is intentionally tiny:

- `src/greeting.txt` is the only business file.
- `tests/verify.ps1` is the Windows PowerShell verification script.
- `.ai-loop/` stores durable loop state and evidence.

Current baseline business state:

```text
message=hello
phase=baseline
```

## Triage

The smallest useful Worker task is to change only the phase marker in
`src/greeting.txt`:

```text
phase=baseline
```

to:

```text
phase=worker-complete
```

Do not change `message=hello`. Do not change the verification script. Do not
change loop-standard files.

## Execution

Kimi Code may edit only:

- `src/greeting.txt`

Kimi must write its report to:

- `.ai-loop/runs/phase-001/report.md`

## Verification

The required verification command is:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\verify.ps1 -ExpectedPhase worker-complete
```

After writing the report, Kimi must collect evidence with:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\collect-evidence.ps1 -ProjectRoot E:\codexfiles\loop\pilot-project -PhaseId phase-001
```

That script must produce:

- `.ai-loop/runs/phase-001/status_after.txt`
- `.ai-loop/runs/phase-001/diff.patch`
- `.ai-loop/runs/phase-001/verify.log`
- `.ai-loop/runs/phase-001/changed_files.txt`

## Memory / Audit

Codex will later prepare the audit pack and inspect:

- `.ai-loop/runs/phase-001/prompt.md`
- `.ai-loop/prompts/phase-001-kimi-prompt.md`
- `.ai-loop/context/phase-001-context.md`
- `.ai-loop/runs/phase-001/report.md`
- `.ai-loop/runs/phase-001/diff.patch`
- `.ai-loop/runs/phase-001/verify.log`
- `.ai-loop/runs/phase-001/status_before.txt`
- `.ai-loop/runs/phase-001/status_after.txt`
- `.ai-loop/runs/phase-001/changed_files.txt`
- `src/greeting.txt`

If any evidence is missing or contains `MISSING:`, Codex must decide `BLOCKED`
or `REWORK`, not `ACCEPTED`.

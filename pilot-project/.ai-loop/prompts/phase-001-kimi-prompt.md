# Kimi Code Prompt: phase-001

You are Kimi Code acting as Worker in a Supervisor-Worker coding loop.

Codex is Supervisor. You may execute only the current phase. You must not decide
the total route, create future phases, or approve your own work.

## Project Root

Work only inside:

```text
E:\codexfiles\loop\pilot-project
```

Do not modify files outside that directory.

## Discovery

Read these files first:

- `.ai-loop/context/phase-001-context.md`
- `.ai-loop/prompts/phase-001-acceptance.md`
- `.ai-loop/runs/phase-001/phase_meta.json`
- `README.md`
- `src/greeting.txt`
- `tests/verify.ps1`

The project is a tiny text-and-PowerShell pilot. The only business file is
`src/greeting.txt`.

## Triage

The phase objective is intentionally tiny:

Change only `src/greeting.txt` so this line:

```text
phase=baseline
```

becomes:

```text
phase=worker-complete
```

Keep this line unchanged:

```text
message=hello
```

Do not edit `tests/verify.ps1`, `.ai-loop/loop.config.json`,
`.ai-loop/status.json`, or any file in `E:\codexfiles\loop\loop-standard`.

## Execution

1. Edit only `src/greeting.txt`.
2. Write a Worker report to:

```text
.ai-loop/runs/phase-001/report.md
```

The report must include:

- summary of the change;
- files changed;
- verification command and result;
- risks or gaps;
- statement that you executed only this phase and did not approve it.

## Verification

Run this command from `E:\codexfiles\loop\pilot-project`:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\verify.ps1 -ExpectedPhase worker-complete
```

After the report exists, collect durable evidence by running:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\collect-evidence.ps1 -ProjectRoot E:\codexfiles\loop\pilot-project -PhaseId phase-001
```

This must produce:

- `.ai-loop/runs/phase-001/status_after.txt`
- `.ai-loop/runs/phase-001/diff.patch`
- `.ai-loop/runs/phase-001/verify.log`
- `.ai-loop/runs/phase-001/changed_files.txt`

## Memory / Audit

Do not mark the phase accepted. Codex will later inspect:

- your report;
- `diff.patch`;
- `verify.log`;
- `status_before.txt`;
- `status_after.txt`;
- `changed_files.txt`;
- `src/greeting.txt`;
- acceptance criteria.

If anything fails, record it honestly in the report. Do not hide missing
evidence or skipped verification.

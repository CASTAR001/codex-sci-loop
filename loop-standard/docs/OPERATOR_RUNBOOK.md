# Supervisor-Worker Operator Runbook

This runbook is the shortest safe operating procedure for the Codex Supervisor
and Kimi Code Worker loop.

## 1. Discovery

Codex reads:

- project files needed for the phase;
- `.ai-loop/status.json`;
- prior run evidence if present.

Codex writes durable context and a bounded Kimi prompt. Do not rely on chat
history as the source of truth.

## 2. Triage

Codex defines one small phase. The phase must include:

- scope;
- exact verification command;
- required report path;
- acceptance criteria;
- what Kimi must not change.

## 3. Execution

Kimi edits only the allowed files and writes:

```text
.ai-loop/runs/<phase-id>/report.md
```

Kimi does not approve the phase and does not decide the route.

## 4. Verification

Kimi or Codex runs:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\collect-evidence.ps1 -ProjectRoot <project> -PhaseId <phase-id>
```

Required evidence:

- `status_after.txt`
- `diff.patch`
- `verify.log`
- `changed_files.txt`
- `changed_business_files.txt`
- `changed_evidence_files.txt`

## 5. Memory / Audit

Codex runs:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\prepare-audit-pack.ps1 -ProjectRoot <project> -PhaseId <phase-id>
```

Codex then inspects report, diff, verify log, status files, changed file lists,
and relevant source files. Codex writes exactly one decision:

```text
Decision: ACCEPTED
```

or:

```text
Decision: REWORK
```

or:

```text
Decision: BLOCKED
```

Run `accept-phase.ps1` only after an `ACCEPTED` audit.

## Failure Policy

Use `BLOCKED` or `REWORK` when:

- required evidence is missing;
- any evidence contains `MISSING:`;
- verification failed;
- Kimi changed files outside the phase scope;
- Codex cannot inspect relevant source files.

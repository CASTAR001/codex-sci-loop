# Pilot Project

This is a tiny text-and-PowerShell project for testing the
Supervisor-Worker loop.

## Baseline Verification

Run from the project root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\verify.ps1
```

## Phase 001 Target Verification

After Kimi completes phase 001, run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\verify.ps1 -ExpectedPhase worker-complete
```

The phase 001 task should only change `src/greeting.txt`.

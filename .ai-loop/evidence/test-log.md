# Test Log

Record test, build, lint, typecheck, simulation, or validation outputs that
support a phase decision.

| Test ID | Phase | Command | Output Path | Exit Code | Status | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| TEST-BOOTSTRAP-001 | harness | manual template creation | .ai-loop/evidence/test-log.md | 0 | recorded | Test log initialized. |

| TEST-phase-001-VERIFY | phase-001 | powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-LoopStandard.ps1 -AllowPilotProject | .ai-loop/runs/phase-001/verify.log | 0 | passed | Primary phase verification. |

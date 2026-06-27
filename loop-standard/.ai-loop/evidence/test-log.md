# Test Log

| Test ID | Phase | Command | Output Path | Exit Code | Status | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| TEST-BOOTSTRAP-001 | harness | template initialization | .ai-loop/evidence/test-log.md | 0 | recorded | Test log initialized. |

| TEST-phase-002-VERIFY | phase-002 | powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-LoopStandard.ps1 -AllowPilotProject | .ai-loop/runs/phase-002/verify.log | 0 | passed | Primary phase verification. |
| TEST-phase-003-VERIFY | phase-003 | powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-LoopStandard.ps1 -AllowPilotProject | .ai-loop/runs/phase-003/verify.log | 0 | passed | Primary phase verification. |

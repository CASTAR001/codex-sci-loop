# Command Log

| Command ID | Phase | Purpose | Command | Exit Code | Output Path | Status | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| CMD-BOOTSTRAP-001 | harness | initialize-ledger | template initialization | 0 | .ai-loop/evidence/command-log.md | recorded | Command log initialized. |

| CMD-phase-002-VERIFY | phase-002 | verification | powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-LoopStandard.ps1 -AllowPilotProject | 0 | .ai-loop/runs/phase-002/verify.log | passed | Verification command executed by collect-evidence.ps1. |
| CMD-phase-003-VERIFY | phase-003 | verification | powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-LoopStandard.ps1 -AllowPilotProject | 0 | .ai-loop/runs/phase-003/verify.log | passed | Verification command executed by collect-evidence.ps1. |

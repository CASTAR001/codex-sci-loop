# Command Log

Record commands that produce verification, build, test, audit, provenance, or
gate evidence.

| Command ID | Phase | Purpose | Command | Exit Code | Output Path | Status | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| CMD-BOOTSTRAP-001 | harness | initialize-ledger | manual template creation | 0 | .ai-loop/evidence/command-log.md | recorded | Command log initialized. |

| CMD-phase-001-VERIFY | phase-001 | verification | powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-LoopStandard.ps1 -AllowPilotProject | 0 | .ai-loop/runs/phase-001/verify.log | passed | Verification command executed by collect-evidence.ps1. |
| CMD-phase-002-VERIFY | phase-002 | verification | & '.\loop-standard\scripts\Test-LoopStandard.ps1' -AllowPilotProject; if (-not $?) { exit 1 }; & '.\loop-standard\scripts\Test-PluginInstall.ps1'; if (-not $?) { exit 1 }; exit 0 | 0 | .ai-loop/runs/phase-002/verify.log | passed | Verification command executed by collect-evidence.ps1. |
| CMD-phase-003-VERIFY | phase-003 | verification | & '.\loop-standard\scripts\Test-LoopStandard.ps1' -AllowPilotProject; if (-not $?) { exit 1 }; & '.\loop-standard\scripts\Test-PluginInstall.ps1'; if (-not $?) { exit 1 }; & '.\loop-standard\scripts\validate-loop.ps1' -ProjectRoot .; if (-not $?) { exit 1 }; exit 0 | 0 | .ai-loop/runs/phase-003/verify.log | passed | Verification command executed by collect-evidence.ps1. |
| CMD-phase-004-VERIFY | phase-004 | verification | powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-Phase004.ps1 | 0 | .ai-loop/runs/phase-004/verify.log | passed | Verification command executed by collect-evidence.ps1. |

# Test Log

Record test, build, lint, typecheck, simulation, or validation outputs that
support a phase decision.

| Test ID | Phase | Command | Output Path | Exit Code | Status | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| TEST-BOOTSTRAP-001 | harness | manual template creation | .ai-loop/evidence/test-log.md | 0 | recorded | Test log initialized. |

| TEST-phase-001-VERIFY | phase-001 | powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-LoopStandard.ps1 -AllowPilotProject | .ai-loop/runs/phase-001/verify.log | 0 | passed | Primary phase verification. |
| TEST-phase-002-VERIFY | phase-002 | & '.\loop-standard\scripts\Test-LoopStandard.ps1' -AllowPilotProject; if (-not $?) { exit 1 }; & '.\loop-standard\scripts\Test-PluginInstall.ps1'; if (-not $?) { exit 1 }; exit 0 | .ai-loop/runs/phase-002/verify.log | 0 | passed | Primary phase verification. |
| TEST-phase-003-VERIFY | phase-003 | & '.\loop-standard\scripts\Test-LoopStandard.ps1' -AllowPilotProject; if (-not $?) { exit 1 }; & '.\loop-standard\scripts\Test-PluginInstall.ps1'; if (-not $?) { exit 1 }; & '.\loop-standard\scripts\validate-loop.ps1' -ProjectRoot .; if (-not $?) { exit 1 }; exit 0 | .ai-loop/runs/phase-003/verify.log | 0 | passed | Primary phase verification. |
| TEST-phase-004-VERIFY | phase-004 | powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-Phase004.ps1 | .ai-loop/runs/phase-004/verify.log | 0 | passed | Primary phase verification. |
| TEST-phase-005-VERIFY | phase-005 | powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-Phase005.ps1 | .ai-loop/runs/phase-005/verify.log | 0 | passed | Primary phase verification. |

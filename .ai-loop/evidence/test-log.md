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
| TEST-phase-006-VERIFY | phase-006 | powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-Phase006.ps1 | .ai-loop/runs/phase-006/verify.log | 0 | passed | Primary phase verification. |
| TEST-phase-007-VERIFY | phase-007 | powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-Phase007.ps1 | .ai-loop/runs/phase-007/verify.log | 0 | passed | Primary phase verification. |
| TEST-phase-008-VERIFY | phase-008 | powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-Phase008.ps1 | .ai-loop/runs/phase-008/verify.log | 0 | passed | Primary phase verification. |
| TEST-phase-009-VERIFY | phase-009 | powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-Phase009.ps1 | .ai-loop/runs/phase-009/verify.log | 0 | passed | Primary phase verification. |
| TEST-phase-010-VERIFY | phase-010 | powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-Phase010.ps1 | .ai-loop/runs/phase-010/verify.log | 0 | passed | Primary phase verification. |
| TEST-phase-011-VERIFY | phase-011 | powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-Phase011.ps1 | .ai-loop/runs/phase-011/verify.log | 0 | passed | Primary phase verification. |
| TEST-phase-012-VERIFY | phase-012 | powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-Phase012.ps1 | .ai-loop/runs/phase-012/verify.log | 0 | passed | Primary phase verification. |
| TEST-phase-013-VERIFY | phase-013 | powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-Phase013.ps1 | .ai-loop/runs/phase-013/verify.log | 0 | passed | Primary phase verification. |

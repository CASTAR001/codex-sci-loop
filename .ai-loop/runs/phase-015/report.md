# Phase 015 Report

## Summary

Implemented structured audit finding extraction for durable `REWORK` and
`BLOCKED` decision workflows.

## Changes

- Added `extract-audit-findings.ps1` to parse audit files into
  `.ai-loop/audits/<phase>-findings.json`.
- Exposed `ai-loop -Command extract-audit-findings`.
- Updated `decide-phase.ps1` so non-accepted decisions generate findings JSON
  and record it in phase metadata, status, last decision, event evidence, and
  transition paths.
- Updated `scaffold-rework-phase.ps1` so REWORK follow-up prompts prefer
  structured findings JSON and preserve finding IDs, severities, required
  fixes, evidence, and file scope in `rework_source.json`.
- Updated `validate-loop.ps1` so terminal `rework` and `blocked` phases require
  audit findings JSON.
- Added `Test-AuditFindingExtraction.ps1` and `Test-Phase015.ps1`.
- Updated README, loop-standard docs, and plugin skills to describe structured
  audit findings.

## Verification

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\Test-Phase015.ps1
```

Result: passed.

# Phase phase-011 Report

## Summary

Implemented per-run temporary directory isolation for PowerShell smoke and
fixture tests. Tests still use ignored `.tmp-ai-loop-*` parent directories, but
default runs now write into unique `run-<timestamp>-<pid>-<id>` children.

## Changes

- Added `loop-standard/scripts/test-temp-root.ps1` with
  `New-LoopTestTempRoot`.
- Updated fixture tests that previously reused fixed `.tmp-ai-loop-*` roots.
- Updated `Test-PluginInstall.ps1` so its default install root is per-run while
  preserving explicit `-InstallRoot` behavior.
- Added `Test-TempIsolation.ps1` to run two plugin install smoke tests in
  parallel and assert that their install roots differ.
- Added `Test-Phase011.ps1` as the verification matrix for this phase.
- Updated README files with the per-run temp directory policy.

## Verification

- `Test-TempIsolation.ps1`: passed.
- `Test-LoopStandard.ps1 -AllowPilotProject`: passed.
- `Test-Phase011.ps1`: passed.
- `AI_LOOP_TEST_RUN_ID=fixed-run; Test-TempIsolation.ps1`: passed, proving
  fixed external run prefixes still produce distinct per-process roots.

## Notes

No external Worker agent was called. This phase addresses a real contention
observed when evidence collection and the phase test matrix were run at the
same time.

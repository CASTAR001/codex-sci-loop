# Worker Report: phase-003

## Summary

Updated `collect-evidence.ps1` so changed files are normalized relative to the
selected `ProjectRoot` before splitting them into business and evidence files.
This prevents `.ai-loop/*` evidence files from being classified as business
files when the project root is a subdirectory inside a larger git repository.

## Changed Files

- `scripts/collect-evidence.ps1`
- `scripts/Test-LoopStandard.ps1`

## Commands Run

```text
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-LoopStandard.ps1 -AllowPilotProject
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\ai-loop.ps1 doctor
git diff --check
```

## Verification Result

All pre-collection verification commands passed. The final classification check
will be verified by the phase evidence files generated during collection.

## Boundary Statement

This phase changes only changed-file classification and self-check coverage. It
does not change gate decisions, artifact hashing, or acceptance semantics.

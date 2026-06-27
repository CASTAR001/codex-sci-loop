# Audit Result: phase-003

Decision: ACCEPTED

## Reason

The phase fixed changed-file classification for subdirectory project roots.
`collect-evidence.ps1` now strips the git `--show-prefix` from changed paths
before writing `changed_files.txt`, `changed_business_files.txt`, and
`changed_evidence_files.txt`.

## Evidence Checked

- `.ai-loop/runs/phase-003/report.md`: describes the classification fix.
- `.ai-loop/runs/phase-003/verify.log`: `Test-LoopStandard.ps1
  -AllowPilotProject` passed with exit code 0.
- `.ai-loop/runs/phase-003/changed_files.txt`: paths are now relative to
  `loop-standard`, not the repository root.
- `.ai-loop/runs/phase-003/changed_business_files.txt`: contains only
  `scripts/collect-evidence.ps1` and `scripts/Test-LoopStandard.ps1`.
- `.ai-loop/runs/phase-003/changed_evidence_files.txt`: contains only
  `.ai-loop/*` evidence/status files.
- `.ai-loop/audits/phase-003-audit-input.md`: Artifact Integrity Summary shows
  all required evidence checks as `OK`.

## Source Inspection

`scripts/collect-evidence.ps1` adds `ConvertTo-ProjectRelativeGitPath`, reads
`git rev-parse --show-prefix`, and normalizes changed file paths before
classification. `scripts/Test-LoopStandard.ps1` now checks that the
classification helper and expected evidence/business file outputs remain wired.

## Notes

This phase improves audit quality for subdirectory project roots such as
`loop-standard`, where git reports paths relative to the repository root.

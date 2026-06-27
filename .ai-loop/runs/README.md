# Runs

Each phase gets one run directory:

```text
runs/<phase-id>/
  base_commit.txt
  status_before.txt
  phase_meta.json
  prompt.md
  report.md
  status_after.txt
  diff.patch
  verify.log
  changed_files.txt
  changed_business_files.txt
  changed_evidence_files.txt
```

Missing files or files containing `MISSING:` are blocking evidence defects.

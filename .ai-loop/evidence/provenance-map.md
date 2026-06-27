# Provenance Map

Track data, figure, table, generated artifact, and decision provenance. For
scientific results, final artifacts must trace to source data, commands, hashes,
or direct verification records.

| Provenance ID | Phase | Artifact | Source Inputs | Producing Command | Hash Or Commit | Status | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| PROV-BOOTSTRAP-001 | harness | .ai-loop/evidence/provenance-map.md | local template | manual template creation | git-tracked | recorded | Provenance map initialized. |

| PROV-phase-001-DIFF | phase-001 | .ai-loop/runs/phase-001/diff.patch | .ai-loop/runs/phase-001/base_commit.txt; .ai-loop/runs/phase-001/status_after.txt | git diff | base commit recorded | recorded | Diff provenance for phase audit. |

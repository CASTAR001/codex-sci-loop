# Evidence Ledger

This ledger maps phase claims to durable evidence. Evidence must be a real file,
command, log, test output, provenance record, or source inspection record.

| Evidence ID | Phase | Claim ID | Type | Path or Command | Produced By | Verified By | Status | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| EVD-BOOTSTRAP-001 | harness | CLAIM-BOOTSTRAP | bootstrap | .ai-loop/evidence/evidence-ledger.md | Codex | Codex | recorded | Ledger initialized for evidence-gated loop work. |

| EVD-phase-001-001 | phase-001 | CLAIM-phase-001 | prompt | .ai-loop/runs/phase-001/prompt.md | Codex Supervisor | pending | recorded | Worker prompt generated. |
| EVD-phase-001-002 | phase-001 | CLAIM-phase-001 | requirements | .ai-loop/runs/phase-001/phase_requirements.json | Codex Supervisor | pending | recorded | Phase requirements generated. |
| EVD-phase-001-003 | phase-001 | CLAIM-phase-001 | worker-report | .ai-loop/runs/phase-001/report.md | Worker | pending | recorded | Worker report captured. |
| EVD-phase-001-004 | phase-001 | CLAIM-phase-001 | status | .ai-loop/runs/phase-001/status_after.txt | collect-evidence.ps1 | pending | recorded | Repository status captured after Worker execution. |
| EVD-phase-001-005 | phase-001 | CLAIM-phase-001 | diff | .ai-loop/runs/phase-001/diff.patch | collect-evidence.ps1 | pending | recorded | Diff captured. |
| EVD-phase-001-006 | phase-001 | CLAIM-phase-001 | verification-log | .ai-loop/runs/phase-001/verify.log | collect-evidence.ps1 | pending | recorded | Verification log captured. |
| EVD-phase-001-007 | phase-001 | CLAIM-phase-001 | changed-files | .ai-loop/runs/phase-001/changed_files.txt | collect-evidence.ps1 | pending | recorded | Changed files captured. |
| EVD-phase-001-008 | phase-001 | CLAIM-phase-001 | business-files | .ai-loop/runs/phase-001/changed_business_files.txt | collect-evidence.ps1 | pending | recorded | Changed business files captured. |
| EVD-phase-001-009 | phase-001 | CLAIM-phase-001 | evidence-files | .ai-loop/runs/phase-001/changed_evidence_files.txt | collect-evidence.ps1 | pending | recorded | Changed evidence files captured. |

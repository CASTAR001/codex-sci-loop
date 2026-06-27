# Evidence Ledger

This compatibility copy mirrors the canonical template evidence ledger.

| Evidence ID | Phase | Claim ID | Type | Path or Command | Produced By | Verified By | Status | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| EVD-BOOTSTRAP-001 | harness | CLAIM-BOOTSTRAP | bootstrap | .ai-loop/evidence/evidence-ledger.md | Supervisor | Supervisor | recorded | Ledger initialized for evidence-gated loop work. |

| EVD-phase-002-001 | phase-002 | CLAIM-phase-002 | prompt | .ai-loop/runs/phase-002/prompt.md | Codex Supervisor | pending | recorded | Worker prompt generated. |
| EVD-phase-002-002 | phase-002 | CLAIM-phase-002 | requirements | .ai-loop/runs/phase-002/phase_requirements.json | Codex Supervisor | pending | recorded | Phase requirements generated. |
| EVD-phase-002-003 | phase-002 | CLAIM-phase-002 | worker-report | .ai-loop/runs/phase-002/report.md | Worker | pending | recorded | Worker report captured. |
| EVD-phase-002-004 | phase-002 | CLAIM-phase-002 | status | .ai-loop/runs/phase-002/status_after.txt | collect-evidence.ps1 | pending | recorded | Repository status captured after Worker execution. |
| EVD-phase-002-005 | phase-002 | CLAIM-phase-002 | diff | .ai-loop/runs/phase-002/diff.patch | collect-evidence.ps1 | pending | recorded | Diff captured. |
| EVD-phase-002-006 | phase-002 | CLAIM-phase-002 | verification-log | .ai-loop/runs/phase-002/verify.log | collect-evidence.ps1 | pending | recorded | Verification log captured. |
| EVD-phase-002-007 | phase-002 | CLAIM-phase-002 | changed-files | .ai-loop/runs/phase-002/changed_files.txt | collect-evidence.ps1 | pending | recorded | Changed files captured. |
| EVD-phase-002-008 | phase-002 | CLAIM-phase-002 | business-files | .ai-loop/runs/phase-002/changed_business_files.txt | collect-evidence.ps1 | pending | recorded | Changed business files captured. |
| EVD-phase-002-009 | phase-002 | CLAIM-phase-002 | evidence-files | .ai-loop/runs/phase-002/changed_evidence_files.txt | collect-evidence.ps1 | pending | recorded | Changed evidence files captured. |

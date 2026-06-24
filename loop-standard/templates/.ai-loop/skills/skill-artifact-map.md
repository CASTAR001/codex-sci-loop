# Skill Artifact Map

This map defines the default project-local artifact paths used by phase gate
automation. Workers may add stronger evidence, but required artifacts must still
exist or be explicitly overridden by the Supervisor.

| Skill | Default Artifact Paths |
| --- | --- |
| research-task-tree | tasks/master-task-tree.md; tasks/task-status.md; tasks/task-summary.md |
| invariant-contract | checks/invariant-contract.md; checks/invariant-test-plan.md |
| bounded-experiment-loop | runs/run-ledger.csv; runs/stop-report.md |
| deterministic-verification | checks/verification-ledger.md; audits/dangerous-claims-report.md |
| independent-crosscheck | checks/crosscheck-plan.md; checks/crosscheck-results.md |
| result-provenance-audit | figures/figure-provenance.md; figures/data-provenance.md |
| manuscript-consistency-audit | drafts/symbol-table.md; drafts/claim-source-ledger.md; drafts/zombie-section-report.md |
| skill-compliance-audit | audits/skill-compliance-audit-report.md |


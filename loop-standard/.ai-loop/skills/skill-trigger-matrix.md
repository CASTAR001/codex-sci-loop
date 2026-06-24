# Skill Trigger Matrix

The harness references skills by name and records their required artifacts. It
does not copy skill packages into each project.

| Trigger | Skill | Required When | Required Artifacts | Stop Condition |
| --- | --- | --- | --- | --- |
| multi-step research, paper reproduction, long scientific coding project | research-task-tree | Task has dependencies, many leaves, or cross-session recovery risk. | tasks/master-task-tree.md; tasks/task-status.md; tasks/task-summary.md | Stop if no active leaf task or acceptance criteria are missing. |
| physics, math, data, invariant-sensitive implementation | invariant-contract | Correctness depends on invariants, units, conservation, symmetry, schema, or tolerances. | checks/invariant-contract.md; checks/invariant-test-plan.md | Stop if invariant tests, tolerance, guarantee location, or failure actions are missing. |
| repeated runs, simulation, benchmark, parameter scan, long command | bounded-experiment-loop | Work may drift through repeated attempts or tune-until-good behavior. | runs/run-ledger.csv; runs/stop-report.md | Stop when budget is exhausted, variables multiply, or ledger/output disagree. |
| correctness, equivalence, convergence, exactness, scaling, conservation, numerical claim | deterministic-verification | A phase makes a correctness-sensitive or quantitative claim. | checks/verification-ledger.md; audits/dangerous-claims-report.md | Stop if claim lacks command, CAS, test, or reproducible log evidence. |
| key result before relying on it or publishing it | independent-crosscheck | A scientific, numerical, symbolic, or simulation conclusion becomes load-bearing. | checks/crosscheck-plan.md; checks/crosscheck-results.md | Stop if independent path is missing or disagrees with primary path. |
| final figure, table, processed dataset, result artifact | result-provenance-audit | A result artifact is accepted, published, or used in a report/manuscript. | figures/figure-provenance.md; figures/data-provenance.md | Stop if raw data, processing, plotting command, hash, or shape-changing operations are missing. |
| paper, report, LaTeX, research notes, result summary | manuscript-consistency-audit | Writing contains scientific claims, equations, figures, symbols, or citations. | drafts/symbol-table.md; drafts/claim-source-ledger.md; drafts/zombie-section-report.md | Stop if key claims lack sources or symbols/equations are inconsistent. |
| skill-pack update or task-completion compliance audit | skill-compliance-audit | Skills were installed/updated, or a research task claims compliance. | audits/skill-compliance-audit-report.md | Stop if evidence is prose-only or required artifacts are insufficient. |

## Research Profiles

| Profile | Skills |
| --- | --- |
| research-core | research-task-tree; invariant-contract; deterministic-verification; skill-compliance-audit |
| physics-sim | research-task-tree; invariant-contract; bounded-experiment-loop; deterministic-verification; independent-crosscheck; result-provenance-audit; skill-compliance-audit |
| manuscript | research-task-tree; deterministic-verification; result-provenance-audit; manuscript-consistency-audit; skill-compliance-audit |
| full-research | research-task-tree; invariant-contract; bounded-experiment-loop; deterministic-verification; independent-crosscheck; result-provenance-audit; manuscript-consistency-audit; skill-compliance-audit |

# Control Plane Build Plan

This plan turns the current Supervisor-Worker loop harness into a portable,
global-ready control plane. The final system must be usable from any project
folder, must not depend on one specific Worker agent, and must support both:

- Codex as Supervisor with an external Worker such as Kimi Code, Claude Code, or
  another coding agent.
- Codex acting as both Supervisor and Worker when no external Worker is used.

The current harness already has runnable loop scripts, a pilot fixture, audit
evidence, and a disposable e2e test. The next stage is to add durable control
systems around memory, constraints, evidence, state, roles, recovery, changes,
and skill dispatch.

## North Star

Build a Codex-global workflow package with project-local state:

- Global package: reusable scripts, prompts, docs, schemas, and templates.
- Project-local `.ai-loop/`: facts, memory, evidence, state, decisions, reports,
  and audit trail for one project.
- Worker-agnostic execution: Workers receive bounded prompts and report evidence;
  no Worker owns the route.
- Supervisor-enforced gates: no phase advances without durable evidence and an
  explicit audit decision.

## Systems To Add

### 1. Memory System

Purpose: survive compaction, new chats, tool switches, and Worker handoffs.

Template paths:

```text
templates/.ai-loop/memory/
  project-memory.md
  decision-log.md
  constraint-ledger.md
  fact-ledger.md
  failure-ledger.md
  handoff-summary.md
```

Initial minimum:

- `project-memory.md`
- `constraint-ledger.md`
- `decision-log.md`
- `handoff-summary.md`

Rules:

- Memory must distinguish verified facts from assumptions.
- Constraints must be explicitly cited by Supervisor and Worker prompts.
- Handoff summary must stay short enough to read before every resumed phase.

### 2. Evidence System

Purpose: prevent "prose completion" and make every claim auditable.

Template paths:

```text
templates/.ai-loop/evidence/
  evidence-ledger.md
  artifact-index.md
  command-log.md
  test-log.md
  provenance-map.md
```

Initial minimum:

- `evidence-ledger.md`

Rules:

- Every completion claim should map to a Claim ID.
- Evidence entries must include type, path, verifier, status, and date.
- Missing evidence blocks acceptance.

### 3. State Machine

Purpose: prevent loop drift and illegal phase transitions.

Template paths:

```text
templates/.ai-loop/state/
  loop-state.md
  phase-gates.md
  stop-rules.md
```

Initial minimum:

- `phase-gates.md`
- `stop-rules.md`

Candidate phase states:

```text
planned -> started -> worker_reported -> evidence_collected -> audit_ready
-> accepted | rework | blocked
```

Rules:

- Scripts should reject illegal transitions unless `-Force` is explicit and
  recorded.
- State changes must be reflected in durable files, not chat history.

### 4. Role And Permission Contracts

Purpose: prevent Worker overreach and polite but weak auditing.

Template paths:

```text
templates/.ai-loop/roles/
  supervisor-contract.md
  worker-contract.md
  auditor-contract.md
  verifier-contract.md
```

Initial minimum:

- `worker-contract.md`
- `auditor-contract.md`

Rules:

- Worker may execute only the assigned phase.
- Auditor must inspect report, diff, verification log, status, changed files, and
  relevant source.
- Auditor must not rewrite the task to make an outcome pass.

### 5. Recovery System

Purpose: resume safely after interruption, compaction, or model/tool switches.

Template paths:

```text
templates/.ai-loop/recovery/
  resume-prompt.md
  restart-protocol.md
  compact-protocol.md
  emergency-stop.md
```

Initial minimum:

- `resume-prompt.md`
- `compact-protocol.md`

Rules:

- Resume starts by reading handoff summary, loop state, constraints, decisions,
  evidence ledger, and phase gates.
- A resumed agent must report current phase, last verified evidence, open
  blockers, next safe action, and files to inspect before edits.

### 6. Change Control

Purpose: make broad automated edits recoverable and reviewable.

Template paths:

```text
templates/.ai-loop/changes/
  change-request.md
  changed-files.md
  rollback-plan.md
  checkpoint-index.md
```

Initial minimum:

- `changed-files.md`
- `rollback-plan.md`

Rules:

- Changed files should record phase, reason, risk, and rollback note.
- Rollback plans must protect memory and evidence ledgers from casual deletion.

### 7. Skill Dispatcher

Purpose: make skill usage explicit, required, and auditable.

Template paths:

```text
templates/.ai-loop/skills/
  skill-trigger-matrix.md
  skill-usage-ledger.md
```

Initial minimum:

- `skill-trigger-matrix.md`
- `skill-usage-ledger.md`

Rules:

- If a situation requires a skill, the required artifact must be named.
- Auditor checks whether required skills were used and artifacts exist.
- "Skill was useful" is not enough; the artifact must land in the project.

## Additional Systems I Recommend

These are not in the webpage suggestion, but they matter for the global,
worker-agnostic goal.

### A. Worker Adapter Layer

Add a neutral worker interface:

```text
templates/.ai-loop/workers/
  worker-adapter.md
  codex-worker.md
  kimi-code-worker.md
  claude-code-worker.md
```

Purpose:

- Separate the loop protocol from one Worker brand.
- Let Codex run as Worker when needed.
- Keep Worker-specific invocation notes out of the core state machine.

### B. Schema And Versioning

Add:

```text
templates/.ai-loop/schema/
  schema-version.json
  migration-log.md
```

Purpose:

- Make `.ai-loop/` upgrades explicit.
- Let scripts detect old templates and suggest migrations.

### C. Validation CLI

Extend scripts with:

```text
scripts/validate-loop.ps1
scripts/validate-phase.ps1
```

Purpose:

- Validate required files, state transitions, evidence ledgers, role contracts,
  and skill ledgers.
- Use these checks before audit and before accept.

### D. Global Entrypoint

Add one stable wrapper:

```text
scripts/ai-loop.ps1
```

Candidate usage:

```powershell
ai-loop init -ProjectRoot E:\some-project
ai-loop start -ProjectRoot E:\some-project -PhaseId phase-001
ai-loop collect -ProjectRoot E:\some-project -PhaseId phase-001
ai-loop audit-pack -ProjectRoot E:\some-project -PhaseId phase-001
ai-loop accept -ProjectRoot E:\some-project -PhaseId phase-001
ai-loop resume -ProjectRoot E:\some-project
```

Purpose:

- Give Codex global install one stable command surface.
- Hide individual script names from normal usage.

## Proposed `.ai-loop/` Target Layout

```text
.ai-loop/
  README.md
  loop.config.json
  status.json

  memory/
  state/
  roles/
  evidence/
  skills/
  changes/
  recovery/
  workers/
  schema/

  prompts/
  runs/
  audits/
  logs/
```

## Build Order

### Phase C1: Memory + Constraints

Deliver:

- memory templates;
- constraints ledger;
- decision log;
- handoff summary;
- prompts updated to require reading these files.

Exit criteria:

- `init-loop.ps1` copies the memory templates.
- `resume-prompt.md` references the memory files.
- e2e still passes.

### Phase C2: Evidence + Skill Dispatcher

Deliver:

- evidence ledger templates;
- skill trigger matrix;
- skill usage ledger;
- audit input includes these ledgers.

Exit criteria:

- `prepare-audit-pack.ps1` lists evidence and skill ledger paths.
- missing required ledgers cause `BLOCKED` or `REWORK`.

### Phase C3: State Machine + Role Contracts

Deliver:

- phase gates;
- stop rules;
- role contracts;
- script-level transition checks.

Exit criteria:

- illegal transition tests exist in e2e.
- Worker and Auditor prompts cite their contracts.

### Phase C4: Recovery + Change Control

Deliver:

- resume prompt;
- compact protocol;
- emergency stop;
- changed files ledger;
- rollback plan.

Exit criteria:

- resumed agent can reconstruct current phase from files only.
- change log and rollback plan are updated by the loop.

### Phase C5: Global Entrypoint + Validation

Deliver:

- `ai-loop.ps1`;
- `validate-loop.ps1`;
- `validate-phase.ps1`;
- dry global install test.

Exit criteria:

- a new temporary project can run the full loop using the global-style entrypoint.

## Immediate Next Step

Start with Phase C1. Do not implement all directories at once. First add:

```text
templates/.ai-loop/memory/project-memory.md
templates/.ai-loop/memory/constraint-ledger.md
templates/.ai-loop/memory/decision-log.md
templates/.ai-loop/memory/handoff-summary.md
templates/.ai-loop/recovery/resume-prompt.md
```

Then update:

- `init-loop.ps1`
- `start-phase.ps1`
- Kimi/Worker prompt generation
- `test-pilot-loop.ps1`
- docs and self-check

The first implementation should prove that a resumed Supervisor can read files
and reconstruct the next safe action without chat history.

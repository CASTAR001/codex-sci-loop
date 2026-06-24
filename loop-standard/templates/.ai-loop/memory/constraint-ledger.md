# Constraint Ledger

## Hard Constraints

- Worker may execute only the current assigned phase.
- Worker must not redefine the project goal or global route.
- Worker must not silently broaden file scope.
- Worker must not modify governance files unless the Supervisor explicitly
  declares a harness maintenance phase.
- Governance files include `.ai-loop/memory/`, `.ai-loop/roles/`,
  `.ai-loop/gates/`, `.ai-loop/events/`, `.ai-loop/evidence/`,
  `.ai-loop/skills/`, `.ai-loop/evolution/`, `.ai-loop/prompts/`, and
  `.ai-loop/templates/`.
- Verification must produce command output, logs, tests, diffs, or reproducible
  artifacts.
- "Looks correct", "it runs", "probably fixed", and fluent prose are not
  evidence.
- If evidence is missing, mark `BLOCKED` or `REWORK`, not `ACCEPTED`.
- If required skill artifacts are missing, mark `BLOCKED` or `REWORK`, unless
  the Supervisor records an explicit force-override reason.
- If an invariant or stop rule fails, stop and report; do not patch around it.
- Do not skip required scientific correctness skills when the task involves
  numerical, symbolic, experimental, research, or correctness-sensitive claims.
- Do not claim a scientific or numerical result is correct without deterministic
  verification or an appropriate cross-check.
- Do not use chat history as an authoritative fact source; facts must land in
  files.

## User Preferences

- Prefer concrete procedures over many alternatives.
- Prefer reusable framework over ad hoc prompt chains.
- Prefer evidence-based verification over subjective review.
- Keep root `AGENTS.md` short; put detailed rules in `.ai-loop/`.

## Worker-Agnostic Rule

The harness must not depend on Kimi Code specifically. Any Worker agent,
including Codex acting in Worker mode, must follow the same contracts and
evidence requirements.

---
name: loop-supervisor
description: "Start and manage one bounded native Codex phase using project-local state, verification evidence, source diffs, and explicit audit gates."
---

# Loop Supervisor

Run `loop-goal-bootstrap` first. Read `AGENTS.md`, `.ai-loop/README.md`, the
active context, constraint ledger, and pre-action check before planning or
editing.

Start exactly one phase:

```bash
python3 <plugin-root>/scripts/sci_loop.py start \
  --project-root <git-root> \
  --phase-id <bounded-id> \
  --title <title> \
  --objective <objective> \
  --verify-command <reproducible-command>
```

The active Codex thread then executes only that objective. It must preserve
existing work, follow repository instructions, and write a factual
`.ai-loop/runs/<phase-id>/report.md`. The runtime adapter must preserve the
exact user request in `request-envelope.json`; before audit, the supervisor
must also provide explicit `acceptance-criteria.json` and
`completion-claims.json` matching the bundled schemas. Collect evidence and
prepare the audit:

```bash
python3 <plugin-root>/scripts/sci_loop.py collect --project-root <git-root> --phase-id <phase-id>
python3 <plugin-root>/scripts/sci_loop.py audit-pack --project-root <git-root> --phase-id <phase-id>
```

The executor cannot accept its own narrative as proof and cannot use
`sci_loop.py decide` for an accepted or blocked terminal state. The host creates
the canonical snapshot, starts the isolated reviewer, stores its observation,
outcome, transcript and receipt outside executor write access, then invokes
`audit_protocol.py finalize`. Any missing, stale, malformed, failed or
unverified evidence blocks completion.

When the Stop adapter requests review, use only the installed
`independent_completion_auditor` custom agent, the exact delegation message
provided by the adapter, and `fork_turns=none`. Do not paraphrase the message,
share parent turns, substitute a general reviewer, or construct a receipt.

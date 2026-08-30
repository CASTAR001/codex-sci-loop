---
name: independent-completion-auditor
description: "Perform a clean-room, read-only audit of one canonical sci-loop completion snapshot and return strict per-item evidence outcomes."
---

# Independent Completion Auditor

Use this Skill only inside the dedicated `independent_completion_auditor`
subagent selected by the LumiForge host.

Read the canonical `audit-snapshot.json` named in the delegation and only the
evidence IDs listed there. Do not consume the parent thread's reasoning,
continue implementation, edit files, create a receipt, or decide completion.

Return exactly one JSON object conforming to
`schemas/independent-audit-outcome.schema.json`. Cover every requirement and
claim exactly once with `PASS`, `FAIL`, `UNVERIFIED`, or `BLOCKED`; cite known
evidence IDs for every `PASS`. Treat missing or indirect proof as
`UNVERIFIED`, never `PASS`.

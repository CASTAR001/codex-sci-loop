# Codex Scientific Loop

This portable plugin adds project-local, evidence-gated phase management to a
native Codex runtime. It does not launch or replace an agent engine. The active
Codex thread performs the requested work, while the bundled core records phase
state, verification output, and Git evidence in `.ai-loop/`.

Completion is governed by `scripts/audit_protocol.py`. It creates a canonical
snapshot from the raw request, acceptance criteria, completion claims, current
workspace evidence, deterministic verification, and runtime certification. A
separate clean-room reviewer must return strict per-item outcomes. Only a fresh
host-issued receipt from a protected root can finalize `PASS`; prose audit files
cannot accept or block a phase.

The default `hooks/hooks.json` maps the certified Codex lifecycle events into
this protocol. `UserPromptSubmit` captures only explicit Goal-mode requests or
revisions to an active loop. The `Agent` pre-tool guard requires the exact
delegation and `fork_turns=none`; subagent start/stop hooks bind the observed
native identity and opaque transcript; `Stop` continues or denies the turn
until the signed gate passes. Hook names and wire shapes remain confined to the
adapter.

The command entrypoint is:

```bash
python3 <plugin-root>/scripts/sci_loop.py --help
python3 <plugin-root>/scripts/audit_protocol.py --help
```

Installation is managed by LumiForge. Do not point a running account directly
at a mutable source checkout. The receipt root and reviewer observation files
must remain outside the executor's write boundary. The bundled custom-agent
file is only a template: LumiForge must project it into the account-private
Codex home and independently attest the outer read-only boundary before review.

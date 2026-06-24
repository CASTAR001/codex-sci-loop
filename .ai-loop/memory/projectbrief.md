# Project Brief

## Project Identity

- Path: `E:\codexfiles\loop`
- Project: reusable Supervisor-Worker loop harness.
- Goal: build a local-first workflow that can later be installed globally for
  Codex and used from any project folder.

## Primary Use Case

Codex acts as Supervisor. A Worker agent executes bounded phases. The Worker can
be Kimi Code, Claude Code, another coding agent, or Codex acting in Worker mode.

## Core Principle

The loop must advance by durable evidence, not by persuasive prose or chat
memory. Every meaningful phase should leave prompt, report, diff, verification
log, state, and audit artifacts.

## Current Repository Shape

- `loop-standard/`: reusable package, scripts, docs, prompts, and templates.
- `pilot-project/`: root-tracked fixture proving the loop end to end.
- `.ai-loop/`: this repository's local control-plane memory and constraints.
- `AGENTS.md`: short bootstrap entrypoint for agents.

`agent.md` / `AGENT.md` should not exist as separate root entrypoints; their
former content has been merged into `.ai-loop/memory/activeContext.md`,
`.ai-loop/memory/projectbrief.md`, and `.ai-loop/memory/constraint-ledger.md`.

## Non-Goals

- No cloud memory service.
- No database.
- No Mem0, Zep, Graphiti, projectmem, or other heavy dependency in this phase.

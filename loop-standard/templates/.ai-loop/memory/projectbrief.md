# Project Brief

## Project Identity

- Path: `<project-root>`
- Project: `<project-name>`
- Goal: use the Supervisor-Worker loop harness for bounded, evidence-based
  project work.

## Primary Use Case

Codex acts as Supervisor. A Worker agent executes bounded phases. The Worker can
be Kimi Code, Claude Code, another coding agent, or Codex acting in Worker mode.

## Core Principle

The loop must advance by durable evidence, not by persuasive prose or chat
memory. Every meaningful phase should leave prompt, report, diff, verification
log, state, and audit artifacts.

## Current Repository Shape

- `.ai-loop/`: project-local control-plane memory and constraints.
- `AGENTS.md`: optional short bootstrap entrypoint for agents.

## Non-Goals

- No cloud memory service.
- No database.
- No Mem0, Zep, Graphiti, projectmem, or other heavy dependency in this phase.

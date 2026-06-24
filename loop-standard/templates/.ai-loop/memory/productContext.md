# Product Context

## Problem

Long coding loops lose constraints during compaction, handoff, or model changes.
Workers may overreach, audits may accept prose instead of evidence, and repeated
failures can be rediscovered instead of prevented.

## Product Shape

This harness provides a small file-based operating system around coding work:

- memory for stable context;
- constraints for hard rules;
- role contracts for Supervisor, Worker, Auditor, Verifier, and Recovery;
- pre-action gates before edits;
- events for durable history;
- prompts and templates for repeatable handoff.

## Users

- Codex Supervisor.
- External Worker agents.
- Codex Worker mode.
- Human operator reviewing files and evidence.

## Desired Experience

An agent entering the repository should know what to read, what not to modify,
what evidence is required, and how to resume without relying on prior chat.

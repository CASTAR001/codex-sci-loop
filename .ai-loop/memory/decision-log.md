# Decision Log

| ID | Date | Decision | Reason | Status |
|---|---|---|---|---|
| D001 | 2026-06-23 | Use local `.ai-loop/` files as source of truth | Chat history is not durable across compaction or handoff | Active |
| D002 | 2026-06-23 | Keep Worker bounded to current phase | Prevent Worker from hijacking route planning | Active |
| D003 | 2026-06-23 | Track `pilot-project/` as a root fixture, not embedded git | Makes the harness portable as one repository | Active |
| D004 | 2026-06-24 | Adopt markdown-first local memory system | Human-readable, git-trackable, no service dependency | Active |
| D005 | 2026-06-24 | Keep `AGENTS.md` as short bootstrap only | Avoid giant root constitution; keep rules in `.ai-loop/` | Active |
| D006 | 2026-06-24 | Do not introduce Mem0, Zep, Graphiti, or projectmem in phase one | Avoid heavy dependencies and cloud/database coupling | Active |
| D007 | 2026-06-24 | Governance files are read-mostly for normal Workers | Prevent accidental mutation of loop rules | Active |
| D008 | 2026-06-24 | Remove duplicate `agent.md` entrypoint | Root should have one bootstrap file: `AGENTS.md` | Active |
| D009 | 2026-06-24 | Keep `.agents/` for agent runtime assets and `.ai-loop/` for project state | Prevent runtime/tool assets from mixing with durable loop memory | Active |

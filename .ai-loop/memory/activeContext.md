# Active Context

## Current Architecture

codex-sci-loop is a project-local evidence and recovery plugin for the native
Codex runtime. It does not implement a second Agent engine.

- The active Codex thread executes the bounded phase.
- The host captures the original Goal request before model execution.
- An isolated native Codex subagent reviews a canonical audit snapshot with
  fork_turns=none.
- Only a fresh, host-signed receipt in the protected receipt root may authorize
  completion.
- Capability ABI checks distinguish compatible Codex updates from relevant
  interface drift. Compatible updates continue without intervention.

## Current Source Candidate

- Plugin: plugins/codex-sci-loop/
- Version: 1.0.0
- Core SHA-256:
  4812d207225e50bc3f8474570e8587573521308ae3ef1518c998bd6e1462752b
- Skills: goal bootstrap, supervisor, auditor, recovery, research orchestrator,
  and independent completion auditor.
- loop-standard/ is retained only as a compatibility toolkit for existing
  projects. New runtime behavior belongs in the Python plugin core.

The source candidate removes the retired external reviewer-specific routes and
the duplicate system-level hook bootstrap. Historical phase evidence remains
in Git and under historical run directories; it is not an active instruction
surface.

## Last Verification

Provider-free phase-029 verification passed:

- native distribution/lifecycle suite;
- capability ABI suite;
- signed audit-receipt suite;
- Codex hook and clean-room subagent suite;
- 172-path compatibility structure check;
- Linux isolated-install smoke test;
- Git whitespace check.

External action count: Provider=0, Browser=0, ServiceLifecycle=0, Production=0,
Remote=0, CurrentPluginChanges=0.

## Known Boundary

Historical phase-001..028 artifact validation is non-portable in this Linux
checkout because some old recorded hashes differ from checkout bytes. Do not
rewrite accepted evidence to make that old chain green. The native v1 gate is
independent and records current evidence.

## Next Safe Actions

1. Complete the external workspace audit for the source-only candidate.
2. Create a local canonical checkpoint commit; do not push without explicit
   authorization.
3. In a separate LumiForge phase, update the vendored upstream revision and
   reviewed-input metadata to that canonical commit.
4. Do not install into the currently running Codex until separately authorized.

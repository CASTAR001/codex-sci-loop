# Global Install Plan

The end state is a Codex-global workflow that can be invoked from any project
folder without copying chat history or ad hoc files.

## Repository Shape

The root repository should track:

- `loop-standard/` - reusable workflow package.
- `pilot-project/` - fixture that proves the workflow end to end.

`pilot-project/` should be a normal tracked fixture directory, not an embedded
git repository or ad hoc submodule. This keeps the whole kit portable as one
artifact.

## Proposed Global Layout

Install into a Codex home directory such as:

```text
%USERPROFILE%\.codex\loop-standard\
```

or an explicit directory passed to the installer:

```text
<CodexHome>\loop-standard\
  templates/
  prompts/
  scripts/
  docs/
```

Projects should not depend on this repo path directly. They should call the
global scripts by absolute path or through a future small wrapper command.

## Required Global Capabilities

- Initialize `.ai-loop/` in any project.
- Start one bounded phase.
- Collect durable evidence.
- Prepare a Codex audit input.
- Accept only after an `ACCEPTED` audit.
- Record memory, constraints, skill usage, evidence, and state transitions in
  files.

## Next Systems To Add

1. Memory system:
   - project memory;
   - phase memory;
   - reusable lessons;
   - known constraints.
2. Constraint system:
   - hard rules;
   - soft preferences;
   - phase-specific constraints;
   - refusal/blocking rules.
3. Evidence system:
   - required artifact manifest;
   - hashes;
   - verification command registry;
   - source inspection checklist.
4. Skill usage record:
   - skill name;
   - why it was used;
   - files read;
   - outputs generated.
5. State machine:
   - explicit allowed transitions;
   - transition logs;
   - recovery paths.

## Non-Goals For This Step

- Do not write into the real Codex global directory yet.
- Do not assume a single machine-specific `%USERPROFILE%`.
- Do not depend on chat history.

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

Install into an explicit loop harness root such as:

```text
%USERPROFILE%\.codex\loop-harness\
```

The installer creates this shape:

```text
<InstallRoot>\
  bin\
    ai-loop.ps1
  loop-standard\
    templates/
    prompts/
    scripts/
    docs/
  plugins\
    codex-loop-harness/
```

Projects should not depend on this repo path directly. They should call the shim
under `<InstallRoot>\bin\ai-loop.ps1` or add that `bin` directory to PATH
manually.

## Installer

Recommended dry install:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\install-global.ps1 `
  -InstallRoot .\.tmp-install `
  -InstallPlugin `
  -CreateShim `
  -SkillLibraryRoot E:\codexfiles\test\.agents\skills `
  -Force
```

Legacy `-CodexHome` remains accepted as an alias-like compatibility path for
older calls, but new documentation should use `-InstallRoot`.

## Required Global Capabilities

- Initialize `.ai-loop/` in any project.
- Start one bounded phase.
- Collect durable evidence.
- Prepare a Codex audit input.
- Accept only after an `ACCEPTED` audit.
- Record memory, constraints, skill usage, evidence, and state transitions in
  files.

## Next Systems To Add

1. Recovery automation:
   - resumable current-phase summary;
   - missing evidence report;
   - BLOCKED recommendation when state cannot be reconstructed.
2. State machine:
   - explicit allowed transitions;
   - compatibility wrappers that cannot bypass gates;
   - transition logs.
3. Evidence automation:
   - stronger artifact indexing;
   - hashes;
   - verification command registry.

## Non-Goals For This Step

- Do not modify PATH automatically.
- Do not assume a single machine-specific `%USERPROFILE%`.
- Do not depend on chat history.

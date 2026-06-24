# Global Callable Convergence Report

Date: 2026-06-25

## Scope

This phase made the harness easier to call from any project by improving the
install layout, generated shim, doctor checks, recovery summary, compatibility
wrappers, and root documentation.

## Implemented

- Root `README.md` is the Chinese human entrypoint; `README_EN.md` keeps the
  English companion; `AGENTS.md` remains the short agent bootstrap.
- `install-global.ps1` now accepts `-InstallRoot`, compatibility `-CodexHome`,
  `-SkillLibraryRoot`, `-InstallPlugin`, `-CreateShim`, and `-Force`.
- Installation can create `<InstallRoot>/bin/ai-loop.ps1`, copy
  `loop-standard/`, and optionally copy `plugins/codex-loop-harness/`.
- `ai-loop doctor` validates the plugin manifest, plugin skill frontmatter,
  plugin wrapper, required research skill library, and installed shim status.
- `ai-loop resume` reports current phase, phase status, required skills,
  missing evidence, next safe action, and `RESUMABLE` or `BLOCKED`.
- Uppercase compatibility scripts now forward to canonical `ai-loop.ps1` and no
  longer maintain independent legacy state logic.
- `Test-LoopStandard.ps1` now checks root README files, install interfaces,
  plugin wrapper parsing, and compatibility wrapper forwarding.

## Verification

Passed:

- PowerShell parse check for `loop-standard/scripts/*.ps1` and plugin scripts.
- `Test-LoopStandard.ps1 -AllowPilotProject`, now checking 73 paths.
- Source `ai-loop.ps1 -Command doctor`.
- Plugin wrapper `scripts/ai-loop.ps1 -Command doctor`.
- Temporary install using `install-global.ps1 -InstallRoot .tmp-install
  -InstallPlugin -CreateShim -Force`.
- Installed shim doctor.
- Installed shim project `init` and `link-skills -Profile full-research`.
- Fullstack phase start, collect, resume, audit-pack, and accept.
- Physics-research missing skill artifacts block audit readiness.
- Force accept requires override reason and succeeds with one.
- Broken required skill link blocks validation.
- Recovery with missing `.ai-loop/status.json` returns BLOCKED and exit code 2.
- Uppercase compatibility wrapper smoke flow.
- README UTF-8 check and `git diff --check`.

## Remaining Work

- Choose and document the real non-temporary global install root.
- Add artifact hashing and stronger evidence ledger automation.
- Add stricter state transition log validation.
- Expand the full-stack and physics skill trigger matrix.

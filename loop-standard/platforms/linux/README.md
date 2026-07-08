# Linux Install Notes

Linux uses `install.sh` at the repository root or
`loop-standard/scripts/install-global.sh` directly. The installer uses POSIX
paths, writes an executable `bin/ai-loop` shim, and stores the default global
layout under `${CODEX_HOME:-$HOME/.codex}/loop-harness`.

The loop command surface is still implemented by the shared PowerShell core, so
the Linux shim expects PowerShell 7 as `pwsh` when running loop commands.

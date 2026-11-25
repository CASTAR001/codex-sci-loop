# Linux Installation

With the Codex CLI on PATH, run `./install.sh` from the repository root to
register this checkout as a local marketplace and install the Codex plugin.

For the compatibility toolkit, run `./install.sh --legacy-toolkit` or use the
existing installer flags. The dispatcher forwards toolkit parameters to
`loop-standard/scripts/install-global.sh`. Its default install root is
`${CODEX_HOME:-$HOME/.codex}/loop-harness`. The optional `bin/ai-loop` shim uses
PowerShell 7 (`pwsh`).

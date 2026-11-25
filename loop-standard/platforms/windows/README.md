# Windows Installation

With the Codex CLI on PATH, run the repository-level installer without toolkit
flags to register this checkout as a local marketplace and install the Codex
plugin.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

For the PowerShell compatibility toolkit, pass `-LegacyToolkit` or the
existing flags. The dispatcher forwards toolkit parameters to
`loop-standard\scripts\install-global.ps1`.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -LegacyToolkit -InstallRoot "C:\path\to\loop-harness"
```

# Windows Install Notes

Windows keeps the existing PowerShell-first installer:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\loop-standard\scripts\install-global.ps1
```

The repository-level `install.ps1` dispatcher detects Windows and forwards to
that installer.

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
OS_NAME="$(uname -s 2>/dev/null || printf 'unknown')"

case "$OS_NAME" in
    Linux)
        exec bash "$SCRIPT_DIR/loop-standard/scripts/install-global.sh" "$@"
        ;;
    Darwin)
        printf '%s\n' "macOS installer placeholder: platform-specific packaging is reserved for a later phase." >&2
        printf '%s\n' "Use the Windows or Linux installer on those platforms for now." >&2
        exit 3
        ;;
    MINGW*|MSYS*|CYGWIN*)
        if ! command -v powershell.exe >/dev/null 2>&1; then
            printf '%s\n' "Windows installer requires powershell.exe." >&2
            exit 127
        fi
        exec powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$SCRIPT_DIR/loop-standard/scripts/install-global.ps1" "$@"
        ;;
    *)
        printf 'Unsupported platform for loop harness install: %s\n' "$OS_NAME" >&2
        exit 2
        ;;
esac

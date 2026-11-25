#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

if [[ "${1:-}" == "--legacy-toolkit" ]]; then
    shift
elif [[ $# -eq 0 ]]; then
    if ! command -v codex >/dev/null 2>&1; then
        printf '%s\n' "Native plugin installation requires the Codex CLI (codex) on PATH." >&2
        exit 127
    fi
    codex plugin marketplace add "$SCRIPT_DIR"
    exec codex plugin add codex-sci-loop@codex-sci-loop-local
fi

OS_NAME="$(uname -s 2>/dev/null || printf 'unknown')"

case "$OS_NAME" in
    Linux)
        exec bash "$SCRIPT_DIR/loop-standard/scripts/install-global.sh" "$@"
        ;;
    Darwin)
        printf '%s\n' "The compatibility toolkit installer supports Linux and Windows." >&2
        printf 'Run "%s/install.sh" without arguments to install the Codex plugin.\n' "$SCRIPT_DIR" >&2
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

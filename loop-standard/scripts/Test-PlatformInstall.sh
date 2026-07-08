#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
KIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
REPO_ROOT="$(cd "$KIT_ROOT/.." && pwd -P)"
TEMP_ROOT="$(mktemp -d "$REPO_ROOT/.tmp-ai-loop-platform-install.XXXXXX")"
KEEP_TEMP="${KEEP_TEMP:-0}"

cleanup() {
    if [[ "$KEEP_TEMP" != "1" ]]; then
        rm -rf "$TEMP_ROOT"
    fi
}
trap cleanup EXIT

problems=()

add_problem() {
    problems+=("$1")
}

require_file() {
    local path="$1"
    if [[ ! -s "$path" ]]; then
        add_problem "missing or empty file: $path"
    fi
}

require_dir() {
    local path="$1"
    if [[ ! -d "$path" ]]; then
        add_problem "missing directory: $path"
    fi
}

INSTALL_ROOT="$TEMP_ROOT/install"
SKILL_ROOT="$TEMP_ROOT/skills"

if [[ "$(uname -s)" != "Linux" ]]; then
    echo "Platform install smoke test: SKIPPED (Linux-only test)"
    exit 0
fi

bash "$SCRIPT_DIR/install-global.sh" \
    --install-root "$INSTALL_ROOT" \
    --skill-library-root "$SKILL_ROOT" \
    --install-plugin \
    --create-shim \
    --create-marketplace \
    --force >"$TEMP_ROOT/install-output.txt"

require_file "$INSTALL_ROOT/loop-standard/scripts/ai-loop.ps1"
require_file "$INSTALL_ROOT/loop-standard/scripts/install-global.sh"
require_file "$INSTALL_ROOT/plugins/codex-loop-harness/.codex-plugin/plugin.json"
require_file "$INSTALL_ROOT/plugins/codex-loop-harness/skills/loop-supervisor/SKILL.md"
require_file "$INSTALL_ROOT/plugins/codex-loop-harness/scripts/ai-loop.ps1"
require_file "$INSTALL_ROOT/.agents/plugins/marketplace.json"
require_file "$INSTALL_ROOT/bin/ai-loop"
require_dir "$INSTALL_ROOT/loop-standard/templates/.ai-loop"

if [[ -e "$INSTALL_ROOT/bin/ai-loop" && ! -x "$INSTALL_ROOT/bin/ai-loop" ]]; then
    add_problem "Linux shim is not executable: $INSTALL_ROOT/bin/ai-loop"
fi

if ! grep -q '"name": "codex-loop-harness"' "$INSTALL_ROOT/.agents/plugins/marketplace.json"; then
    add_problem "marketplace missing codex-loop-harness plugin entry"
fi

if ! grep -q 'pwsh' "$INSTALL_ROOT/bin/ai-loop"; then
    add_problem "Linux shim does not invoke pwsh"
fi
if ! grep -q 'pwsh' "$INSTALL_ROOT/plugins/codex-loop-harness/scripts/ai-loop.ps1"; then
    add_problem "plugin wrapper does not support pwsh"
fi

if ! bash -n "$REPO_ROOT/install.sh"; then
    add_problem "root install.sh has a bash syntax error"
fi
if ! bash -n "$SCRIPT_DIR/install-global.sh"; then
    add_problem "install-global.sh has a bash syntax error"
fi

if [[ ${#problems[@]} -gt 0 ]]; then
    echo "Platform install smoke test: FAILED"
    for problem in "${problems[@]}"; do
        echo "- $problem"
    done
    echo "Install root: $INSTALL_ROOT"
    exit 2
fi

echo "Platform install smoke test: OK"
echo "Install root: $INSTALL_ROOT"

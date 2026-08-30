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
require_file "$INSTALL_ROOT/loop-standard/scripts/Test-ValidateLoopMissingProperties.py"
require_file "$INSTALL_ROOT/loop-standard/scripts/validate-loop.ps1"
require_file "$INSTALL_ROOT/plugins/codex-sci-loop/.codex-plugin/plugin.json"
require_file "$INSTALL_ROOT/plugins/codex-sci-loop/scripts/sci_loop.py"
require_file "$INSTALL_ROOT/plugins/codex-sci-loop/scripts/capability_gate.py"
require_file "$INSTALL_ROOT/plugins/codex-sci-loop/scripts/audit_protocol.py"
require_file "$INSTALL_ROOT/plugins/codex-sci-loop/hooks/codex_adapter.py"
require_file "$INSTALL_ROOT/plugins/codex-sci-loop/hooks/hooks.json"
require_file "$INSTALL_ROOT/plugins/codex-sci-loop/skills/independent-completion-auditor/SKILL.md"
require_file "$INSTALL_ROOT/plugins/codex-sci-loop/skills/loop-goal-bootstrap/SKILL.md"
require_file "$INSTALL_ROOT/plugins/codex-sci-loop/skills/loop-supervisor/SKILL.md"
require_file "$INSTALL_ROOT/.agents/plugins/marketplace.json"
require_file "$INSTALL_ROOT/bin/ai-loop"
require_dir "$INSTALL_ROOT/loop-standard/templates/.ai-loop"

if [[ -e "$INSTALL_ROOT/bin/ai-loop" && ! -x "$INSTALL_ROOT/bin/ai-loop" ]]; then
    add_problem "Linux shim is not executable: $INSTALL_ROOT/bin/ai-loop"
fi

if ! grep -q '"name": "codex-sci-loop"' "$INSTALL_ROOT/.agents/plugins/marketplace.json"; then
    add_problem "marketplace missing codex-sci-loop plugin entry"
fi

if ! grep -q 'pwsh' "$INSTALL_ROOT/bin/ai-loop"; then
    add_problem "Linux shim does not invoke pwsh"
fi
if ! grep -q 'readlink -f' "$INSTALL_ROOT/bin/ai-loop"; then
    add_problem "Linux shim does not resolve symbolic links"
fi
if ! cmp -s "$SCRIPT_DIR/validate-loop.ps1" "$INSTALL_ROOT/loop-standard/scripts/validate-loop.ps1"; then
    add_problem "installed validator differs from the source candidate"
fi
if ! cmp -s "$REPO_ROOT/plugins/codex-sci-loop/scripts/sci_loop.py" "$INSTALL_ROOT/plugins/codex-sci-loop/scripts/sci_loop.py"; then
    add_problem "installed native phase core differs from the source candidate"
fi

if ! bash -n "$REPO_ROOT/install.sh"; then
    add_problem "root install.sh has a bash syntax error"
fi
if ! bash -n "$SCRIPT_DIR/install-global.sh"; then
    add_problem "install-global.sh has a bash syntax error"
fi
if ! python3 "$SCRIPT_DIR/Test-ValidateLoopMissingProperties.py" >"$TEMP_ROOT/validate-loop-properties-output.txt" 2>&1; then
    add_problem "validate-loop missing-property regression failed"
fi
if ! python3 "$INSTALL_ROOT/plugins/codex-sci-loop/scripts/sci_loop.py" --version >"$TEMP_ROOT/plugin-version-output.txt" 2>&1; then
    add_problem "native plugin version check failed"
fi
if ! python3 "$INSTALL_ROOT/plugins/codex-sci-loop/scripts/sci_loop.py" validate-distribution >"$TEMP_ROOT/plugin-distribution-output.txt" 2>&1; then
    add_problem "native plugin distribution validation failed"
fi

SYMLINK_PATH="$TEMP_ROOT/ai-loop"
SYMLINK_PROJECT="$TEMP_ROOT/symlink-project"
ln -s "$INSTALL_ROOT/bin/ai-loop" "$SYMLINK_PATH"
mkdir -p "$SYMLINK_PROJECT"
if ! "$SYMLINK_PATH" -Command init -ProjectRoot "$SYMLINK_PROJECT" >"$TEMP_ROOT/symlink-output.txt" 2>&1; then
    add_problem "Linux shim failed when invoked through a symbolic link"
elif [[ ! -s "$SYMLINK_PROJECT/.ai-loop/status.json" ]]; then
    add_problem "symbolic-link invocation did not initialize the project"
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

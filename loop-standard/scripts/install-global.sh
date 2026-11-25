#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: install-global.sh [options]

Linux installer for the Loop Harness global layout.

Options:
  --install-root PATH          Install target. Defaults to ${CODEX_HOME:-$HOME/.codex}/loop-harness.
  --codex-home PATH            Alias for --install-root, kept for parity with the Windows installer.
  --skill-library-root PATH    Shared skill library root. Defaults to ${CODEX_HOME:-$HOME/.codex}/skills.
  --install-plugin             Install plugins/codex-sci-loop.
  --create-shim                Create bin/ai-loop.
  --create-marketplace         Create .agents/plugins/marketplace.json. Requires --install-plugin.
  --marketplace-name NAME      Marketplace name. Defaults to loop-harness-local.
  --force                      Replace existing copied directories/files.
  -h, --help                   Show this help.
USAGE
}

fail() {
    printf '%s\n' "$1" >&2
    exit "${2:-1}"
}

abs_path() {
    local path="$1"
    case "$path" in
        /*) printf '%s\n' "$path" ;;
        *) printf '%s\n' "$PWD/$path" ;;
    esac
}

normalize_target_path() {
    local path
    path="$(abs_path "$1")"
    local dir
    dir="$(dirname "$path")"
    local base
    base="$(basename "$path")"
    mkdir -p "$dir"
    (cd "$dir" && printf '%s/%s\n' "$(pwd -P)" "$base")
}

copy_clean_directory() {
    local source="$1"
    local destination="$2"
    if [[ ! -d "$source" ]]; then
        fail "Missing source directory: $source"
    fi
    if [[ -e "$destination" ]]; then
        if [[ "$FORCE" != "1" ]]; then
            fail "Destination already exists: $destination. Use --force to replace files."
        fi
        if [[ -z "$destination" || "$destination" == "/" ]]; then
            fail "Refusing to replace unsafe destination: $destination"
        fi
        rm -rf "$destination"
    fi
    mkdir -p "$(dirname "$destination")"
    cp -a "$source" "$destination"
}

json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

CODEX_HOME_DEFAULT="${CODEX_HOME:-$HOME/.codex}"
INSTALL_ROOT=""
CODEX_HOME_ARG=""
SKILL_LIBRARY_ROOT="$CODEX_HOME_DEFAULT/skills"
INSTALL_PLUGIN=0
CREATE_SHIM=0
CREATE_MARKETPLACE=0
MARKETPLACE_NAME="loop-harness-local"
FORCE=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --install-root|-InstallRoot)
            [[ $# -ge 2 ]] || fail "Missing value for $1"
            INSTALL_ROOT="$2"
            shift 2
            ;;
        --codex-home|-CodexHome)
            [[ $# -ge 2 ]] || fail "Missing value for $1"
            CODEX_HOME_ARG="$2"
            shift 2
            ;;
        --skill-library-root|-SkillLibraryRoot)
            [[ $# -ge 2 ]] || fail "Missing value for $1"
            SKILL_LIBRARY_ROOT="$2"
            shift 2
            ;;
        --install-plugin|-InstallPlugin)
            INSTALL_PLUGIN=1
            shift
            ;;
        --create-shim|-CreateShim)
            CREATE_SHIM=1
            shift
            ;;
        --create-marketplace|-CreateMarketplace)
            CREATE_MARKETPLACE=1
            shift
            ;;
        --marketplace-name|-MarketplaceName)
            [[ $# -ge 2 ]] || fail "Missing value for $1"
            MARKETPLACE_NAME="$2"
            shift 2
            ;;
        --force|-Force)
            FORCE=1
            shift
            ;;
        -h|--help|-Help)
            usage
            exit 0
            ;;
        *)
            fail "Unknown option for Linux installer: $1"
            ;;
    esac
done

if [[ "$(uname -s 2>/dev/null || true)" != "Linux" ]]; then
    fail "install-global.sh is the Linux installer for the compatibility toolkit. Use install.ps1 with toolkit flags on Windows." 2
fi

if [[ -n "$INSTALL_ROOT" && -n "$CODEX_HOME_ARG" ]]; then
    RESOLVED_INSTALL="$(normalize_target_path "$INSTALL_ROOT")"
    RESOLVED_CODEX="$(normalize_target_path "$CODEX_HOME_ARG")"
    if [[ "$RESOLVED_INSTALL" != "$RESOLVED_CODEX" ]]; then
        fail "Use either --install-root or --codex-home, or pass the same path for both."
    fi
    INSTALL_ROOT="$RESOLVED_INSTALL"
elif [[ -n "$INSTALL_ROOT" ]]; then
    INSTALL_ROOT="$(normalize_target_path "$INSTALL_ROOT")"
elif [[ -n "$CODEX_HOME_ARG" ]]; then
    INSTALL_ROOT="$(normalize_target_path "$CODEX_HOME_ARG")"
else
    INSTALL_ROOT="$(normalize_target_path "$CODEX_HOME_DEFAULT/loop-harness")"
fi

SKILL_LIBRARY_ROOT="$(normalize_target_path "$SKILL_LIBRARY_ROOT")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
KIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
REPO_ROOT="$(cd "$KIT_ROOT/.." && pwd -P)"

LOOP_STANDARD_DESTINATION="$INSTALL_ROOT/loop-standard"
PLUGIN_SOURCE="$REPO_ROOT/plugins/codex-sci-loop"
PLUGIN_DESTINATION="$INSTALL_ROOT/plugins/codex-sci-loop"
BIN_DIR="$INSTALL_ROOT/bin"
SHIM_PATH="$BIN_DIR/ai-loop"
MARKETPLACE_DIR="$INSTALL_ROOT/.agents/plugins"
MARKETPLACE_PATH="$MARKETPLACE_DIR/marketplace.json"

mkdir -p "$INSTALL_ROOT"
copy_clean_directory "$KIT_ROOT" "$LOOP_STANDARD_DESTINATION"

if [[ "$INSTALL_PLUGIN" == "1" ]]; then
    copy_clean_directory "$PLUGIN_SOURCE" "$PLUGIN_DESTINATION"
fi

if [[ "$CREATE_MARKETPLACE" == "1" ]]; then
    if [[ "$INSTALL_PLUGIN" != "1" ]]; then
        fail "--create-marketplace requires --install-plugin."
    fi
    mkdir -p "$MARKETPLACE_DIR"
    if [[ -e "$MARKETPLACE_PATH" && "$FORCE" != "1" ]]; then
        fail "Marketplace already exists: $MARKETPLACE_PATH. Use --force to replace it."
    fi
    ESCAPED_MARKETPLACE_NAME="$(json_escape "$MARKETPLACE_NAME")"
    cat > "$MARKETPLACE_PATH" <<JSON
{
  "name": "$ESCAPED_MARKETPLACE_NAME",
  "interface": {
    "displayName": "Loop Harness Local"
  },
  "plugins": [
    {
      "name": "codex-sci-loop",
      "source": {
        "source": "local",
        "path": "./plugins/codex-sci-loop"
      },
      "policy": {
        "installation": "INSTALLED_BY_DEFAULT",
        "authentication": "ON_INSTALL"
      },
      "category": "Productivity"
    }
  ]
}
JSON
fi

if [[ "$CREATE_SHIM" == "1" ]]; then
    mkdir -p "$BIN_DIR"
    if [[ -e "$SHIM_PATH" && "$FORCE" != "1" ]]; then
        fail "Shim already exists: $SHIM_PATH. Use --force to replace it."
    fi
    cat > "$SHIM_PATH" <<SHIM
#!/usr/bin/env bash
set -euo pipefail

SHIM_SOURCE="\$(readlink -f "\${BASH_SOURCE[0]}")"
SHIM_DIR="\$(cd "\$(dirname "\$SHIM_SOURCE")" && pwd -P)"
INSTALL_ROOT="\$(cd "\$SHIM_DIR/.." && pwd -P)"
LOOP_SCRIPT="\$INSTALL_ROOT/loop-standard/scripts/ai-loop.ps1"
SKILL_LIBRARY_ROOT="$SKILL_LIBRARY_ROOT"

COMMANDS=" init migrate start collect audit-pack validate validate-loop accept decide extract-audit-findings scaffold-rework resume link-skills worker-preflight invoke-worker prune-temp readiness release-check doctor "
if [[ \$# -gt 0 && "\$COMMANDS" == *" \$1 "* ]]; then
    set -- -Command "\$@"
fi

if ! command -v pwsh >/dev/null 2>&1; then
    printf '%s\n' "ai-loop Linux shim"
    printf '%s\n' "Installed loop script: \$LOOP_SCRIPT"
    printf '%s\n' "PowerShell runtime: missing"
    printf '%s\n' "Install PowerShell 7 (pwsh) to run loop commands on Linux."
    exit 127
fi

exec pwsh -NoProfile -ExecutionPolicy Bypass -File "\$LOOP_SCRIPT" -SkillLibraryRoot "\$SKILL_LIBRARY_ROOT" "\$@"
SHIM
    chmod +x "$SHIM_PATH"
fi

printf 'Installed loop-standard to %s\n' "$LOOP_STANDARD_DESTINATION"
if [[ "$INSTALL_PLUGIN" == "1" ]]; then
    printf 'Installed plugin to %s\n' "$PLUGIN_DESTINATION"
fi
if [[ "$CREATE_MARKETPLACE" == "1" ]]; then
    printf 'Created local marketplace: %s\n' "$MARKETPLACE_PATH"
    printf '%s\n' "Optional Codex marketplace add command:"
    printf 'codex plugin marketplace add "%s"\n' "$INSTALL_ROOT"
fi
if [[ "$CREATE_SHIM" == "1" ]]; then
    printf 'Created shim: %s\n' "$SHIM_PATH"
    printf '%s\n' "Optional PATH entry:"
    printf '%s\n' "$BIN_DIR"
fi
printf '%s\n' "Verify installation with:"
if [[ "$CREATE_SHIM" == "1" ]]; then
    printf '"%s" -Command doctor\n' "$SHIM_PATH"
else
    printf 'pwsh -NoProfile -ExecutionPolicy Bypass -File "%s/scripts/ai-loop.ps1" -Command doctor -SkillLibraryRoot "%s"\n' "$LOOP_STANDARD_DESTINATION" "$SKILL_LIBRARY_ROOT"
fi

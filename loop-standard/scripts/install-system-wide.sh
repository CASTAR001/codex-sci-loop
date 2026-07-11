#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
    printf '%s\n' "Run this installer with sudo." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
KIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
REPO_ROOT="$(cd "$KIT_ROOT/.." && pwd -P)"
INSTALL_ROOT="/opt/codex-loop-harness"
SKILL_ROOT="/opt/codex-skills"
CALLING_USER="${SUDO_USER:-}"

if [[ -z "$CALLING_USER" || "$CALLING_USER" == "root" ]]; then
    printf '%s\n' "Run through sudo from the administrator's ordinary account." >&2
    exit 1
fi

CALLING_HOME="$(getent passwd "$CALLING_USER" | cut -d: -f6)"
if [[ -z "$CALLING_HOME" || ! -d "$CALLING_HOME" ]]; then
    printf '%s\n' "Cannot resolve home directory for $CALLING_USER." >&2
    exit 1
fi

POWERSHELL_SOURCE="$(readlink -f "$CALLING_HOME/.local/bin/pwsh" 2>/dev/null || true)"
if [[ ! -x /usr/local/bin/pwsh && ! -x /usr/bin/pwsh ]]; then
    if [[ -z "$POWERSHELL_SOURCE" || ! -x "$POWERSHELL_SOURCE" ]]; then
        printf '%s\n' "System pwsh is missing and no user-local pwsh source was found." >&2
        exit 1
    fi
    POWERSHELL_VERSION="$(basename "$(dirname "$POWERSHELL_SOURCE")")"
    install -d -o root -g root -m 0755 /opt/powershell
    rm -rf "/opt/powershell/$POWERSHELL_VERSION"
    cp -a "$(dirname "$POWERSHELL_SOURCE")" "/opt/powershell/$POWERSHELL_VERSION"
    chown -R root:root "/opt/powershell/$POWERSHELL_VERSION"
    chmod -R go-w "/opt/powershell/$POWERSHELL_VERSION"
    chmod -R a+rX "/opt/powershell/$POWERSHELL_VERSION"
    ln -sfn "/opt/powershell/$POWERSHELL_VERSION/pwsh" /usr/local/bin/pwsh
fi

USER_CODEX_BIN=""
if [[ -d "$CALLING_HOME/.nvm/versions/node" ]]; then
    USER_CODEX_BIN="$(find "$CALLING_HOME/.nvm/versions/node" -path '*/bin/codex' -type l | sort -V | tail -n 1)"
fi
if [[ -z "$USER_CODEX_BIN" ]]; then
    USER_CODEX_BIN="$(readlink -f /usr/bin/codex 2>/dev/null || true)"
fi
USER_CODEX_REAL="$(readlink -f "$USER_CODEX_BIN" 2>/dev/null || true)"
if [[ -z "$USER_CODEX_REAL" || ! -f "$USER_CODEX_REAL" ]]; then
    printf '%s\n' "Cannot locate a Codex CLI package to install system-wide." >&2
    exit 1
fi
CODEX_SOURCE="$(cd "$(dirname "$USER_CODEX_REAL")/.." && pwd -P)"
CODEX_STAGE="/opt/codex-cli.new.$$"
rm -rf "$CODEX_STAGE"
cp -a "$CODEX_SOURCE" "$CODEX_STAGE"
rm -rf /opt/codex-cli
mv "$CODEX_STAGE" /opt/codex-cli
chown -R root:root /opt/codex-cli
chmod -R go-w /opt/codex-cli
chmod -R a+rX /opt/codex-cli

if [[ -f /usr/local/lib/codex-audit/real-path ]]; then
    printf '%s\n' "/opt/codex-cli/bin/codex.js" > /usr/local/lib/codex-audit/real-path
else
    ln -sfn /opt/codex-cli/bin/codex.js /usr/local/bin/codex
fi

RESEARCH_SKILLS=(
    research-task-tree
    invariant-contract
    bounded-experiment-loop
    deterministic-verification
    independent-crosscheck
    result-provenance-audit
    manuscript-consistency-audit
    skill-compliance-audit
)

install -d -o root -g root -m 0755 "$SKILL_ROOT"
for skill in "${RESEARCH_SKILLS[@]}"; do
    source="$CALLING_HOME/.codex/skills/$skill"
    if [[ ! -f "$source/SKILL.md" ]]; then
        printf '%s\n' "Missing approved skill source: $source/SKILL.md" >&2
        exit 1
    fi
    rm -rf "$SKILL_ROOT/$skill"
    cp -a "$source" "$SKILL_ROOT/$skill"
done

"$REPO_ROOT/install.sh" \
    --install-root "$INSTALL_ROOT" \
    --skill-library-root "$SKILL_ROOT" \
    --install-plugin \
    --create-shim \
    --create-marketplace \
    --force

chown -R root:root "$INSTALL_ROOT" "$SKILL_ROOT"
chmod -R go-w "$INSTALL_ROOT" "$SKILL_ROOT"
chmod -R a+rX "$INSTALL_ROOT" "$SKILL_ROOT"
ln -sfn "$INSTALL_ROOT/bin/ai-loop" /usr/local/bin/ai-loop

REQUIREMENTS_SOURCE="$KIT_ROOT/system/requirements.toml"
REQUIREMENTS_TARGET="/etc/codex/requirements.toml"
install -d -o root -g root -m 0755 /etc/codex
if [[ -e "$REQUIREMENTS_TARGET" ]] && ! grep -q '^# Managed by codex-sci-loop$' "$REQUIREMENTS_TARGET"; then
    printf '%s\n' "Refusing to replace an unmanaged Codex requirements file: $REQUIREMENTS_TARGET" >&2
    exit 1
fi
install -o root -g root -m 0644 "$REQUIREMENTS_SOURCE" "$REQUIREMENTS_TARGET"

CODEX_LOOP_LIB="/usr/local/lib/codex-loop"
UPSTREAM_CODEX_WRAPPER="$CODEX_LOOP_LIB/upstream-codex-wrapper"
install -d -o root -g root -m 0755 "$CODEX_LOOP_LIB"
if [[ -e /usr/local/bin/codex ]] && ! grep -q '^# Managed by codex-sci-loop$' /usr/local/bin/codex; then
    cp -a /usr/local/bin/codex "$UPSTREAM_CODEX_WRAPPER"
elif [[ ! -e "$UPSTREAM_CODEX_WRAPPER" ]]; then
    ln -s /opt/codex-cli/bin/codex.js "$UPSTREAM_CODEX_WRAPPER"
fi
chown -h root:root "$UPSTREAM_CODEX_WRAPPER"
install -o root -g root -m 0755 "$KIT_ROOT/system/codex-loop-wrapper.sh" /usr/local/bin/codex

PLUGIN_SKILLS="$INSTALL_ROOT/plugins/codex-loop-harness/skills"
LOOP_SKILLS=(
    loop-goal-bootstrap
    loop-supervisor
    loop-auditor
    loop-recovery
    research-loop-orchestrator
)

link_user_skills() {
    local user="$1"
    local uid="$2"
    local gid="$3"
    local home="$4"

    if [[ ! -d "$home/.codex" ]]; then
        install -d -o "$uid" -g "$gid" -m 0700 "$home/.codex"
    fi
    if [[ ! -d "$home/.codex/skills" ]]; then
        install -d -o "$uid" -g "$gid" -m 0755 "$home/.codex/skills"
    fi

    for skill in "${LOOP_SKILLS[@]}"; do
        local target="$home/.codex/skills/$skill"
        local source="$PLUGIN_SKILLS/$skill"
        if [[ -L "$target" ]]; then
            ln -sfn "$source" "$target"
            chown -h "$uid:$gid" "$target"
        elif [[ -e "$target" ]]; then
            printf '%s\n' "Preserved existing skill: $target"
        else
            ln -s "$source" "$target"
            chown -h "$uid:$gid" "$target"
        fi
    done

    if [[ -x /usr/local/bin/codex ]] && command -v runuser >/dev/null 2>&1; then
        if ! runuser -u "$user" -- env HOME="$home" /usr/local/bin/codex plugin marketplace add "$INSTALL_ROOT"; then
            printf '%s\n' "Marketplace registration already exists or failed for $user; continuing with direct skill links." >&2
        fi
        if ! runuser -u "$user" -- env HOME="$home" /usr/local/bin/codex plugin add codex-loop-harness@loop-harness-local; then
            printf '%s\n' "Plugin CLI install failed for $user; direct skill links remain active." >&2
        fi
    fi
}

while IFS=: read -r user _ uid gid _ home shell; do
    if (( uid < 1000 )) || [[ "$shell" == *nologin ]] || [[ "$shell" == *false ]] || [[ ! -d "$home" ]]; then
        continue
    fi
    link_user_skills "$user" "$uid" "$gid" "$home"
done < <(getent passwd)

install -d -o root -g root -m 0755 /etc/skel/.codex /etc/skel/.codex/skills
for skill in "${LOOP_SKILLS[@]}"; do
    ln -sfn "$PLUGIN_SKILLS/$skill" "/etc/skel/.codex/skills/$skill"
    chown -h root:root "/etc/skel/.codex/skills/$skill"
done

if ! command -v claude-mimo >/dev/null 2>&1; then
    printf '%s\n' "Warning: claude-mimo is not available on the root PATH." >&2
fi

/usr/local/bin/ai-loop -Command doctor
/usr/local/bin/codex --version
/usr/bin/python3 "$INSTALL_ROOT/loop-standard/scripts/Test-GoalLoopHook.py"
/usr/bin/python3 "$INSTALL_ROOT/loop-standard/scripts/Test-CodexHookUpdateCheck.py"
printf '%s\n' '{"hook_event_name":"UserPromptSubmit","cwd":"/tmp","prompt":"ordinary prompt"}' |
    /usr/bin/python3 "$INSTALL_ROOT/plugins/codex-loop-harness/scripts/goal-loop-bootstrap.py"
runuser -u "$CALLING_USER" -- env \
    HOME="$CALLING_HOME" \
    PATH="/usr/local/bin:/usr/bin:/bin" \
    /usr/local/bin/ai-loop -Command doctor
printf '%s\n' "System-wide loop installation: OK"
printf '%s\n' "Harness: $INSTALL_ROOT"
printf '%s\n' "Skills: $SKILL_ROOT"
printf '%s\n' "Command: /usr/local/bin/ai-loop"
printf '%s\n' "Users must start a new Codex thread to discover the new skills."

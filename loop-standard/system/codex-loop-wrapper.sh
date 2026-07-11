#!/usr/bin/env bash
# Managed by codex-sci-loop
set -u

/usr/bin/python3 \
    /opt/codex-loop-harness/plugins/codex-loop-harness/scripts/check-codex-hook-after-update.py \
    --codex-real /opt/codex-cli/bin/codex.js || true

exec /usr/local/lib/codex-loop/upstream-codex-wrapper "$@"

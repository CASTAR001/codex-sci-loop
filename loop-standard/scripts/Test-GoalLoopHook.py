#!/usr/bin/env python3

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
HOOK = REPO_ROOT / "plugins/codex-loop-harness/scripts/goal-loop-bootstrap.py"


def write_fake_ai_loop(path: Path) -> None:
    path.write_text(
        """#!/usr/bin/env bash
set -euo pipefail
printf '%s\\n' "$*" >> "$FAKE_AI_LOOP_CALLS"
if [[ "$*" == *"-Command init"* ]]; then
  mkdir -p "$FAKE_PROJECT_ROOT/.ai-loop"
  printf '{"status":"initialized"}\\n' > "$FAKE_PROJECT_ROOT/.ai-loop/status.json"
fi
if [[ "$*" == *"-Command validate-loop"* && "${FAKE_VALIDATE_FAIL:-0}" == "1" ]]; then
  printf 'Loop validation: FAILED\\n'
  printf '%s\\n' '- loop.config.json missing required property: skill_ledgers'
  printf '%s\\n' "The property 'skill_ledgers' cannot be found on this object."
  printf 'Verify that the property exists.\\n'
  exit 2
fi
""",
        encoding="utf-8",
    )
    path.chmod(0o755)


def invoke(project: Path, fake_ai_loop: Path, prompt: str, fail_validate: bool = False):
    calls = project / "calls.txt"
    event = {
        "hook_event_name": "UserPromptSubmit",
        "session_id": "fixture-session",
        "turn_id": "fixture-turn",
        "cwd": str(project),
        "prompt": prompt,
    }
    env = os.environ.copy()
    env["FAKE_AI_LOOP_CALLS"] = str(calls)
    env["FAKE_PROJECT_ROOT"] = str(project)
    if fail_validate:
        env["FAKE_VALIDATE_FAIL"] = "1"
    result = subprocess.run(
        [sys.executable, str(HOOK), "--ai-loop", str(fake_ai_loop)],
        input=json.dumps(event),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=env,
        check=False,
    )
    output = json.loads(result.stdout) if result.stdout.strip() else None
    call_lines = calls.read_text(encoding="utf-8").splitlines() if calls.exists() else []
    return result, output, call_lines


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="goal-loop-hook-") as temp:
        root = Path(temp)
        project = root / "project"
        project.mkdir()
        subprocess.run(["git", "-C", str(project), "init", "-q"], check=True)
        fake_ai_loop = root / "ai-loop"
        write_fake_ai_loop(fake_ai_loop)

        result, output, calls = invoke(project, fake_ai_loop, "Fix the README typo.")
        require(result.returncode == 0 and output is None and calls == [], "non-goal prompt should be ignored")

        result, output, calls = invoke(project, fake_ai_loop, "Create a goal for this repository.")
        require(result.returncode == 0, "goal bootstrap should exit successfully")
        require(len(calls) == 2 and "-Command init" in calls[0], "missing init call")
        require("-Command validate-loop" in calls[1], "missing validate-loop call")
        require("additionalContext" in output["hookSpecificOutput"], "missing additional context")

        (project / "calls.txt").unlink()
        result, output, calls = invoke(project, fake_ai_loop, "Continue the active goal.")
        require(len(calls) == 1 and "-Command validate-loop" in calls[0], "existing loop should only validate")

        result, output, calls = invoke(project, fake_ai_loop, "Start a durable goal.", fail_validate=True)
        require(output.get("decision") == "block", "validation failure should block the prompt")
        reason = output.get("reason", "")
        require("validate-loop failed" in reason, "block reason should identify validation")
        require("skill_ledgers" in reason, "block reason should retain the failing property name")
        require("Verify that the property exists." in reason, "block reason should retain the final diagnostic line")
        require(" | " in reason, "block reason should delimit retained diagnostic lines")
        require(len(reason) <= 1200, "block reason should remain bounded")

    print("Goal loop hook test: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

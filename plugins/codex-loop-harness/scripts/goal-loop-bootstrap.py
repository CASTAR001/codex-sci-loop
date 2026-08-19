#!/usr/bin/env python3
"""Bootstrap .ai-loop before a goal or loop prompt reaches Codex."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path


TRIGGER_PATTERN = re.compile(
    r"(?:\bgoal\b|\bcreate_goal\b|\bupdate_goal\b|\bget_goal\b|"
    r"\bdurable objective\b|\bactive objective\b|\bai[- ]?loop\b|"
    r"\bsupervisor[- ]worker loop\b|创建(?:一个)?(?:长期|持久)?目标|"
    r"开始(?:一个)?(?:长期|持久)?目标|目标(?:刚刚|已经)?开始|"
    r"长期目标|持久目标|使用loop|用loop)",
    re.IGNORECASE,
)

FAILURE_DETAIL_LINES = 4
FAILURE_DETAIL_CHARS = 1000


def emit(value: dict[str, object]) -> None:
    print(json.dumps(value, ensure_ascii=False, separators=(",", ":")))


def block(reason: str) -> int:
    emit({"decision": "block", "reason": reason})
    return 0


def additional_context(message: str) -> int:
    emit(
        {
            "hookSpecificOutput": {
                "hookEventName": "UserPromptSubmit",
                "additionalContext": message,
            }
        }
    )
    return 0


def run(command: list[str], cwd: Path) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(
            command,
            cwd=cwd,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
            timeout=120,
        )
    except subprocess.TimeoutExpired as exc:
        output = exc.stdout if isinstance(exc.stdout, str) else ""
        return subprocess.CompletedProcess(command, 124, output + "\ncommand timed out")
    except OSError as exc:
        return subprocess.CompletedProcess(command, 127, str(exc))


def concise_failure(label: str, result: subprocess.CompletedProcess[str]) -> str:
    lines = [line.strip() for line in result.stdout.splitlines() if line.strip()]
    if lines:
        detail = " | ".join(lines[-FAILURE_DETAIL_LINES:])
        if len(detail) > FAILURE_DETAIL_CHARS:
            detail = detail[: FAILURE_DETAIL_CHARS - 3].rstrip() + "..."
    else:
        detail = f"exit code {result.returncode}"
    return f"Goal loop bootstrap blocked: {label} failed ({detail})."


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ai-loop", default="/usr/local/bin/ai-loop")
    args = parser.parse_args()

    try:
        event = json.load(sys.stdin)
    except (json.JSONDecodeError, OSError) as exc:
        return block(f"Goal loop bootstrap blocked: invalid hook input ({exc}).")

    if event.get("hook_event_name") != "UserPromptSubmit":
        return 0

    prompt = str(event.get("prompt", ""))
    if not TRIGGER_PATTERN.search(prompt):
        return 0

    cwd = Path(str(event.get("cwd", ""))).expanduser()
    if not cwd.is_dir():
        return block("Goal loop bootstrap blocked: hook cwd is missing or invalid.")

    git_root_result = run(["git", "-C", str(cwd), "rev-parse", "--show-toplevel"], cwd)
    if git_root_result.returncode != 0:
        return block("Goal loop bootstrap blocked: the current directory is not inside a Git repository.")

    git_root = Path(git_root_result.stdout.strip()).resolve()
    ai_loop = Path(args.ai_loop)
    if not ai_loop.is_file():
        return block(f"Goal loop bootstrap blocked: ai-loop is missing at {ai_loop}.")

    status_path = git_root / ".ai-loop" / "status.json"
    initialized = status_path.is_file()
    if not initialized:
        init_result = run(
            [
                str(ai_loop),
                "-Command",
                "init",
                "-ProjectRoot",
                str(git_root),
                "-CreateAgentsBootstrap",
            ],
            git_root,
        )
        if init_result.returncode != 0:
            return block(concise_failure("ai-loop init", init_result))

    validate_result = run(
        [str(ai_loop), "-Command", "validate-loop", "-ProjectRoot", str(git_root)],
        git_root,
    )
    if validate_result.returncode != 0:
        return block(concise_failure("validate-loop", validate_result))

    action = "validated existing" if initialized else "initialized and validated"
    return additional_context(
        f"Managed goal hook {action} .ai-loop at {git_root}. "
        "Continue this goal through the loop workflow before ordinary task work. "
        "Use claude-mimo as the default external Worker, require Worker preflight, "
        "and do not enable Yolo unless the user explicitly authorizes it."
    )


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Silently verify managed hook compatibility after a Codex version change."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path


CHECK_REVISION = "1"


def run(command: list[str]) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(
            command,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
            timeout=60,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        return subprocess.CompletedProcess(command, 127, str(exc))


def report_failure(message: str, hook_mode: bool) -> int:
    warning = f"Codex hook compatibility warning: {message}"
    if hook_mode:
        print(json.dumps({"continue": True, "systemMessage": warning}, separators=(",", ":")))
    else:
        print(warning, file=sys.stderr)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--codex-real", default="/opt/codex-cli/bin/codex.js")
    parser.add_argument("--requirements", default="/etc/codex/requirements.toml")
    parser.add_argument(
        "--hook-script",
        default="/opt/codex-loop-harness/plugins/codex-loop-harness/scripts/goal-loop-bootstrap.py",
    )
    parser.add_argument(
        "--hook-test",
        default="/opt/codex-loop-harness/loop-standard/scripts/Test-GoalLoopHook.py",
    )
    parser.add_argument("--state-root", default="")
    parser.add_argument("--hook-mode", action="store_true")
    args = parser.parse_args()

    codex_real = Path(args.codex_real)
    version_result = run(["/usr/bin/node", str(codex_real), "--version"])
    if version_result.returncode != 0:
        return report_failure("the installed Codex version cannot be read.", args.hook_mode)
    version = version_result.stdout.strip()

    state_root = Path(args.state_root) if args.state_root else Path.home() / ".cache/codex-loop"
    marker = state_root / "hook-check-version"
    expected_marker = f"{version}|{CHECK_REVISION}"
    if marker.is_file() and marker.read_text(encoding="utf-8").strip() == expected_marker:
        return 0

    requirements = Path(args.requirements)
    hook_script = Path(args.hook_script)
    hook_test = Path(args.hook_test)
    if not requirements.is_file():
        return report_failure(f"managed requirements are missing at {requirements}.", args.hook_mode)
    requirements_text = requirements.read_text(encoding="utf-8")
    required_fragments = (
        "hooks = true",
        "[[hooks.UserPromptSubmit]]",
        str(hook_script),
    )
    if any(fragment not in requirements_text for fragment in required_fragments):
        return report_failure("managed goal hook configuration is incomplete.", args.hook_mode)
    if not hook_script.is_file() or not hook_test.is_file():
        return report_failure("the goal hook script or its self-test is missing.", args.hook_mode)

    features_result = run(["/usr/bin/node", str(codex_real), "features", "list"])
    hooks_enabled = re.search(r"(?m)^hooks\s+\S+\s+true\s*$", features_result.stdout)
    if features_result.returncode != 0 or hooks_enabled is None:
        return report_failure(
            f"{version} no longer reports the hooks feature as enabled.",
            args.hook_mode,
        )

    test_result = run(["/usr/bin/python3", str(hook_test)])
    if test_result.returncode != 0 or "Goal loop hook test: OK" not in test_result.stdout:
        return report_failure(f"the goal hook self-test failed under {version}.", args.hook_mode)

    state_root.mkdir(parents=True, exist_ok=True)
    marker.write_text(expected_marker + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

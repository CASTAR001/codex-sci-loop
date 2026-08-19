#!/usr/bin/env python3
"""Regression coverage for StrictMode-safe validation of incomplete loop JSON."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import tempfile
from collections.abc import Callable
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
SOURCE_LOOP = REPO_ROOT / ".ai-loop"
VALIDATOR = REPO_ROOT / "loop-standard/scripts/validate-loop.ps1"
POWERSHELL = shutil.which("powershell.exe" if os.name == "nt" else "pwsh")
STRICTMODE_LEAKS = (
    "cannot be found on this object",
    "Verify that the property exists",
    "PropertyNotFoundStrict",
)


def read_json(path: Path) -> dict[str, object]:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def write_json(path: Path, value: dict[str, object]) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def make_fixture(root: Path) -> None:
    shutil.copytree(SOURCE_LOOP, root / ".ai-loop")
    status_path = root / ".ai-loop/status.json"
    status = read_json(status_path)
    status["phases"] = []
    status["current_phase"] = None
    write_json(status_path, status)


def invoke_validator(root: Path) -> subprocess.CompletedProcess[str]:
    if POWERSHELL is None:
        raise RuntimeError("PowerShell is required for validate-loop regression tests")
    return subprocess.run(
        [
            POWERSHELL,
            "-NoProfile",
            "-File",
            str(VALIDATOR),
            "-ProjectRoot",
            str(root),
        ],
        cwd=REPO_ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
        timeout=120,
    )


def remove_property(relative_path: str, name: str) -> Callable[[Path], None]:
    def mutate(root: Path) -> None:
        path = root / relative_path
        value = read_json(path)
        value.pop(name, None)
        write_json(path, value)

    return mutate


def replace_status(**changes: object) -> Callable[[Path], None]:
    def mutate(root: Path) -> None:
        path = root / ".ai-loop/status.json"
        status = read_json(path)
        status.update(changes)
        write_json(path, status)

    return mutate


def replace_transition_log(root: Path) -> None:
    path = root / ".ai-loop/events/state-transitions.ndjson"
    path.write_text(
        json.dumps(
            {
                "ts": "2026-08-19T00:00:00Z",
                "from_status": None,
                "to_status": "started",
                "actor": "fixture",
                "action": "fixture",
                "paths": [],
            },
            separators=(",", ":"),
        )
        + "\n",
        encoding="utf-8",
    )


def require_failure(name: str, result: subprocess.CompletedProcess[str], expected: str) -> None:
    if result.returncode == 0:
        raise AssertionError(f"{name}: validator unexpectedly passed")
    if expected not in result.stdout:
        raise AssertionError(f"{name}: expected {expected!r}; output was:\n{result.stdout}")
    leaked = [marker for marker in STRICTMODE_LEAKS if marker in result.stdout]
    if leaked:
        raise AssertionError(f"{name}: leaked StrictMode exception markers {leaked}:\n{result.stdout}")


def main() -> int:
    cases: list[tuple[str, Callable[[Path], None], str]] = [
        (
            "config-decisions",
            remove_property(".ai-loop/loop.config.json", "decisions"),
            "loop.config.json missing required property: decisions",
        ),
        (
            "config-evidence-ledgers",
            remove_property(".ai-loop/loop.config.json", "evidence_ledgers"),
            "loop.config.json missing required property: evidence_ledgers",
        ),
        (
            "config-skill-ledgers",
            remove_property(".ai-loop/loop.config.json", "skill_ledgers"),
            "loop.config.json missing required property: skill_ledgers",
        ),
        (
            "status-project-name",
            remove_property(".ai-loop/status.json", "project_name"),
            "status.json missing project_name",
        ),
        (
            "status-phases",
            remove_property(".ai-loop/status.json", "phases"),
            "status.json missing phases array",
        ),
        (
            "status-current-phase",
            remove_property(".ai-loop/status.json", "current_phase"),
            "status.json missing current_phase property",
        ),
        (
            "current-phase-id",
            replace_status(current_phase={"status": "started"}),
            "current_phase missing phase_id",
        ),
        (
            "current-phase-status",
            replace_status(current_phase={"phase_id": "fixture-phase"}),
            "current_phase missing status",
        ),
        (
            "phase-id",
            replace_status(phases=[{"status": "started"}]),
            "status.json contains phase with blank phase_id",
        ),
        (
            "phase-status",
            replace_status(phases=[{"phase_id": "fixture-phase"}]),
            "phase fixture-phase missing status",
        ),
        (
            "transition-phase-id",
            replace_transition_log,
            "state-transitions.ndjson line 1 missing required property: phase_id",
        ),
    ]

    with tempfile.TemporaryDirectory(prefix="validate-loop-properties-") as temp:
        temp_root = Path(temp)
        valid_root = temp_root / "valid"
        make_fixture(valid_root)
        valid_result = invoke_validator(valid_root)
        if valid_result.returncode != 0:
            raise AssertionError(f"normalized fixture should validate:\n{valid_result.stdout}")

        for name, mutate, expected in cases:
            case_root = temp_root / name
            make_fixture(case_root)
            mutate(case_root)
            require_failure(name, invoke_validator(case_root), expected)

    print(f"Validate-loop missing-property regression: OK ({len(cases)} cases)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

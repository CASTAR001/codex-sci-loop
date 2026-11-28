#!/usr/bin/env python3
"""Inspect a legacy Python phase project or validate the native plugin distribution."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

sys.dont_write_bytecode = True
from loop_io import LoopError, PHASE_ID_RE, git, read_json, resolve_project

VERSION = "1.4.0-alpha.1"
SCHEMA_VERSION = "2.0"
PHASE_STATES = {"accepted", "blocked", "rework", "started", "collecting", "evidence_collected", "audit_prepared"}


def validate_repositories(root: Path, config: dict[str, Any]) -> None:
    repositories = config.get("evidence_repositories")
    if not isinstance(repositories, list) or not repositories or not all(isinstance(item, str) for item in repositories):
        raise LoopError("evidence_repositories must be a non-empty string array")
    resolved = set()
    for raw in repositories:
        relative = Path(raw)
        if not raw or relative.is_absolute() or ".." in relative.parts:
            raise LoopError(f"invalid evidence repository path: {raw!r}")
        candidate = (root / relative).resolve()
        if not candidate.is_relative_to(root):
            raise LoopError(f"evidence repository escapes the project root: {raw}")
        if not candidate.is_dir():
            raise LoopError(f"evidence repository is not a directory: {raw}")
        git_root = Path(git(candidate, "rev-parse", "--show-toplevel").strip()).resolve()
        if git_root != candidate:
            raise LoopError(f"evidence repository must resolve to its Git root: {raw}")
        if candidate in resolved:
            raise LoopError(f"duplicate evidence repository: {raw}")
        resolved.add(candidate)
    if root not in resolved:
        raise LoopError("evidence_repositories must include the project root '.'")


def read_phase_state(root: Path) -> tuple[dict[str, Any], dict[str, Any]]:
    base = root / ".ai-loop"
    config = read_json(base / "loop.config.json")
    if config.get("runtime_mode") != "native-codex-loop" or config.get("executor") != "codex":
        raise LoopError("this is not a legacy Python phase project; use the tool that created its state")
    status = read_json(base / "status.json")
    if config.get("schema_version") != SCHEMA_VERSION or status.get("schema_version") != SCHEMA_VERSION:
        raise LoopError(f"legacy Python phase state requires schema {SCHEMA_VERSION}")
    phases = status.get("phases")
    if not isinstance(phases, list):
        raise LoopError("status phases must be an array")
    ids: set[str] = set()
    for phase in phases:
        phase_id = phase.get("phase_id") if isinstance(phase, dict) else None
        if not isinstance(phase_id, str) or not PHASE_ID_RE.fullmatch(phase_id):
            raise LoopError("invalid phase record in status")
        if phase_id in ids:
            raise LoopError(f"duplicate phase id: {phase_id}")
        if not isinstance(phase.get("status"), str) or phase["status"] not in PHASE_STATES:
            raise LoopError("unknown phase state")
        ids.add(phase_id)
    if "current_phase" not in status or status["current_phase"] != (phases[-1] if phases else None):
        raise LoopError("current phase disagrees with phase history")
    return config, status


def cmd_validate(root: Path, _args: argparse.Namespace) -> None:
    config, _status = read_phase_state(root)
    base = root / ".ai-loop"
    required = (
        "README.md", "memory/activeContext.md", "memory/constraint-ledger.md",
        "gates/pre-action-check.md", "prompts/codex-loop.prompt.md",
    )
    missing = [f".ai-loop/{name}" for name in required if not (base / name).is_file()]
    if missing:
        raise LoopError("missing control files: " + ", ".join(missing))
    validate_repositories(root, config)
    print("VALIDATE: OK")


def cmd_resume(root: Path, args: argparse.Namespace) -> None:
    _config, status = read_phase_state(root)
    phase = status["current_phase"]
    phase_id = phase["phase_id"] if phase else ""
    state = phase["status"] if phase else "none"
    if state in {"none", "accepted"}:
        decision = "READY_FOR_NEXT_PHASE"
        next_step = "Read the existing phase records before planning any new work."
    elif state == "blocked":
        decision = "BLOCKED"
        next_step = "Inspect the recorded blocking condition before continuing."
    elif state == "rework":
        decision = "REWORK_REQUIRED"
        next_step = "Inspect the recorded audit findings before planning any rework."
    else:
        decision = "CONTINUE_ACTIVE_PHASE"
        next_step = f"Inspect the recorded objective and evidence under .ai-loop/runs/{phase_id}/."
        if state == "collecting":
            next_step = "Verification was interrupted. Inspect possible side effects before running another check."
    payload = {
        "decision": decision, "phase_id": phase_id, "status": state, "next": next_step,
        "read_only": True,
    }
    if state in {"none", "accepted"}:
        payload["acceptance_scope"] = "recorded historical decision only" if phase else None
        payload["audit_snapshot_sha256"] = phase.get("audit_snapshot_sha256") if phase else None
    if args.json:
        print(json.dumps(payload, ensure_ascii=False, separators=(",", ":")))
    else:
        print(f"LEGACY PHASE (read-only) — {decision}: {phase_id} {state}")
        print(f"NEXT: {next_step}")


def cmd_validate_distribution() -> None:
    plugin_root = Path(__file__).resolve().parents[1]
    manifest = read_json(plugin_root / ".codex-plugin" / "plugin.json")
    if manifest.get("id") != "codex-sci-loop" or manifest.get("name") != "codex-sci-loop" or manifest.get("version") != VERSION:
        raise LoopError("plugin manifest identity does not match the bundled version")
    required = {"task-checkpoint", "research-verification"}
    skills = plugin_root / "skills"
    present = {path.name for path in skills.iterdir() if path.is_dir() and (path / "SKILL.md").is_file()}
    if manifest.get("skills") != "./skills/" or present != required:
        raise LoopError(f"skill set mismatch: expected {sorted(required)}, got {sorted(present)}")
    if "hooks" in manifest or (plugin_root / "hooks").exists():
        raise LoopError("native checkpoints require no lifecycle hooks")
    scripts = plugin_root / "scripts"
    if not all((scripts / name).is_file() for name in ("checkpoint.py", "loop_io.py")):
        raise LoopError("native checkpoint scripts are missing")
    print("DISTRIBUTION: OK")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", action="version", version=VERSION)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("validate-distribution")
    for command in ("validate", "resume"):
        item = commands.add_parser(command)
        item.add_argument("--project-root", required=True)
        if command == "resume":
            item.add_argument("--json", action="store_true")
    args = parser.parse_args()
    try:
        if args.command == "validate-distribution":
            cmd_validate_distribution()
        elif args.command == "validate":
            cmd_validate(resolve_project(args.project_root), args)
        else:
            cmd_resume(resolve_project(args.project_root), args)
    except (LoopError, OSError, UnicodeError) as exc:
        print(f"sci-loop: ERROR: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

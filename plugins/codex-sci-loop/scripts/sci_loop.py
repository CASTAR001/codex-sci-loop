#!/usr/bin/env python3
"""Project-local phase control for the portable codex-sci-loop plugin."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any, NoReturn


VERSION = "1.0.0"
SCHEMA_VERSION = "2.0"
PHASE_ID_RE = re.compile(r"^[a-z0-9][a-z0-9._-]{0,95}$")
DECIDED_PHASE_STATES = {"accepted", "rework", "blocked"}
CONTROL_PATHSPECS = (".", ":(exclude).ai-loop", ":(exclude).ai-loop/**")


class LoopError(RuntimeError):
    """A safe, operator-facing loop failure."""


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise LoopError(f"required file is missing: {path}") from exc
    except (OSError, json.JSONDecodeError) as exc:
        raise LoopError(f"cannot read valid JSON from {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise LoopError(f"JSON root must be an object: {path}")
    return value


def atomic_text(path: Path, value: str, mode: int = 0o600) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    temporary_path = Path(temporary)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(value)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temporary_path, mode)
        os.replace(temporary_path, path)
    finally:
        temporary_path.unlink(missing_ok=True)


def atomic_json(path: Path, value: dict[str, Any]) -> None:
    atomic_text(path, json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def run(command: list[str], cwd: Path, timeout: int = 120) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(
            command,
            cwd=cwd,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired as exc:
        output = exc.stdout if isinstance(exc.stdout, str) else ""
        return subprocess.CompletedProcess(command, 124, output + "\ncommand timed out\n")
    except OSError as exc:
        return subprocess.CompletedProcess(command, 127, f"{exc}\n")


def git(root: Path, *arguments: str, timeout: int = 120) -> str:
    result = run(["git", "-C", str(root), *arguments], root, timeout)
    if result.returncode != 0:
        detail = result.stdout.strip().splitlines()
        message = detail[-1][:300] if detail else f"exit {result.returncode}"
        raise LoopError(f"git {' '.join(arguments)} failed: {message}")
    return result.stdout


def resolve_project(raw: str) -> Path:
    candidate = Path(raw).expanduser().resolve()
    if not candidate.is_dir():
        raise LoopError(f"project root is not a directory: {candidate}")
    resolved = Path(git(candidate, "rev-parse", "--show-toplevel").strip()).resolve()
    if resolved != candidate:
        raise LoopError(f"project root must be the Git root: {resolved}")
    return resolved


def control_paths(root: Path) -> dict[str, Path]:
    base = root / ".ai-loop"
    return {
        "base": base,
        "config": base / "loop.config.json",
        "status": base / "status.json",
        "runs": base / "runs",
        "audits": base / "audits",
        "events": base / "events" / "state-transitions.ndjson",
    }


def append_event(paths: dict[str, Path], event: str, phase_id: str, **fields: Any) -> None:
    payload = {"event": event, "phase_id": phase_id, "at": utc_now(), **fields}
    paths["events"].parent.mkdir(parents=True, exist_ok=True)
    descriptor = os.open(paths["events"], os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)
    os.chmod(paths["events"], 0o600)
    with os.fdopen(descriptor, "a", encoding="utf-8", newline="\n") as handle:
        handle.write(json.dumps(payload, ensure_ascii=False, separators=(",", ":")) + "\n")


def default_config() -> dict[str, Any]:
    return {
        "schema_version": SCHEMA_VERSION,
        "runtime_mode": "native-codex-loop",
        "executor": "codex",
        "evidence_repositories": ["."],
    }


def default_status() -> dict[str, Any]:
    return {
        "schema_version": SCHEMA_VERSION,
        "current_phase": None,
        "phases": [],
        "last_decision": None,
    }


def cmd_init(root: Path, _args: argparse.Namespace) -> None:
    paths = control_paths(root)
    if paths["base"].exists():
        raise LoopError(f"refusing to overwrite existing control state: {paths['base']}")
    templates = {
        "README.md": "# Project loop state\n\nThis directory contains durable phase evidence for native Codex work.\n",
        "memory/activeContext.md": "# Active Context\n\nNo phase has started.\n",
        "memory/constraint-ledger.md": "# Constraint Ledger\n\n- Preserve user work and fail closed on missing evidence.\n",
        "gates/pre-action-check.md": "# Pre-action Check\n\n- Confirm scope, safety, evidence, and verification before acting.\n",
        "prompts/codex-loop.prompt.md": "# Codex Loop\n\nUse one bounded phase at a time and accept only audited evidence.\n",
    }
    for relative, contents in templates.items():
        atomic_text(paths["base"] / relative, contents)
    atomic_json(paths["config"], default_config())
    atomic_json(paths["status"], default_status())
    paths["runs"].mkdir(parents=True, exist_ok=True)
    paths["audits"].mkdir(parents=True, exist_ok=True)
    append_event(paths, "loop_initialized", "")
    print(f"INITIALIZED {paths['base']}")


def validate_project(root: Path) -> tuple[dict[str, Path], dict[str, Any], dict[str, Any]]:
    paths = control_paths(root)
    required = [
        paths["config"],
        paths["status"],
        paths["base"] / "README.md",
        paths["base"] / "memory" / "activeContext.md",
        paths["base"] / "memory" / "constraint-ledger.md",
        paths["base"] / "gates" / "pre-action-check.md",
        paths["base"] / "prompts" / "codex-loop.prompt.md",
    ]
    missing = [str(path.relative_to(root)) for path in required if not path.is_file()]
    if missing:
        raise LoopError("missing control files: " + ", ".join(missing))
    config = read_json(paths["config"])
    status = read_json(paths["status"])
    if config.get("schema_version") != SCHEMA_VERSION or status.get("schema_version") != SCHEMA_VERSION:
        raise LoopError("unsupported loop schema; explicit migration is required")
    if config.get("runtime_mode") != "native-codex-loop" or config.get("executor") != "codex":
        raise LoopError("loop config must select the native Codex executor")
    repositories = config.get("evidence_repositories")
    if not isinstance(repositories, list) or not repositories or not all(isinstance(item, str) for item in repositories):
        raise LoopError("evidence_repositories must be a non-empty string array")
    resolve_evidence_repositories(root, config)
    if not isinstance(status.get("phases"), list):
        raise LoopError("status phases must be an array")
    return paths, config, status


def resolve_evidence_repositories(root: Path, config: dict[str, Any]) -> dict[str, Path]:
    resolved: dict[str, Path] = {}
    for raw in config.get("evidence_repositories", []):
        relative = Path(raw)
        if not raw or relative.is_absolute() or ".." in relative.parts:
            raise LoopError(f"invalid evidence repository path: {raw!r}")
        candidate = (root / relative).resolve()
        try:
            candidate.relative_to(root)
        except ValueError as exc:
            raise LoopError(f"evidence repository escapes the project root: {raw}") from exc
        if not candidate.is_dir():
            raise LoopError(f"evidence repository is not a directory: {raw}")
        git_root = Path(git(candidate, "rev-parse", "--show-toplevel").strip()).resolve()
        if git_root != candidate:
            raise LoopError(f"evidence repository must resolve to its Git root: {raw}")
        key = "." if candidate == root else candidate.relative_to(root).as_posix()
        if key in resolved:
            raise LoopError(f"duplicate evidence repository: {key}")
        resolved[key] = candidate
    if "." not in resolved:
        raise LoopError("evidence_repositories must include the project root '.'")
    return resolved


def prefix_lines(repository: str, value: str) -> str:
    if repository == ".":
        return value
    return "".join(f"{repository}/{line}\n" for line in value.splitlines() if line)


def business_status(repository_key: str, repository: Path) -> str:
    arguments = ["status", "--short"]
    if repository_key == ".":
        arguments.extend(["--", *CONTROL_PATHSPECS])
    return git(repository, *arguments)


def cmd_validate(root: Path, _args: argparse.Namespace) -> None:
    validate_project(root)
    print("VALIDATE: OK")


def cmd_resume(root: Path, args: argparse.Namespace) -> None:
    _paths, _config, status = validate_project(root)
    phase = status.get("current_phase")
    if not isinstance(phase, dict) or phase.get("status") == "accepted":
        payload = {
            "decision": "READY_FOR_NEXT_PHASE",
            "phase_id": "",
            "status": phase.get("status", "none") if isinstance(phase, dict) else "none",
            "next": "Start one bounded phase.",
        }
    elif phase.get("status") == "blocked":
        payload = {
            "decision": "BLOCKED",
            "phase_id": str(phase.get("phase_id", "")),
            "status": "blocked",
            "next": "Resolve the recorded blocking condition before continuing.",
        }
    elif phase.get("status") == "rework":
        payload = {
            "decision": "REWORK_REQUIRED",
            "phase_id": str(phase.get("phase_id", "")),
            "status": "rework",
            "next": "Start a bounded follow-up derived only from the recorded audit findings.",
        }
    else:
        phase_id = str(phase.get("phase_id", ""))
        state = str(phase.get("status", "unknown"))
        next_by_state = {
            "started": f"Execute .ai-loop/runs/{phase_id}/prompt.md, then collect evidence.",
            "evidence_collected": f"Prepare the audit pack for {phase_id}.",
            "audit_prepared": f"Run an isolated audit for {phase_id} and record its decision.",
        }
        payload = {
            "decision": "CONTINUE_ACTIVE_PHASE",
            "phase_id": phase_id,
            "status": state,
            "next": next_by_state.get(state, "Inspect durable phase state."),
        }
    if args.json:
        print(json.dumps(payload, ensure_ascii=False, separators=(",", ":")))
    else:
        print(f"{payload['decision']}: {payload['phase_id']} {payload['status']}")
        print(f"NEXT: {payload['next']}")


def update_phase(document: dict[str, Any], phase_id: str, **changes: Any) -> dict[str, Any]:
    phases = document.get("phases", [])
    updated = False
    for index, phase in enumerate(phases):
        if isinstance(phase, dict) and phase.get("phase_id") == phase_id:
            phases[index] = {**phase, **changes}
            updated = True
    if not updated:
        raise LoopError(f"phase is missing from status: {phase_id}")
    current = document.get("current_phase")
    if isinstance(current, dict) and current.get("phase_id") == phase_id:
        document["current_phase"] = {**current, **changes}
    document["phases"] = phases
    return document


def cmd_start(root: Path, args: argparse.Namespace) -> None:
    paths, config, status = validate_project(root)
    if not PHASE_ID_RE.fullmatch(args.phase_id):
        raise LoopError("phase id must be lowercase and contain only letters, digits, dot, underscore, or dash")
    current = status.get("current_phase")
    if isinstance(current, dict) and current.get("status") != "accepted":
        raise LoopError(f"another phase is active: {current.get('phase_id')}")
    if any(isinstance(item, dict) and item.get("phase_id") == args.phase_id for item in status["phases"]):
        raise LoopError(f"phase id already exists: {args.phase_id}")
    run_dir = paths["runs"] / args.phase_id
    run_dir.mkdir(parents=True, exist_ok=False)
    repositories = resolve_evidence_repositories(root, config)
    repository_heads = {key: git(path, "rev-parse", "HEAD").strip() for key, path in repositories.items()}
    base = repository_heads["."]
    status_before = "".join(prefix_lines(key, business_status(key, path)) for key, path in repositories.items())
    started_at = utc_now()
    phase = {
        "phase_id": args.phase_id,
        "title": args.title,
        "objective": args.objective,
        "verify_command": args.verify_command,
        "status": "started",
        "base_commit": base,
        "repository_heads": repository_heads,
        "run_dir": f".ai-loop/runs/{args.phase_id}",
        "started_at": started_at,
        "evidence_collected_at": None,
        "audit_prepared_at": None,
        "decided_at": None,
    }
    atomic_text(run_dir / "base_commit.txt", base + "\n")
    atomic_json(run_dir / "repository_heads.json", repository_heads)
    atomic_text(run_dir / "status_before.txt", status_before)
    atomic_json(run_dir / "phase.json", phase)
    atomic_text(
        run_dir / "prompt.md",
        f"# Phase: {args.phase_id} — {args.title}\n\n"
        f"## Objective\n\n{args.objective}\n\n"
        "## Boundaries\n\n"
        "- Make only changes required by this phase.\n"
        "- Preserve existing user work and repository constraints.\n"
        "- Do not accept the phase without reproducible evidence and audit.\n"
        "- Do not push, deploy, or mutate external systems unless explicitly authorized.\n\n"
        f"## Verification\n\n```bash\n{args.verify_command}\n```\n",
    )
    status["current_phase"] = phase
    status["phases"].append(phase)
    atomic_json(paths["status"], status)
    append_event(paths, "phase_started", args.phase_id)
    print(f"STARTED {args.phase_id}")


def changed_files(repository_key: str, repository: Path, base: str) -> list[str]:
    tracked_arguments = ["diff", "--name-only", base]
    if repository_key == ".":
        tracked_arguments.extend(["--", *CONTROL_PATHSPECS])
    tracked = git(repository, *tracked_arguments).splitlines()
    untracked = git(repository, "ls-files", "--others", "--exclude-standard").splitlines()
    if repository_key == ".":
        untracked = [item for item in untracked if item != ".ai-loop" and not item.startswith(".ai-loop/")]
    return sorted({item for item in tracked + untracked if item})


def untracked_business_patch(project_root: Path, repository_key: str, repository: Path) -> str:
    chunks: list[str] = []
    source_prefix = "a/" if repository_key == "." else f"a/{repository_key}/"
    target_prefix = "b/" if repository_key == "." else f"b/{repository_key}/"
    for relative in git(repository, "ls-files", "--others", "--exclude-standard").splitlines():
        if repository == project_root and (
            not relative or relative == ".ai-loop" or relative.startswith(".ai-loop/")
        ):
            continue
        candidate = (repository / relative).resolve()
        try:
            candidate.relative_to(repository)
        except ValueError as exc:
            raise LoopError(f"untracked path escapes evidence repository {repository_key}: {relative}") from exc
        if not candidate.is_file():
            continue
        result = run(
            [
                "git",
                "-C",
                str(repository),
                "diff",
                "--no-index",
                "--binary",
                f"--src-prefix={source_prefix}",
                f"--dst-prefix={target_prefix}",
                "--",
                "/dev/null",
                relative,
            ],
            repository,
            120,
        )
        if result.returncode not in (0, 1):
            raise LoopError(f"cannot capture untracked evidence for {relative}")
        chunks.append(result.stdout)
    return "".join(chunks)


def tracked_patch(repository_key: str, repository: Path, base: str) -> str:
    source_prefix = "a/" if repository_key == "." else f"a/{repository_key}/"
    target_prefix = "b/" if repository_key == "." else f"b/{repository_key}/"
    arguments = [
        "diff",
        "--binary",
        f"--src-prefix={source_prefix}",
        f"--dst-prefix={target_prefix}",
        base,
    ]
    if repository_key == ".":
        arguments.extend(["--", *CONTROL_PATHSPECS])
    return git(repository, *arguments, timeout=300)


def cmd_collect(root: Path, args: argparse.Namespace) -> None:
    paths, config, status = validate_project(root)
    phase = status.get("current_phase")
    if not isinstance(phase, dict) or phase.get("phase_id") != args.phase_id:
        raise LoopError(f"phase is not current: {args.phase_id}")
    if phase.get("status") != "started":
        raise LoopError(f"phase is not collectable from state: {phase.get('status')}")
    run_dir = paths["runs"] / args.phase_id
    repositories = resolve_evidence_repositories(root, config)
    heads = phase.get("repository_heads")
    if not isinstance(heads, dict) or set(heads) != set(repositories):
        raise LoopError("evidence repository set changed during the phase")
    patches: list[str] = []
    statuses: list[str] = []
    changed: list[str] = []
    for key, repository in repositories.items():
        base = heads.get(key)
        if not isinstance(base, str) or not base:
            raise LoopError(f"missing evidence repository head: {key}")
        patches.append(tracked_patch(key, repository, base))
        patches.append(untracked_business_patch(root, key, repository))
        statuses.append(prefix_lines(key, business_status(key, repository)))
        changed.extend(
            item if key == "." else f"{key}/{item}"
            for item in changed_files(key, repository, base)
        )
    patch = "".join(patches)
    atomic_text(run_dir / "diff.patch", patch)
    atomic_text(run_dir / "status_after.txt", "".join(statuses))
    atomic_text(run_dir / "changed_files.txt", "\n".join(sorted(set(changed))) + "\n")
    command = str(phase.get("verify_command", "")).strip()
    if not command:
        raise LoopError("verification command is empty")
    verification = run(["bash", "-lc", command], root, timeout=args.timeout)
    atomic_text(
        run_dir / "verify.log",
        verification.stdout + f"\n[sci-loop] verify_exit_code={verification.returncode}\n",
    )
    collected_at = utc_now()
    status = update_phase(
        status,
        args.phase_id,
        status="evidence_collected",
        evidence_collected_at=collected_at,
        verify_exit_code=verification.returncode,
    )
    atomic_json(paths["status"], status)
    append_event(paths, "evidence_collected", args.phase_id, verify_exit_code=verification.returncode)
    print(f"COLLECTED {args.phase_id} verify_exit_code={verification.returncode}")


def cmd_audit_pack(root: Path, args: argparse.Namespace) -> None:
    paths, _config, status = validate_project(root)
    phase = status.get("current_phase")
    if not isinstance(phase, dict) or phase.get("phase_id") != args.phase_id:
        raise LoopError(f"phase is not current: {args.phase_id}")
    if phase.get("status") != "evidence_collected":
        raise LoopError(f"phase is not ready for audit: {phase.get('status')}")
    run_dir = paths["runs"] / args.phase_id
    required = ["prompt.md", "report.md", "diff.patch", "verify.log", "status_after.txt", "changed_files.txt"]
    missing = [name for name in required if not (run_dir / name).is_file()]
    if missing:
        raise LoopError("audit evidence is missing: " + ", ".join(missing))
    sections = [f"# Audit Input: {args.phase_id}\n"]
    for title, name in (
        ("Phase Prompt", "prompt.md"),
        ("Execution Report", "report.md"),
        ("Changed Files", "changed_files.txt"),
        ("Diff", "diff.patch"),
        ("Verification", "verify.log"),
        ("Status After", "status_after.txt"),
    ):
        body = (run_dir / name).read_text(encoding="utf-8")
        sections.append(f"\n## {title}\n\n{body}")
    audit_input = paths["audits"] / f"{args.phase_id}-audit-input.md"
    atomic_text(audit_input, "".join(sections))
    prepared_at = utc_now()
    status = update_phase(status, args.phase_id, status="audit_prepared", audit_prepared_at=prepared_at)
    atomic_json(paths["status"], status)
    append_event(paths, "audit_prepared", args.phase_id)
    print(f"PREPARED {audit_input.relative_to(root)}")


def cmd_decide(root: Path, args: argparse.Namespace) -> None:
    paths, _config, status = validate_project(root)
    phase = status.get("current_phase")
    if not isinstance(phase, dict) or phase.get("phase_id") != args.phase_id:
        raise LoopError(f"phase is not current: {args.phase_id}")
    if phase.get("status") != "audit_prepared":
        raise LoopError(f"phase cannot be decided from state: {phase.get('status')}")
    decision = args.decision.lower()
    if decision not in DECIDED_PHASE_STATES:
        raise LoopError("decision must be accepted, rework, or blocked")
    if decision in {"accepted", "blocked"}:
        raise LoopError(
            "accepted and blocked terminal states require the host-authorized audit_protocol.py finalize gate"
        )
    audit = paths["audits"] / f"{args.phase_id}-audit.md"
    if not audit.is_file():
        raise LoopError(f"audit decision is missing: {audit.relative_to(root)}")
    contents = audit.read_text(encoding="utf-8")
    expected = f"Decision: {decision.upper()}"
    if expected not in {line.strip() for line in contents.splitlines()}:
        raise LoopError(f"audit must contain the exact line: {expected}")
    decided_at = utc_now()
    status = update_phase(status, args.phase_id, status=decision, decided_at=decided_at)
    status["last_decision"] = decision.upper()
    atomic_json(paths["status"], status)
    append_event(paths, "phase_decided", args.phase_id, decision=decision.upper())
    print(f"DECIDED {decision.upper()} {args.phase_id}")


def cmd_validate_distribution(_root: Path | None, _args: argparse.Namespace) -> None:
    plugin_root = Path(__file__).resolve().parents[1]
    manifest = read_json(plugin_root / ".codex-plugin" / "plugin.json")
    if manifest.get("name") != "codex-sci-loop" or manifest.get("version") != VERSION:
        raise LoopError("plugin manifest identity does not match the bundled core")
    skills = plugin_root / "skills"
    required = {
        "independent-completion-auditor",
        "loop-goal-bootstrap",
        "loop-supervisor",
        "loop-auditor",
        "loop-recovery",
        "research-loop-orchestrator",
    }
    present = {path.name for path in skills.iterdir() if path.is_dir() and (path / "SKILL.md").is_file()}
    if present != required:
        raise LoopError(f"skill set mismatch: expected {sorted(required)}, got {sorted(present)}")
    print("DISTRIBUTION: OK")


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument("--version", action="version", version=VERSION)
    subparsers = result.add_subparsers(dest="command", required=True)
    distribution = subparsers.add_parser("validate-distribution")
    distribution.set_defaults(handler=cmd_validate_distribution, project_optional=True)
    for command, handler in (("init", cmd_init), ("validate", cmd_validate), ("resume", cmd_resume)):
        item = subparsers.add_parser(command)
        item.add_argument("--project-root", required=True)
        if command == "resume":
            item.add_argument("--json", action="store_true")
        item.set_defaults(handler=handler, project_optional=False)
    start = subparsers.add_parser("start")
    start.add_argument("--project-root", required=True)
    start.add_argument("--phase-id", required=True)
    start.add_argument("--title", required=True)
    start.add_argument("--objective", required=True)
    start.add_argument("--verify-command", required=True)
    start.set_defaults(handler=cmd_start, project_optional=False)
    collect = subparsers.add_parser("collect")
    collect.add_argument("--project-root", required=True)
    collect.add_argument("--phase-id", required=True)
    collect.add_argument("--timeout", type=int, default=1800)
    collect.set_defaults(handler=cmd_collect, project_optional=False)
    audit = subparsers.add_parser("audit-pack")
    audit.add_argument("--project-root", required=True)
    audit.add_argument("--phase-id", required=True)
    audit.set_defaults(handler=cmd_audit_pack, project_optional=False)
    decide = subparsers.add_parser("decide")
    decide.add_argument("--project-root", required=True)
    decide.add_argument("--phase-id", required=True)
    decide.add_argument("--decision", required=True)
    decide.set_defaults(handler=cmd_decide, project_optional=False)
    return result


def fail(message: str) -> NoReturn:
    print(f"sci-loop: ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def main() -> int:
    args = parser().parse_args()
    try:
        root = None if getattr(args, "project_optional", False) else resolve_project(args.project_root)
        args.handler(root, args)
    except LoopError as exc:
        fail(str(exc))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

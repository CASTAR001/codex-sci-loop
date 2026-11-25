#!/usr/bin/env python3
"""Project-local phase control for the portable codex-sci-loop plugin."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any, NoReturn


sys.dont_write_bytecode = True
from loop_io import (
    LoopError, OUTPUT_TAIL_BYTES, PHASE_ID_RE, atomic_json, atomic_text, canonical_hash,
    digest, git, project_lock, read_json, resolve_project, run_check, utc_now,
)

VERSION = "1.1.0"
SCHEMA_VERSION = "2.0"
DECIDED_PHASE_STATES = {"accepted", "rework", "blocked"}
CONTROL_PATHSPECS = (".", ":(exclude).ai-loop", ":(exclude).ai-loop/**")


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
    if any(p.name != ".lock" for p in paths["base"].iterdir()):
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
    phases = status["phases"]
    ids = []
    for item in phases:
        if not isinstance(item, dict) or not PHASE_ID_RE.fullmatch(str(item.get("phase_id", ""))):
            raise LoopError("invalid phase record in status")
        if item.get("status") not in DECIDED_PHASE_STATES | {"started", "collecting", "evidence_collected", "audit_prepared"}:
            raise LoopError("unknown phase state")
        ids.append(item["phase_id"])
    if len(set(ids)) != len(ids) or status.get("current_phase") != (phases[-1] if phases else None):
        raise LoopError("current phase disagrees with phase history")
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
            "acceptance_scope": "recorded historical decision only" if phase else None,
            "audit_snapshot_sha256": phase.get("audit_snapshot_sha256") if phase else None,
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
            "next": "Inspect the audit findings, revise this phase and recollect evidence.",
        }
    else:
        phase_id = str(phase.get("phase_id", ""))
        state = str(phase.get("status", "unknown"))
        next_by_state = {
            "collecting": "Verification was interrupted. Inspect possible side effects before retrying collect.",
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
    tracked_arguments = ["diff", "--no-renames", "--name-only", "-z", base]
    if repository_key == ".":
        tracked_arguments.extend(["--", *CONTROL_PATHSPECS])
    tracked = git(repository, *tracked_arguments).split("\0")
    untracked = git(repository, "ls-files", "--others", "--exclude-standard", "-z").rstrip("\0").split("\0")
    if repository_key == ".":
        untracked = [item for item in untracked if item != ".ai-loop" and not item.startswith(".ai-loop/")]
    return sorted({item for item in tracked + untracked if item})


def untracked_business_patch(project_root: Path, repository_key: str, repository: Path) -> str:
    chunks: list[str] = []
    source_prefix = "a/" if repository_key == "." else f"a/{repository_key}/"
    target_prefix = "b/" if repository_key == "." else f"b/{repository_key}/"
    for relative in git(repository, "ls-files", "--others", "--exclude-standard", "-z").rstrip("\0").split("\0"):
        if repository == project_root and (
            not relative or relative == ".ai-loop" or relative.startswith(".ai-loop/")
        ):
            continue
        if not relative:
            continue
        candidate = repository / relative
        try:
            candidate.relative_to(repository)
        except ValueError as exc:
            raise LoopError(f"untracked path escapes evidence repository {repository_key}: {relative}") from exc
        if not (candidate.is_file() or candidate.is_symlink()):
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
                os.devnull,
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
        "--no-ext-diff",
        "--no-textconv",
        "--binary",
        f"--src-prefix={source_prefix}",
        f"--dst-prefix={target_prefix}",
        base,
    ]
    if repository_key == ".":
        arguments.extend(["--", *CONTROL_PATHSPECS])
    return git(repository, *arguments, timeout=300)


def capture_workspace(root: Path, config: dict[str, Any], phase: dict[str, Any]) -> tuple[dict[str, str], list[dict[str, Any]]]:
    repositories = resolve_evidence_repositories(root, config)
    heads = phase.get("repository_heads")
    if not isinstance(heads, dict) or set(heads) != set(repositories):
        raise LoopError("evidence repository set changed during the phase")
    patches: list[str] = []
    statuses: list[str] = []
    changed: list[str] = []
    records = []
    for key, repository in repositories.items():
        base = heads.get(key)
        if not isinstance(base, str) or not base:
            raise LoopError(f"missing evidence repository head: {key}")
        patch = tracked_patch(key, repository, base) + untracked_business_patch(root, key, repository)
        repo_status = business_status(key, repository)
        files = changed_files(key, repository, base)
        patches.append(patch)
        statuses.append(prefix_lines(key, repo_status))
        changed.extend(item if key == "." else f"{key}/{item}" for item in files)
        index_args = ["ls-files", "--stage", "-z"]
        if key == ".":
            index_args.extend(["--", *CONTROL_PATHSPECS])
        records.append({
            "repository": key, "base_commit": base,
            "current_head": git(repository, "rev-parse", "HEAD").strip(),
            "status_sha256": digest(repo_status.encode()), "patch_sha256": digest(patch.encode()),
            "index_sha256": digest(git(repository, *index_args).encode()),
            "changed_files_sha256": canonical_hash(files),
        })
    return {
        "diff.patch": "".join(patches), "status_after.txt": "".join(statuses),
        "changed_files.txt": "\n".join(sorted(set(changed))) + "\n",
    }, records


def cmd_collect(root: Path, args: argparse.Namespace) -> None:
    paths, config, status = validate_project(root)
    phase = status.get("current_phase")
    if not isinstance(phase, dict) or phase.get("phase_id") != args.phase_id:
        raise LoopError(f"phase is not current: {args.phase_id}")
    if phase.get("status") not in {"started", "collecting", "evidence_collected", "audit_prepared", "rework"}:
        raise LoopError(f"phase is not collectable from state: {phase.get('status')}")
    run_dir = paths["runs"] / args.phase_id
    envelope = run_dir / "request-envelope.json"

    def request_hash():
        return digest(envelope.read_bytes()) if envelope.exists() else None

    if args.timeout <= 0:
        raise LoopError("verification timeout must be positive")
    command = str(phase.get("verify_command", "")).strip()
    if not command:
        raise LoopError("verification command is empty")
    update_phase(status, args.phase_id, status="collecting", verification_binding=None, verify_exit_code=None)
    atomic_json(paths["status"], status)
    before_request = request_hash()
    before, records = capture_workspace(root, config, phase)
    del before
    verification = run_check(root, ["bash", "-c", command], args.timeout)
    code = 124 if verification["status"] == "timeout" else verification["exit_code"]
    evidence, after_records = capture_workspace(root, config, phase)
    log = verification["tail"]
    if verification["output_bytes"] > OUTPUT_TAIL_BYTES:
        log = (f"[sci-loop] last {OUTPUT_TAIL_BYTES} of {verification['output_bytes']} bytes; "
               f"output_sha256={verification['output_sha256']}\n" + log)
    log += f"\n[sci-loop] verify_exit_code={code}\n"
    atomic_text(run_dir / "verify.log", log)
    if before_request != request_hash() or records != after_records:
        raise LoopError("verification inputs changed during collection; inspect outputs and recollect")
    for name, contents in evidence.items():
        atomic_text(run_dir / name, contents)
    binding = {
        "request_envelope_sha256": before_request, "command": command,
        "log_sha256": digest(log.encode()), "workspace_sha256": canonical_hash(records),
    }
    status = update_phase(
        status, args.phase_id, status="evidence_collected", evidence_collected_at=utc_now(),
        verify_exit_code=code, verification_binding=binding, audit_prepared_at=None,
    )
    atomic_json(paths["status"], status)
    append_event(paths, "evidence_collected", args.phase_id, verify_exit_code=code)
    print(f"COLLECTED {args.phase_id} verify_exit_code={code}")


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
    # The snapshot binds the original files. Keep this legacy Markdown entrypoint small.
    sections = [f"# Audit Input: {args.phase_id}\n\n"]
    sections.extend(f"- [{name}](../runs/{args.phase_id}/{name})\n" for name in required)
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
    required = {"task-checkpoint", "research-verification"}
    present = {path.name for path in skills.iterdir() if path.is_dir() and (path / "SKILL.md").is_file()}
    if present != required:
        raise LoopError(f"skill set mismatch: expected {sorted(required)}, got {sorted(present)}")
    if (plugin_root / "hooks" / "hooks.json").exists() or manifest.get("hooks"):
        raise LoopError("native checkpoints require no global lifecycle hooks")
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
        if root is None:
            args.handler(root, args)
        else:
            with project_lock(root, create=args.command == "init"):
                args.handler(root, args)
    except (LoopError, OSError, UnicodeError) as exc:
        fail(str(exc))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Opt-in task checkpoints for ordinary Codex sessions (Python standard library)."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import stat
import subprocess
import sys
from pathlib import Path

sys.dont_write_bytecode = True
from loop_io import (
    LoopError, PHASE_ID_RE, atomic_json, canonical_hash, project_lock, read_json,
    resolve_project, run_check, utc_now,
)

SCHEMA = "sci-loop-checkpoint-v1"
CONTEXT_LIMIT = 2048
HISTORY_EVENT_LIMIT = 8
HISTORY_FIELDS = (("notes", "notes"), ("artifacts", "artifacts"), ("pending_changes", "pending_changes"),
                  ("mode_changes", "mode_changes"), ("verification_history", "verification"),
                  ("review_history", "reviews"))
CONTROL = (".", ":(exclude).ai-loop", ":(exclude).ai-loop/**")
OPERATOR_MODES = ("active", "blocked", "paused", "cancelled")
RESULTS = ("running", "passed", "failed", "timeout", "stale", "unavailable")


def request_text(file: str) -> str:
    """Read the supplied UTF-8 contract verbatim, including its line endings."""
    limit = 128 * 1024
    if file == "-":
        raw = sys.stdin.buffer.read(limit + 1)
    else:
        path = Path(file)
        if not path.is_file():
            raise LoopError("request must be a regular UTF-8 file or '-' for stdin")
        with path.open("rb") as stream:
            raw = stream.read(limit + 1)
    if len(raw) > limit:
        raise LoopError("request exceeds 128 KiB")
    text = raw.decode("utf-8")
    if not text.strip():
        raise LoopError("request is empty")
    return text


def checkpoint_path(root: Path, task: str) -> Path:
    if not PHASE_ID_RE.fullmatch(task):
        raise LoopError("invalid task id (use lowercase letters, digits, dot, dash or underscore)")
    base = root / ".ai-loop"
    directory = base / "checkpoints"
    path = directory / (task + ".json")
    if any(part.is_symlink() for part in (base, directory, path)):
        raise LoopError("checkpoint path contains a symlink")
    if (base / "loop.config.json").exists():
        raise LoopError("this project already uses a phase protocol; use its existing resume command")
    return path


def validate_input_names(inputs: list[str]) -> None:
    for item in inputs:
        relative = Path(item)
        if relative.is_absolute() or not relative.parts or ".." in relative.parts or relative.parts[0].lower() in {".git", ".ai-loop"}:
            raise LoopError(f"input must be a project-relative data file: {item}")


def contract(args, previous=None):
    command = args.verify_command if args.verify_command is not None else (previous or {}).get("command")
    if getattr(args, "remove_verifier", False):
        command = None
    if command is not None and not command.strip():
        raise LoopError("verification command is empty")
    inputs = args.input if args.input is not None else (previous or {}).get("inputs", [])
    validate_input_names(inputs)
    review = args.require_review if args.require_review is not None else (previous or {}).get("require_review", False)
    return {"request": request_text(args.request_file), "command": command, "inputs": sorted(set(inputs)),
            "require_review": review,
            "tree_only": args.tree_only if args.tree_only is not None else (previous or {}).get("tree_only", False)}


def checked_state(path: Path, task: str) -> dict:
    state = read_json(path)
    versions = state.get("contracts")
    if (state.get("schema") != SCHEMA or state.get("task") != task or state.get("mode") not in (*OPERATOR_MODES, "finished", "closed")
            or not isinstance(versions, list) or not versions or not isinstance(state.get("notes"), list)):
        raise LoopError("unrecognized or inconsistent checkpoint")
    for item in versions:
        if (not isinstance(item, dict) or not isinstance(item.get("request"), str)
                or not item["request"].strip() or type(item.get("require_review", False)) is not bool
                or type(item.get("tree_only", False)) is not bool
                or not isinstance(item.get("inputs"), list) or "command" not in item
                or not all(isinstance(name, str) for name in item["inputs"])
                or (item.get("command") is not None and not isinstance(item["command"], str))):
            raise LoopError("invalid task contract")
        validate_input_names(item["inputs"])
    if (not isinstance(state.get("next"), str) or not all(
            isinstance(note, dict) and type(note.get("revision")) is int and isinstance(note.get("text"), str)
            for note in state["notes"])):
        raise LoopError("invalid checkpoint note or pending action")
    review = state.get("review")
    if review is not None and (not isinstance(review, dict) or not all(
            isinstance(review.get(key), str) for key in ("reviewer", "outcome", "subject", "report", "at"))):
        raise LoopError("invalid review record")
    if "verification" not in state:
        raise LoopError("missing verification field")
    result = state["verification"]
    if result is not None and (not isinstance(result, dict) or result.get("status") not in RESULTS):
        raise LoopError("unrecognized verification record")
    for key in ("pending_changes", "mode_changes", "verification_history", "review_history", "artifacts"):
        records = state.get(key, [])
        if not isinstance(records, list) or not all(
                isinstance(record, dict) and type(record.get("revision")) is int
                and 1 <= record["revision"] <= len(versions) for record in records):
            raise LoopError(f"invalid {key} in checkpoint")
    return state


def git_bytes(root: Path, *args: str) -> bytes:
    result = subprocess.run(["git", *args], cwd=root, capture_output=True, timeout=120)
    if result.returncode:
        raise LoopError(result.stderr.decode(errors="replace").strip() or "Git evidence unavailable")
    return result.stdout


def file_digest(stream) -> str:
    digest = hashlib.sha256()
    for chunk in iter(lambda: stream.read(1024 * 1024), b""):
        digest.update(chunk)
    return digest.hexdigest()


def file_id(path: Path) -> str:
    with path.open("rb") as stream:
        return file_digest(stream)


def open_artifact(root: Path, relative: Path) -> int:
    flags = os.O_RDONLY | getattr(os, "O_BINARY", 0) | getattr(os, "O_NONBLOCK", 0)
    if os.open not in os.supports_dir_fd or not hasattr(os, "O_NOFOLLOW") or not hasattr(os, "O_DIRECTORY"):
        return os.open(root / relative, flags)
    # Resolve each component from the already opened parent, refusing symlinks.
    directory_flags = flags | os.O_NOFOLLOW | os.O_DIRECTORY
    directory = os.open(root, directory_flags)
    try:
        for part in relative.parts[:-1]:
            child = os.open(part, directory_flags, dir_fd=directory)
            os.close(directory)
            directory = child
        return os.open(relative.name, flags | os.O_NOFOLLOW, dir_fd=directory)
    finally:
        os.close(directory)


def artifact_stat(path: Path):
    if path.resolve() != path:
        raise LoopError("artifact must remain inside the project and must contain no symlinks")
    info = path.lstat()
    if not stat.S_ISREG(info.st_mode):
        raise LoopError("artifact must be a regular file")
    return info


def artifact_version(info) -> tuple:
    return info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns, info.st_ctime_ns


def observe_artifacts(root: Path, names: list[str], revision: int) -> list[dict]:
    records = []
    for relative in dict.fromkeys(Path(name) for name in names):
        if (relative.anchor or not relative.parts or ".." in relative.parts
                or relative.parts[0].lower() in {".git", ".ai-loop"}):
            raise LoopError(f"artifact must be a project-relative file: {relative}")
        path = root / relative
        # Require filenames representable in the UTF-8 checkpoint format.
        relative.as_posix().encode("utf-8")
        try:
            initial = artifact_stat(path)
            with os.fdopen(open_artifact(root, relative), "rb") as stream:
                opened = os.fstat(stream.fileno())
                if not stat.S_ISREG(opened.st_mode) or artifact_version(opened) != artifact_version(initial):
                    raise LoopError("artifact changed before it could be read")
                digest = file_digest(stream)
                if (stream.tell() != opened.st_size
                        or artifact_version(os.fstat(stream.fileno())) != artifact_version(opened)
                        or artifact_version(artifact_stat(path)) != artifact_version(opened)):
                    raise LoopError("artifact changed while it was being read")
        except (LoopError, OSError, RuntimeError) as exc:
            raise LoopError(f"cannot observe artifact {relative}: {exc}") from exc
        records.append({"revision": revision, "at": utc_now(), "path": relative.as_posix(), "sha256": digest,
                        "size": opened.st_size, "source": "observed file contents"})
    return records


def task_root(raw: str) -> Path:
    root = Path(raw).expanduser().resolve()
    if not root.is_dir():
        raise LoopError(f"task folder does not exist: {root}")
    if any(os.path.lexists(parent / ".git") for parent in (root, *root.parents)):
        return resolve_project(str(root))
    return root


def workspace(root: Path, current: dict) -> dict:
    """Fingerprint the Git worktree, or only explicitly declared files in an ordinary folder."""
    inputs = current["inputs"]
    declared = {}
    for name in inputs:
        path = root / name
        if path.resolve() != path or not path.is_file() or not path.is_relative_to(root):
            raise LoopError(f"declared input must be a regular file within the project: {name}")
    if not os.path.lexists(root / ".git"):
        if not inputs:
            raise LoopError("verification or review outside Git needs explicit --input files, including the check script")
        declared = {name: file_id(root / name) for name in inputs}
        modes = {name: stat.S_IMODE((root / name).stat().st_mode) for name in inputs}
        return {"sha256": canonical_hash({"declared_files": declared, "modes": modes}),
                "git_head": None, "input_sha256": declared}

    head = subprocess.run(["git", "rev-parse", "--verify", "--quiet", "HEAD"], cwd=root,
                          capture_output=True, timeout=120)
    if head.returncode not in (0, 1):
        raise LoopError("cannot determine repository HEAD")
    index = git_bytes(root, "ls-files", "-v", "--stage", "-z", "--", *CONTROL)
    status = git_bytes(root, "status", "--porcelain=v1", "-z", "--no-renames",
                       "--untracked-files=all", "--ignore-submodules=none", "--", *CONTROL)
    paths = {os.fsdecode(entry[3:]) for entry in status.split(b"\0") if entry}
    # Git status suppresses assume-unchanged and skip-worktree entries.
    for entry in index.split(b"\0"):
        if entry and (entry[:1].islower() or entry[:1] == b"S"):
            paths.add(os.fsdecode(entry.split(b"\t", 1)[1]))
    files = []
    for name in sorted(paths.union(inputs)):
        path = root / name
        if path.parent.resolve() != path.parent:
            raise LoopError(f"cannot fingerprint a path below a symlink: {name}")
        if path.is_symlink():
            files.append((name, "link", os.readlink(path)))
        elif not path.exists():
            files.append((name, "absent"))
        elif path.is_file():
            content = file_id(path)
            files.append((name, stat.S_IMODE(path.stat().st_mode), content))
            if name in inputs:
                declared[name] = content
        else:
            raise LoopError(f"cannot fingerprint directory or special file: {name}; check it in its own Git root")
    # ASCII JSON also represents filenames containing non-UTF-8 bytes losslessly.
    files_bytes = json.dumps(files, ensure_ascii=True, separators=(",", ":")).encode()
    hashes = [hashlib.sha256(value).hexdigest() for value in (index, status, files_bytes)]
    if not current.get("tree_only", False):
        hashes.append(head.stdout.decode().strip())
    return {"sha256": canonical_hash(hashes), "git_head": head.stdout.decode().strip() or None, "input_sha256": declared}


def review_subject(state: dict, tree: dict) -> str:
    revision = len(state["contracts"])
    subject = {
        "task": state["task"], "revision": revision, "contract": state["contracts"][-1],
        "notes": [note for note in state["notes"] if note["revision"] == revision],
        "workspace": tree["sha256"], "verification": state["verification"],
    }
    artifacts = [item for item in state.get("artifacts", []) if item["revision"] == revision]
    if artifacts:
        subject["artifacts"] = artifacts
    return canonical_hash(subject)


def summary(root: Path, path: Path, state: dict, full: bool, for_review: bool) -> dict:
    current = state["contracts"][-1]
    result = dict(state["verification"] or {"status": "unverified"})
    review = state.get("review")
    tree = None
    subject = None
    if for_review or review or result["status"] in {"passed", "failed", "timeout"}:
        try:
            tree = workspace(root, current)
        except (LoopError, OSError, subprocess.TimeoutExpired) as exc:
            if for_review:
                raise
            result["reason"] = str(exc)
        if tree is not None and (for_review or review):
            subject = review_subject(state, tree)
    if result["status"] == "running":
        # show owns the process lock. The prior verifier has stopped.
        result["status"] = "interrupted"
    elif result["status"] in {"passed", "failed", "timeout"}:
        if (result.get("contract_sha256") != canonical_hash(current)
                or result.get("revision") != len(state["contracts"])
                or tree is None or tree["sha256"] != result.get("workspace_sha256")):
            result["status"] = "stale"
        elif result["status"] == "passed" and (type(result.get("exit_code")) is not int or result["exit_code"] != 0):
            raise LoopError("verification status disagrees with the recorded exit code")
    scope = current["request"]
    revision = len(state["contracts"])
    notes = [note for note in state["notes"] if note["revision"] == revision]
    artifacts = [item for item in state.get("artifacts", []) if item["revision"] == revision]
    info = {
        "task": state["task"], "mode": state["mode"], "revision": len(state["contracts"]),
        "request": scope if full else scope[:CONTEXT_LIMIT], "request_truncated": not full and len(scope) > CONTEXT_LIMIT,
        "checkpoint": str(path.relative_to(root)), "next": state["next"], "mode_reason": state.get("reason", ""),
        "notes": notes if full else notes[-3:], "note_count": len(notes),
        "artifacts": artifacts if full else artifacts[-3:], "artifact_count": len(artifacts),
        "verification": result, "command": current["command"], "inputs": current["inputs"],
        "require_review": current.get("require_review", False), "tree_only": current.get("tree_only", False),
    }
    if for_review:
        info["review_subject"] = subject
    if review:
        info["review"] = {key: review[key] for key in ("outcome", "reviewer", "at", "subject")}
        info["review"]["revision"] = review.get("revision")
        info["review"]["freshness"] = "current" if subject == review["subject"] else "stale"
        if full:
            info["review"]["report"] = review["report"]
    if state["mode"] == "closed":
        info["close_basis"] = "operator statement"
    if state["mode"] == "finished" and closeout_gaps(info):
        info["mode"] = "needs_recheck"
        info["recorded_mode"] = "finished"
    if not full:
        result.pop("tail", None)
    return info


def verification_record(result: dict) -> dict:
    record = dict(result)
    record.pop("tail", None)
    status = record.pop("status")
    record["recorded_status"] = "interrupted" if status == "running" else status
    return record


def review_record(review: dict) -> dict:
    record = dict(review)
    report = record.pop("report")
    record["report_sha256"] = hashlib.sha256(report.encode("utf-8")).hexdigest()
    return record


def bound_history_events(revision: dict, task: str) -> None:
    totals = {}
    shortened = False
    for _, field in HISTORY_FIELDS:
        events = revision[field]
        if len(events) > HISTORY_EVENT_LIMIT:
            totals[field] = len(events)
            revision[field] = events[-HISTORY_EVENT_LIMIT:]
        for index, event in enumerate(revision[field]):
            long_fields = [key for key in ("text", "previous", "next", "reason")
                           if isinstance(event.get(key), str) and len(event[key]) > CONTEXT_LIMIT]
            if long_fields:
                preview = {key: event[key][:CONTEXT_LIMIT] for key in long_fields}
                revision[field][index] = {**event, **preview, "truncated_fields": long_fields}
                shortened = True
    if totals:
        revision["event_totals"] = totals
    if totals or shortened or revision["request_truncated"]:
        revision["full_query"] = f"history --revision {revision['revision']} --full --task {task}"


def history(state: dict, args) -> dict:
    current = len(state["contracts"])
    if args.revision is not None:
        if not 1 <= args.revision <= current:
            raise LoopError("history revision is outside the recorded range")
        first = last = args.revision
    else:
        before = args.before if args.before is not None else current + 1
        if not 1 <= before <= current + 1 or not 1 <= args.limit <= 100:
            raise LoopError("history expects --before within the recorded range and --limit from 1 to 100")
        last = before - 1
        first = max(1, before - args.limit)

    revisions = {}
    for revision in range(last, first - 1, -1):
        recorded = state["contracts"][revision - 1]
        request = recorded["request"]
        revisions[revision] = {
            "revision": revision, "is_current": revision == current,
            "contract": {**recorded, "request": request if args.full else request[:CONTEXT_LIMIT]},
            "request_truncated": not args.full and len(request) > CONTEXT_LIMIT,
            "notes": [], "artifacts": [], "pending_changes": [], "mode_changes": [], "verification": [], "reviews": [],
        }
    for key, field in HISTORY_FIELDS:
        for record in state.get(key, []):
            if record["revision"] in revisions:
                revisions[record["revision"]][field].append(record)
    for key, field, compact in (("verification", "verification", verification_record),
                                ("review", "reviews", review_record)):
        record = state.get(key)
        if record and record.get("revision") in revisions:
            revisions[record["revision"]][field].append(compact(record))
    if not args.full:
        for revision in revisions.values():
            bound_history_events(revision, state["task"])
    return {
        "task": state["task"], "current_revision": current, "recorded_mode": state["mode"],
        "current_next": state["next"], "revisions": list(revisions.values()),
        "next_before": first if args.revision is None and first > 1 else None,
    }


def record_next(state: dict, next_action: str, cause: str, at: str) -> None:
    if next_action != state["next"]:
        state.setdefault("pending_changes", []).append({
            "revision": len(state["contracts"]), "at": at, "previous": state["next"],
            "next": next_action, "cause": cause, "source": "operator statement",
        })
        state["next"] = next_action


def record_snapshot(root: Path, state: dict, args, at: str) -> None:
    artifacts = observe_artifacts(root, args.artifact, len(state["contracts"]))
    if artifacts:
        state.setdefault("artifacts", []).extend(artifacts)
    if args.note:
        state["notes"].append({"revision": len(state["contracts"]), "at": at, "kind": args.kind,
                               "text": args.note, "source": "operator statement"})
    if args.next is not None:
        record_next(state, args.next, args.action, at)


def archive_evidence(state: dict, key: str, compact) -> None:
    record = state.get(key)
    if record and type(record.get("revision")) is int and 1 <= record["revision"] <= len(state["contracts"]):
        state.setdefault(f"{key}_history", []).append(compact(record))


def closeout_gaps(info: dict) -> list[str]:
    gaps = []
    review = info.get("review")
    if info["next"]:
        gaps.append("pending action remains")
    if info["command"] and info["verification"]["status"] != "passed":
        gaps.append("current verification has not passed")
    if info["require_review"] or (review and review["revision"] == info["revision"]) or not info["command"]:
        if not review or review["freshness"] != "current" or review["outcome"] != "supported":
            gaps.append("a current supporting review is required")
    return gaps


def verify_checkpoint(root: Path, path: Path, state: dict, timeout: int) -> None:
    if state["mode"] != "active":
        raise LoopError(f"task is {state['mode']}; verification requires an active task")
    current = state["contracts"][-1]
    if not current["command"] or timeout <= 0:
        raise LoopError("verification requires a declared command and positive timeout")
    evidence = {"status": "running", "revision": len(state["contracts"]),
                "contract_sha256": canonical_hash(current), "started_at": utc_now()}
    archive_evidence(state, "verification", verification_record)
    state["verification"] = evidence
    atomic_json(path, state)
    try:
        before = workspace(root, current)
        evidence.update(workspace_sha256=before["sha256"], git_head=before["git_head"],
                        input_sha256=before["input_sha256"])
        evidence.update(run_check(root, current["command"], timeout), finished_at=utc_now())
        if workspace(root, current)["sha256"] != before["sha256"]:
            evidence["status"] = "stale"
    except (LoopError, OSError, subprocess.TimeoutExpired) as exc:
        evidence.update(status="unavailable", reason=str(exc))


def print_json(value: dict) -> None:
    result = json.dumps(value, ensure_ascii=False)
    try:
        result.encode(sys.stdout.encoding or "utf-8")
    except UnicodeEncodeError:
        result = json.dumps(value, ensure_ascii=True)
    print(result)


def execute(root: Path, args) -> int:
    path = checkpoint_path(root, args.task)
    at = utc_now()
    if args.action == "start":
        if path.exists():
            raise LoopError("task already exists; use show or revise")
        state = {"schema": SCHEMA, "task": args.task, "contracts": [contract(args)], "mode": "active",
                 "notes": [], "next": "", "verification": None}
        record_snapshot(root, state, args, at)
    else:
        state = checked_state(path, args.task)
        if args.action == "show":
            print_json(summary(root, path, state, args.full, args.for_review))
            return 0
        if args.action == "history":
            print_json(history(state, args))
            return 0
        previous_mode = state["mode"]
        previous_reason = state.get("reason", "")
        if state["mode"] == "cancelled":
            raise LoopError("task was cancelled; use a new task id")
        if args.action == "close":
            current = state["contracts"][-1]
            review = state.get("review") or {}
            if state["mode"] not in {"active", "closed"} or state["next"]:
                raise LoopError("close requires an active task with no pending action")
            if (current["command"] or current["inputs"] or current.get("require_review")
                    or review.get("revision") == len(state["contracts"])):
                raise LoopError("this task has evidence requirements; use finish")
            state["mode"] = "closed"
        elif args.action == "finish":
            if state["mode"] not in {"active", "finished"}:
                raise LoopError("only an active task can finish")
            issues = closeout_gaps(summary(root, path, state, False, False))
            if issues:
                raise LoopError("cannot finish: " + ", ".join(issues))
            state["mode"] = "finished"
        elif state["mode"] in {"finished", "closed"} and args.action != "set-state":
            raise LoopError("use set-state --state active to reopen the task")
        elif args.action == "set-state":
            if not args.reason.strip():
                raise LoopError("record a reason for the state change")
            state.update(mode=args.state, reason=args.reason)
        elif args.action == "revise":
            if args.from_revision != len(state["contracts"]):
                raise LoopError("contract revision changed; read show before replacing it")
            amended = contract(args, state["contracts"][-1])
            record_next(state, "", "revise", at)
            state["contracts"].append(amended)
            record_snapshot(root, state, args, at)
        elif args.action == "note":
            if not args.note and args.next is None and not args.artifact:
                raise LoopError("provide --note, --next or --artifact")
            record_snapshot(root, state, args, at)
        elif args.action == "review":
            tree = workspace(root, state["contracts"][-1])
            if args.subject != review_subject(state, tree):
                raise LoopError("review subject changed; inspect show --for-review and review the current evidence")
            review = {"revision": len(state["contracts"]), "subject": args.subject,
                      "report": request_text(args.file), "at": at,
                      "reviewer": args.reviewer, "outcome": args.outcome}
            previous = state.get("review")
            if previous and any(previous.get(key) != review[key] for key in
                                ("revision", "subject", "report", "reviewer", "outcome")):
                archive_evidence(state, "review", review_record)
            state["review"] = review
        elif args.action == "verify":
            verify_checkpoint(root, path, state, args.timeout)
        if state["mode"] != previous_mode or state.get("reason", "") != previous_reason:
            change = {"revision": len(state["contracts"]), "at": at, "previous": previous_mode,
                      "mode": state["mode"], "cause": args.action}
            if args.action == "set-state":
                change["reason"] = args.reason
            elif args.action == "close":
                change["close_basis"] = "operator statement"
            state.setdefault("mode_changes", []).append(change)
    atomic_json(path, state)
    if args.action == "verify":
        print_json(state["verification"])
        return 0 if state["verification"]["status"] == "passed" else 1
    print(f"{args.task} {args.action} revision={len(state['contracts'])} mode={state['mode']}")
    return 0


def parser():
    result = argparse.ArgumentParser(description=__doc__)
    commands = result.add_subparsers(dest="action", required=True)
    for name in ("start", "revise", "note", "verify", "show", "history", "review", "finish", "close", "set-state"):
        cmd = commands.add_parser(name)
        cmd.add_argument("--project-root", default=".")
        cmd.add_argument("--task", default="main")
        if name in {"start", "revise"}:
            cmd.add_argument("--request-file", required=True, help="full effective user contract (UTF-8 file or '-' for stdin)")
            scope = cmd.add_mutually_exclusive_group()
            scope.add_argument("--tree-only", action="store_true", default=None,
                               help="exclude commit identity when the check depends only on source and declared inputs")
            if name == "revise":
                scope.add_argument("--bind-head", dest="tree_only", action="store_false", default=None)
            review = cmd.add_mutually_exclusive_group()
            review.add_argument("--require-review", action="store_true", default=None)
            if name == "revise":
                review.add_argument("--optional-review", dest="require_review", action="store_false", default=None)
            verifier = cmd.add_mutually_exclusive_group()
            verifier.add_argument("--verify-command", help="authorized repeatable shell command executed only by verify")
            if name == "revise":
                verifier.add_argument("--remove-verifier", action="store_true")
            inputs = cmd.add_mutually_exclusive_group()
            if name == "revise":
                inputs.add_argument("--clear-inputs", dest="input", action="store_const", const=[])
            inputs.add_argument("--input", action="append", help="also bind this regular file, including files outside the Git index")
        if name == "revise":
            cmd.add_argument("--from-revision", required=True, type=int)
        if name in {"start", "revise", "note"}:
            cmd.add_argument("--kind", default="decision", help="label for this note")
            cmd.add_argument("--note")
            cmd.add_argument("--next", help="replace the pending action")
            cmd.add_argument("--artifact", action="append", default=[], metavar="PATH",
                             help="record an observed digest of this project-relative file (repeatable)")
        if name == "review":
            cmd.add_argument("--subject", required=True, help="digest obtained before independent review")
            cmd.add_argument("--reviewer", required=True, help="declared reviewer or native thread identifier")
            cmd.add_argument("--outcome", required=True, choices=("supported", "rework", "inconclusive", "blocked"))
            cmd.add_argument("--file", required=True, help="review with evidence references, from UTF-8 file or stdin (-)")
        if name == "set-state":
            cmd.add_argument("--state", required=True, choices=OPERATOR_MODES)
            cmd.add_argument("--reason", required=True)
        if name == "verify":
            cmd.add_argument("--timeout", type=int, default=300)
        if name == "show":
            cmd.add_argument("--for-review", action="store_true", help="identify the exact evidence to review")
            cmd.add_argument("--full", action="store_true", help="include full current request and verification output tail")
        if name == "history":
            position = cmd.add_mutually_exclusive_group()
            position.add_argument("--before", type=int, help="exclude this revision and later ones")
            position.add_argument("--revision", type=int, help="read a single revision")
            cmd.add_argument("--limit", type=int, default=5, help="revisions per page, newest first (1–100)")
            cmd.add_argument("--full", action="store_true", help="include complete contract text and recorded events")
    return result


def main() -> int:
    args = parser().parse_args()
    try:
        root = task_root(args.project_root)
        with project_lock(root, create=args.action == "start"):
            return execute(root, args)
    except (LoopError, OSError, UnicodeError, subprocess.TimeoutExpired) as exc:
        print(f"sci-loop: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())

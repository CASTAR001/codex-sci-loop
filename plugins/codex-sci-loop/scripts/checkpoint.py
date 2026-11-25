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


def contract(args, previous=None):
    command = args.verify_command if args.verify_command is not None else (previous or {}).get("command")
    if getattr(args, "remove_verifier", False):
        command = None
    if command is not None and not command.strip():
        raise LoopError("verification command is empty")
    inputs = args.input if args.input is not None else (previous or {}).get("inputs", [])
    for item in inputs:
        relative = Path(item)
        if relative.is_absolute() or not relative.parts or ".." in relative.parts or relative.parts[0] in {".git", ".ai-loop"}:
            raise LoopError(f"input must be a project-relative data file: {item}")
    review = args.require_review if args.require_review is not None else (previous or {}).get("require_review", False)
    return {"request": request_text(args.request_file), "command": command, "inputs": sorted(set(inputs)),
            "require_review": review}


def checked_state(path: Path, task: str) -> dict:
    state = read_json(path)
    versions = state.get("contracts")
    if (state.get("schema") != SCHEMA or state.get("task") != task or state.get("mode") not in (*OPERATOR_MODES, "finished")
            or not isinstance(versions, list) or not versions or not isinstance(state.get("notes"), list)):
        raise LoopError("unrecognized or inconsistent checkpoint")
    for item in versions:
        if (not isinstance(item, dict) or not isinstance(item.get("request"), str)
                or not item["request"].strip() or type(item.get("require_review", False)) is not bool
                or not isinstance(item.get("inputs"), list) or "command" not in item
                or not all(isinstance(name, str) for name in item["inputs"])
                or (item.get("command") is not None and not isinstance(item["command"], str))):
            raise LoopError("invalid task contract")
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
    return state


def git_bytes(root: Path, *args: str) -> bytes:
    result = subprocess.run(["git", *args], cwd=root, capture_output=True, timeout=120)
    if result.returncode:
        raise LoopError(result.stderr.decode(errors="replace").strip() or "Git evidence unavailable")
    return result.stdout


def file_id(path: Path) -> str:
    with path.open("rb") as stream:
        h = hashlib.sha256()
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def workspace(root: Path, inputs: list[str]) -> dict:
    """Bind the index and actual dirty file bytes. Never store a second patch."""
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
    declared = {}
    for name in inputs:
        path = root / name
        if path.resolve() != path or not path.is_file() or not path.is_relative_to(root):
            raise LoopError(f"declared input must be a regular file within the project: {name}")
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
    # Record HEAD for provenance; a commit containing only the checkpoint must stay fresh.
    hashes = [hashlib.sha256(value).hexdigest() for value in (index, status, files_bytes)]
    return {"sha256": canonical_hash(hashes), "git_head": head.stdout.decode().strip() or None, "input_sha256": declared}


def review_subject(state: dict, tree: dict) -> str:
    revision = len(state["contracts"])
    return canonical_hash({
        "task": state["task"], "revision": revision, "contract": state["contracts"][-1],
        "notes": [note for note in state["notes"] if note["revision"] == revision],
        "workspace": tree["sha256"], "verification": state["verification"],
    })


def summary(root: Path, path: Path, state: dict, full: bool, for_review: bool) -> dict:
    current = state["contracts"][-1]
    result = dict(state["verification"] or {"status": "unverified"})
    review = state.get("review")
    tree = None
    subject = None
    if for_review or review or result["status"] in {"passed", "failed", "timeout"}:
        try:
            tree = workspace(root, current["inputs"])
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
    notes = [note for note in state["notes"] if note["revision"] == len(state["contracts"])]
    info = {
        "task": state["task"], "mode": state["mode"], "revision": len(state["contracts"]),
        "request": scope if full else scope[:CONTEXT_LIMIT], "request_truncated": not full and len(scope) > CONTEXT_LIMIT,
        "checkpoint": str(path.relative_to(root)), "next": state["next"], "mode_reason": state.get("reason", ""),
        "notes": notes if full else notes[-3:], "note_count": len(notes),
        "verification": result, "command": current["command"], "inputs": current["inputs"],
        "require_review": current.get("require_review", False),
    }
    if for_review:
        info["review_subject"] = subject
    if review:
        info["review"] = {key: review[key] for key in ("outcome", "reviewer", "at", "subject")}
        info["review"]["revision"] = review.get("revision")
        info["review"]["freshness"] = "current" if subject == review["subject"] else "stale"
        if full:
            info["review"]["report"] = review["report"]
    if state["mode"] == "finished" and closeout_gaps(info):
        info["mode"] = "needs_recheck"
        info["recorded_mode"] = "finished"
    if not full:
        result.pop("tail", None)
    return info


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
    state["verification"] = evidence
    atomic_json(path, state)
    try:
        before = workspace(root, current["inputs"])
        evidence.update(workspace_sha256=before["sha256"], git_head=before["git_head"],
                        input_sha256=before["input_sha256"])
        evidence.update(run_check(root, current["command"], timeout), finished_at=utc_now())
        if workspace(root, current["inputs"])["sha256"] != before["sha256"]:
            evidence["status"] = "stale"
    except (LoopError, OSError, subprocess.TimeoutExpired) as exc:
        evidence.update(status="unavailable", reason=str(exc))


def execute(root: Path, args) -> int:
    path = checkpoint_path(root, args.task)
    if args.action == "start":
        if path.exists():
            raise LoopError("task already exists; use show or revise")
        state = {"schema": SCHEMA, "task": args.task, "contracts": [contract(args)], "mode": "active",
                 "notes": [], "next": "", "verification": None}
    else:
        state = checked_state(path, args.task)
        if args.action == "show":
            print(json.dumps(summary(root, path, state, args.full, args.for_review), ensure_ascii=True))
            return 0
        if state["mode"] == "cancelled":
            raise LoopError("task was cancelled; use a new task id")
        if args.action == "finish":
            if state["mode"] not in {"active", "finished"}:
                raise LoopError("only an active task can finish")
            issues = closeout_gaps(summary(root, path, state, False, False))
            if issues:
                raise LoopError("cannot finish: " + ", ".join(issues))
            state["mode"] = "finished"
        elif state["mode"] == "finished" and args.action != "set-state":
            raise LoopError("use set-state --state active to reopen the finished task")
        elif args.action == "set-state":
            if not args.reason.strip():
                raise LoopError("record a reason for the state change")
            state.update(mode=args.state, reason=args.reason)
        elif args.action == "revise":
            if args.from_revision != len(state["contracts"]):
                raise LoopError("contract revision changed; read show before replacing it")
            state["contracts"].append(contract(args, state["contracts"][-1]))
            state["next"] = ""
        elif args.action == "note":
            if not args.note and args.next is None:
                raise LoopError("provide --note or --next")
            if args.note:
                state["notes"].append({"revision": len(state["contracts"]), "at": utc_now(), "kind": args.kind,
                                       "text": args.note, "source": "operator statement"})
            if args.next is not None:
                state["next"] = args.next
        elif args.action == "review":
            tree = workspace(root, state["contracts"][-1]["inputs"])
            if args.subject != review_subject(state, tree):
                raise LoopError("review subject changed; inspect show --for-review and review the current evidence")
            state["review"] = {"revision": len(state["contracts"]), "subject": args.subject, "report": request_text(args.file), "at": utc_now(),
                               "reviewer": args.reviewer, "outcome": args.outcome}
        elif args.action == "verify":
            verify_checkpoint(root, path, state, args.timeout)
    atomic_json(path, state)
    if args.action == "verify":
        print(json.dumps(state["verification"], ensure_ascii=True))
        return 0 if state["verification"]["status"] == "passed" else 1
    print(f"{args.task} {args.action} revision={len(state['contracts'])} mode={state['mode']}")
    return 0


def parser():
    result = argparse.ArgumentParser(description=__doc__)
    commands = result.add_subparsers(dest="action", required=True)
    for name in ("start", "revise", "note", "verify", "show", "review", "finish", "set-state"):
        cmd = commands.add_parser(name)
        cmd.add_argument("--project-root", default=".")
        cmd.add_argument("--task", default="main")
        if name in {"start", "revise"}:
            cmd.add_argument("--request-file", required=True, help="full effective user contract (UTF-8 file or '-' for stdin)")
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
            inputs.add_argument("--input", action="append", help="also bind this regular file, e.g. ignored experimental data")
        if name == "revise":
            cmd.add_argument("--from-revision", required=True, type=int)
        if name == "note":
            cmd.add_argument("--kind", choices=("decision", "hypothesis", "ruled-out"), default="decision")
            cmd.add_argument("--note")
            cmd.add_argument("--next", help="replace the pending action")
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
    return result


def main() -> int:
    args = parser().parse_args()
    try:
        root = resolve_project(args.project_root)
        with project_lock(root, create=args.action == "start"):
            return execute(root, args)
    except (LoopError, OSError, UnicodeError, subprocess.TimeoutExpired) as exc:
        print(f"sci-loop: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())

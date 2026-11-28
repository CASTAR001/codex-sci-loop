"""Shared local file, Git and verification primitives for the two state formats."""

from __future__ import annotations

import datetime as dt
import hashlib
import json
import os
import re
import signal
import subprocess
import tempfile
import threading
import time
from contextlib import contextmanager
from pathlib import Path
from typing import Any


OUTPUT_TAIL_BYTES = 8192
PHASE_ID_RE = re.compile(r"^[a-z0-9][a-z0-9._-]{0,95}$")


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


def stop_verifier(process: subprocess.Popen) -> None:
    # The shell leader can exit while children in the same group retain stdout.
    try:
        if os.name == "posix":
            os.killpg(process.pid, signal.SIGKILL)
        else:
            subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=1)
    except (OSError, subprocess.TimeoutExpired):
        pass
    if process.poll() is None:
        try:
            process.kill()
        except OSError:
            pass


def run_check(root: Path, command: str | list[str], timeout: int) -> dict:
    """Bound wall time and retained output even if a descendant keeps the pipe open."""
    h = hashlib.sha256()
    tail = bytearray()
    count = 0
    errors = []
    stopping = threading.Event()
    eof = threading.Event()
    buffer_lock = threading.Lock()
    process = subprocess.Popen(
        command, cwd=root, shell=isinstance(command, str), stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL, bufsize=0, start_new_session=os.name == "posix",
    )

    def drain():
        nonlocal count
        try:
            while not stopping.is_set():
                chunk = process.stdout.read(65536)
                if not chunk:
                    eof.set()
                    return
                with buffer_lock:
                    h.update(chunk)
                    count += len(chunk)
                    tail.extend(chunk)
                    del tail[:-OUTPUT_TAIL_BYTES]
        except (ValueError, OSError) as exc:
            if not stopping.is_set():
                errors.append(exc)

    reader = threading.Thread(target=drain, daemon=True)
    deadline = time.monotonic() + timeout
    complete = False
    timed_out = False
    try:
        reader.start()
        reader.join(timeout)
        if reader.is_alive():
            raise subprocess.TimeoutExpired(command, timeout)
        process.wait(timeout=max(0, deadline - time.monotonic()))
        if errors:
            raise LoopError(f"could not read verifier output: {errors[0]}")
        complete = True
    except subprocess.TimeoutExpired:
        timed_out = True
    finally:
        if not complete:
            stopping.set()
            stop_verifier(process)
            try:
                process.wait(timeout=0.5)
            except subprocess.TimeoutExpired:
                pass
        # Unbuffered pipe. A deliberately detached child cannot delay CLI shutdown.
        process.stdout.close()
    outcome = "timeout" if timed_out else ("passed" if process.returncode == 0 else "failed")
    with buffer_lock:
        return {"status": outcome, "exit_code": process.returncode, "output_bytes": count,
                "output_sha256": h.hexdigest(), "output_complete": eof.is_set(),
                "tail": tail.decode("utf-8", errors="replace")}


def git(root: Path, *arguments: str, timeout: int = 120) -> str:
    try:
        result = subprocess.run(["git", "-C", str(root), *arguments], cwd=root,
                                text=True, encoding="utf-8" if os.name == "nt" else None,
                                capture_output=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise LoopError(f"cannot run git {arguments[0]}: {exc}") from exc
    if result.returncode != 0:
        detail = result.stderr.strip().splitlines()
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


@contextmanager
def project_lock(root: Path, *, create: bool = False):
    """Serialize cooperating processes per Git worktree; the OS unlocks on exit."""
    directory = root / ".ai-loop"
    lock = directory / ".lock"
    if directory.is_symlink() or lock.is_symlink():
        raise LoopError("unsafe control or lock path")
    if create:
        # Python 3.13+ maps 0700 to a private Windows ACL owned by the creating
        # account. Inherit the project ACL so both Codex clients can reopen it.
        directory.mkdir(mode=0o777 if os.name == "nt" else 0o700, exist_ok=True)
    with lock.open("a+b") as handle:
        try:
            if os.name == "nt":
                import msvcrt
                handle.seek(0)
                msvcrt.locking(handle.fileno(), msvcrt.LK_NBLCK, 1)
            else:
                import fcntl
                fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError as exc:
            raise LoopError("another sci-loop operation is in progress or the lock is unavailable") from exc
        yield


def digest(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def canonical_hash(value: Any) -> str:
    return digest(json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode())

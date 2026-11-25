#!/usr/bin/env python3
"""Codex 0.147 lifecycle adapter for the runtime-neutral sci-loop core."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import stat
import sys
import tempfile
from contextlib import nullcontext
from pathlib import Path
from typing import Any, NoReturn


SCRIPT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPT_ROOT / "scripts"))

import audit_protocol as audit  # noqa: E402
import capability_gate as capability  # noqa: E402
import sci_loop as loop  # noqa: E402


MAX_EVENT_BYTES = 2 * 1024 * 1024
MAX_PROMPT_BYTES = 1024 * 1024
REVIEWER_TYPE = "independent_completion_auditor"
PAUSE_PROMPT = "sci-loop pause"
RESUME_PROMPT = "sci-loop resume"
COMMON = {"session_id", "transcript_path", "cwd", "hook_event_name", "model", "permission_mode"}
EVENT_FIELDS = {
    "SessionStart": COMMON | {"source"},
    "UserPromptSubmit": COMMON | {"turn_id", "prompt"},
    "PreToolUse": COMMON | {"turn_id", "tool_name", "tool_use_id", "tool_input"},
    "SubagentStart": COMMON | {"turn_id", "agent_id", "agent_type"},
    "SubagentStop": COMMON
    | {"turn_id", "agent_id", "agent_type", "agent_transcript_path", "stop_hook_active", "last_assistant_message"},
    "Stop": COMMON | {"turn_id", "stop_hook_active", "last_assistant_message"},
}
COMMAND_EVENTS = {
    "session-start": "SessionStart",
    "user-prompt-submit": "UserPromptSubmit",
    "reviewer-pre-tool": "PreToolUse",
    "reviewer-start": "SubagentStart",
    "reviewer-stop": "SubagentStop",
    "stop": "Stop",
}


class AdapterError(RuntimeError):
    pass


def digest_text(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def read_event(expected: str) -> dict[str, Any]:
    payload = sys.stdin.buffer.read(MAX_EVENT_BYTES + 1)
    if len(payload) > MAX_EVENT_BYTES:
        raise AdapterError("hook event exceeds the size limit")
    try:
        event = json.loads(payload.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise AdapterError("hook event is not valid JSON") from exc
    if not isinstance(event, dict) or set(event) != EVENT_FIELDS[expected]:
        raise AdapterError("hook event fields do not match the certified Codex 0.147 schema")
    if event.get("hook_event_name") != expected:
        raise AdapterError("hook event identity does not match the adapter command")
    for name in ("session_id", "cwd", "model", "permission_mode"):
        if not isinstance(event.get(name), str) or not event[name]:
            raise AdapterError(f"hook event {name} is invalid")
    if event["permission_mode"] not in {"default", "acceptEdits", "plan", "dontAsk", "bypassPermissions"}:
        raise AdapterError("hook event permission mode is unknown")
    if expected != "SessionStart" and (not isinstance(event.get("turn_id"), str) or not event["turn_id"]):
        raise AdapterError("hook event turn_id is invalid")
    transcript = event.get("transcript_path")
    if transcript is not None and not isinstance(transcript, str):
        raise AdapterError("hook transcript path is invalid")
    if expected == "SessionStart" and event.get("source") not in {"startup", "resume", "clear", "compact"}:
        raise AdapterError("session start source is unknown")
    if expected == "PreToolUse":
        if not all(isinstance(event.get(name), str) and event[name] for name in ("tool_name", "tool_use_id")):
            raise AdapterError("pre-tool identity is invalid")
    if expected in {"SubagentStart", "SubagentStop"}:
        if not all(isinstance(event.get(name), str) and event[name] for name in ("agent_id", "agent_type")):
            raise AdapterError("subagent identity is invalid")
    if expected == "SubagentStop":
        agent_transcript = event.get("agent_transcript_path")
        if agent_transcript is not None and not isinstance(agent_transcript, str):
            raise AdapterError("subagent transcript path is invalid")
    if expected in {"SubagentStop", "Stop"}:
        if not isinstance(event.get("stop_hook_active"), bool):
            raise AdapterError("stop_hook_active must be boolean")
        message = event.get("last_assistant_message")
        if message is not None and not isinstance(message, str):
            raise AdapterError("last assistant message is invalid")
    return event


def git_project(cwd: str) -> Path | None:
    candidate = Path(cwd).expanduser().resolve()
    if not candidate.is_dir():
        raise AdapterError("hook cwd is not a directory")
    result = loop.run(["git", "-C", str(candidate), "rev-parse", "--show-toplevel"], candidate, 15)
    if result.returncode != 0:
        return None
    root = Path(result.stdout.strip()).resolve()
    if not root.is_dir():
        raise AdapterError("Git project root is invalid")
    return root


def plugin_data() -> Path:
    raw_root = os.environ.get("PLUGIN_ROOT", "")
    if not raw_root or Path(raw_root).expanduser().resolve() != SCRIPT_ROOT:
        raise AdapterError("PLUGIN_ROOT does not identify this immutable plugin")
    raw_data = os.environ.get("PLUGIN_DATA", "")
    if not raw_data:
        raise AdapterError("PLUGIN_DATA is not configured")
    candidate_raw = Path(raw_data).expanduser()
    if candidate_raw.is_symlink():
        raise AdapterError("PLUGIN_DATA must not be a symlink")
    candidate = candidate_raw.resolve()
    if not candidate.is_dir():
        raise AdapterError("PLUGIN_DATA is not a directory")
    metadata = candidate.stat()
    if metadata.st_uid != os.geteuid() or stat.S_IMODE(metadata.st_mode) != 0o700:
        raise AdapterError("PLUGIN_DATA must be owned by the hook user with mode 0700")
    return candidate


def private_directory(path: Path, root: Path) -> Path:
    try:
        path.resolve().relative_to(root.resolve())
    except ValueError as exc:
        raise AdapterError("adapter state escapes PLUGIN_DATA") from exc
    if path.exists() and (path.is_symlink() or not path.is_dir()):
        raise AdapterError("adapter state directory is unsafe")
    relative = path.relative_to(root)
    current = root
    for part in relative.parts:
        current = current / part
        if current.is_symlink():
            raise AdapterError("adapter state path contains a symlink")
    path.mkdir(parents=True, exist_ok=True, mode=0o700)
    path.chmod(0o700)
    return path


def session_state(root: Path, event: dict[str, Any]) -> Path:
    session_key = hashlib.sha256(event["session_id"].encode("utf-8")).hexdigest()
    return private_directory(root / "sessions" / session_key, root)


def read_state(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise AdapterError(f"{label} is missing or invalid") from exc
    if not isinstance(value, dict):
        raise AdapterError(f"{label} must be an object")
    return value


def current_phase(project: Path) -> tuple[dict[str, Path], dict[str, Any]] | None:
    if not (project / ".ai-loop" / "loop.config.json").is_file():
        return None
    try:
        paths, _config, status = loop.validate_project(project)
    except loop.LoopError as exc:
        raise AdapterError(str(exc)) from exc
    phase = status.get("current_phase")
    if not isinstance(phase, dict):
        return None
    return paths, phase


def runtime_bootstrap(project: Path, event: dict[str, Any], state_root: Path) -> None:
    probe_raw = os.environ.get("LUMIFORGE_SCI_LOOP_PROBE", "")
    certificates_raw = os.environ.get("LUMIFORGE_SCI_LOOP_CERTIFICATE_ROOT", "")
    trusted_raw = os.environ.get("LUMIFORGE_SCI_LOOP_TRUSTED_ROOT", "")
    if not probe_raw or not certificates_raw or not trusted_raw:
        raise AdapterError("LumiForge runtime certification paths are incomplete")
    probe = Path(probe_raw).expanduser().resolve()
    certificates = Path(certificates_raw).expanduser().resolve()
    try:
        decision, exit_code = capability.decide(SCRIPT_ROOT, probe, certificates)
        probe_document = capability.read_object(probe)
        plugin_tree_sha256 = capability.sha256_plugin_tree(SCRIPT_ROOT)
    except capability.GateError as exc:
        raise AdapterError(f"runtime capability input is invalid: {exc}") from exc
    if exit_code != 0 or decision.get("state") != "CERTIFIED":
        raise AdapterError("LumiForge runtime is not certified for sci-loop")
    certificate_path = (certificates / f"codex-{decision['runtime_version']}.json").resolve()
    try:
        certificate_path.relative_to(certificates.resolve())
    except ValueError as exc:
        raise AdapterError("runtime behavior certificate escapes its root") from exc
    if not certificate_path.is_file():
        raise AdapterError("runtime behavior certificate is missing")
    try:
        protected = audit.trusted_root(trusted_raw, project)
        certification_path = audit.protected_file(protected, "runtime-certification.json")
        identity = audit.read_object(certification_path, "runtime certification")
        audit.validate_certification(identity, audit.receipt_public_key())
    except audit.AuditProtocolError as exc:
        raise AdapterError(f"runtime certification identity is invalid: {exc}") from exc
    expected_identity = {
        "runtime": decision["runtime"],
        "runtime_version": decision["runtime_version"],
        "plugin_version": decision["plugin_version"],
        "adapter_id": decision["adapter_id"],
        "certificate_sha256": audit.file_hash(certificate_path),
        "probe_sha256": audit.file_hash(probe),
        "runtime_artifact_sha256": probe_document.get("runtime_artifact_sha256"),
        "plugin_tree_sha256": plugin_tree_sha256,
    }
    if any(identity.get(field) != value for field, value in expected_identity.items()):
        raise AdapterError("runtime certification identity does not match the certified capability inputs")
    loop.atomic_json(
        session_state(state_root, event) / "bootstrap.json",
        {
            "schema": "sci-loop-codex-bootstrap-v1",
            "session_id_sha256": digest_text(event["session_id"]),
            "runtime": decision["runtime"],
            "runtime_version": decision["runtime_version"],
            "plugin_version": decision["plugin_version"],
            "adapter_id": decision["adapter_id"],
            "certification_identity_sha256": audit.file_hash(certification_path),
        },
    )


def phase_control_path(state: Path, project: Path, phase_id: str) -> Path:
    phase_key = digest_text(f"{project}\0{phase_id}")
    return state / f"phase-control-{phase_key}.json"


def read_phase_control(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {"state": "ready"}
    value = read_state(path, "phase control")
    if value.get("state") not in {"ready", "paused", "continuation-used"}:
        raise AdapterError("managed phase control state is invalid")
    return value


def capture_request(project: Path, event: dict[str, Any], state_root: Path) -> dict[str, Any]:
    prompt = event.get("prompt")
    if not isinstance(prompt, str) or not prompt.strip() or len(prompt.encode("utf-8")) > MAX_PROMPT_BYTES:
        raise AdapterError("user prompt is empty or exceeds the capture limit")
    state = session_state(state_root, event)
    phase_context = current_phase(project)
    active = phase_context is not None and phase_context[1]["status"] not in {"accepted", "rework", "blocked"}
    control_command = prompt.strip()
    event_hash = digest_text(f"{event['session_id']}\0{event['turn_id']}\0{prompt}")
    if not active and control_command in {PAUSE_PROMPT, RESUME_PROMPT}:
        return {"decision": "block", "reason": "No active sci-loop phase in this project."}
    if active:
        paths, phase = phase_context
        control = phase_control_path(state, project, phase["phase_id"])
        control_state = read_phase_control(control)
        if control_command == PAUSE_PROMPT:
            loop.atomic_json(control, {"state": "paused", "command_event_sha256": event_hash})
            return {"decision": "block", "reason": f"sci-loop paused. Send `{RESUME_PROMPT}` to resume."}
        if control_command == RESUME_PROMPT:
            if control_state.get("command_event_sha256") != event_hash:
                loop.atomic_json(control, {"state": "ready", "command_event_sha256": event_hash})
            return {"systemMessage": "sci-loop resumed. Completion still requires a fresh signed receipt."}
        if control_state["state"] == "paused":
            return {"decision": "block", "reason": f"sci-loop is paused. Send `{RESUME_PROMPT}` first."}
    captured = private_directory(state / "captured-prompts", state_root) / f"{event_hash}.json"
    if captured.is_file():
        return {}
    # Codex 0.147 injects Stop continuation messages into its running turn.
    # UserPromptSubmit receives actual user prompts, even when the text matches one.
    if not active:
        pending = private_directory(state_root / "pending-requests", state_root)
        loop.atomic_json(
            pending / f"{event_hash}.json",
            {
                "schema": "sci-loop-pending-request-v1",
                "envelope": {
                    "schema": "sci-loop-request-envelope-v1",
                    "request_id": f"request-{event_hash[:16]}",
                    "original_request": prompt,
                    "revisions": [],
                },
                "project_root_sha256": digest_text(str(project)),
                "session_id_sha256": digest_text(event["session_id"]),
                "turn_id_sha256": digest_text(event["turn_id"]),
            },
        )
        loop.atomic_json(captured, {"schema": "sci-loop-captured-prompt-v1", "internal_continuation": False})
        return {}
    run_dir = paths["runs"] / str(phase["phase_id"])
    request_path = run_dir / "request-envelope.json"
    if not request_path.is_file():
        envelope = {
            "schema": "sci-loop-request-envelope-v1",
            "request_id": f"request-{event_hash[:16]}",
            "original_request": prompt,
            "revisions": [],
        }
    else:
        envelope = read_state(request_path, "request envelope")
        audit.validate_request(envelope)
        if envelope["request_id"] == f"request-{event_hash[:16]}" and envelope["original_request"] == prompt:
            loop.atomic_json(captured, {"schema": "sci-loop-captured-prompt-v1", "internal_continuation": False})
            return {}
        revision_id = f"revision-{event_hash[:16]}"
        existing = {item.get("revision_id"): item.get("text") for item in envelope["revisions"]}
        if revision_id in existing:
            if existing[revision_id] != prompt:
                raise AdapterError("captured request revision identity collided")
            return {}
        envelope["revisions"].append({"revision_id": revision_id, "text": prompt})
    loop.atomic_json(request_path, envelope)
    review_request_path(state).unlink(missing_ok=True)
    loop.atomic_json(captured, {"schema": "sci-loop-captured-prompt-v1", "internal_continuation": False})
    return {}


def review_request_path(state: Path) -> Path:
    return state / "review-request.json"


def delegation_message(phase_id: str, snapshot_hash: str) -> str:
    return (
        f"Audit sci-loop phase {phase_id} from .ai-loop/runs/{phase_id}/audit-snapshot.json "
        f"with snapshot SHA-256 {snapshot_hash}. Use only the snapshot and its evidence manifest, "
        "make no changes, and return only JSON matching sci-loop-independent-audit-outcome-v1."
    )


def prepare_review_request(
    project: Path,
    event: dict[str, Any],
    state_root: Path,
    protected_root: Path,
    paths: dict[str, Path],
    phase: dict[str, Any],
) -> dict[str, Any] | None:
    phase_id = str(phase["phase_id"])
    snapshot_path = paths["runs"] / phase_id / "audit-snapshot.json"
    if not snapshot_path.is_file():
        return None
    snapshot = audit.read_object(snapshot_path, "audit snapshot")
    certification_path = audit.protected_file(protected_root, "runtime-certification.json")
    current_snapshot = audit.build_snapshot(project, phase_id, certification_path)
    if audit.canonical_bytes(snapshot) != audit.canonical_bytes(current_snapshot):
        return None
    snapshot_hash = audit.canonical_hash(snapshot)
    state = session_state(state_root, event)
    path = review_request_path(state)
    attested = False
    if path.is_file():
        previous = read_state(path, "review request")
        if previous.get("phase_id") == phase_id and previous.get("snapshot_sha256") == snapshot_hash:
            attested = previous.get("host_isolation_attested") is True
    request = {
        "schema": "sci-loop-review-request-v1",
        "phase_id": phase_id,
        "snapshot_sha256": snapshot_hash,
        "reviewer_type": REVIEWER_TYPE,
        "delegation_message": delegation_message(phase_id, snapshot_hash),
        "host_isolation_attested": attested,
    }
    loop.atomic_json(path, request)
    return request


def validate_review_request(value: dict[str, Any]) -> None:
    expected = {
        "schema",
        "phase_id",
        "snapshot_sha256",
        "reviewer_type",
        "delegation_message",
        "host_isolation_attested",
    }
    if set(value) != expected or value.get("schema") != "sci-loop-review-request-v1":
        raise AdapterError("review request schema is invalid")
    if value.get("reviewer_type") != REVIEWER_TYPE or not isinstance(value.get("delegation_message"), str):
        raise AdapterError("review request identity is invalid")
    if not isinstance(value.get("phase_id"), str) or not loop.PHASE_ID_RE.fullmatch(value["phase_id"]):
        raise AdapterError("review request phase id is invalid")
    audit.sha256(value.get("snapshot_sha256"), "review request snapshot")
    if value["delegation_message"] != delegation_message(value["phase_id"], value["snapshot_sha256"]):
        raise AdapterError("review request delegation changed")
    if not isinstance(value.get("host_isolation_attested"), bool):
        raise AdapterError("review request isolation attestation is invalid")


def pre_tool(event: dict[str, Any], state_root: Path) -> dict[str, Any]:
    if event.get("tool_name") != "Agent":
        raise AdapterError("reviewer pre-tool handler received a non-Agent tool")
    state = session_state(state_root, event)
    request_path = review_request_path(state)
    if not request_path.is_file():
        return {}
    request = read_state(request_path, "review request")
    validate_review_request(request)
    if request["host_isolation_attested"] is not True:
        return deny_tool("LumiForge has not attested the clean-room reviewer boundary.")
    tool_input = event.get("tool_input")
    if not isinstance(tool_input, dict):
        return deny_tool("Independent reviewer input is not an object.")
    allowed_shapes = [
        {"agent_type", "message", "fork_turns"},
        {"task_name", "message", "fork_turns"},
        {"agent_type", "task_name", "message", "fork_turns"},
    ]
    if set(tool_input) not in allowed_shapes:
        return deny_tool("Independent reviewer input differs from the certified spawn contract.")
    if tool_input.get("message") != request["delegation_message"] or tool_input.get("fork_turns") != "none":
        return deny_tool("Independent reviewer must receive the exact clean-room delegation with no parent turns.")
    if "agent_type" in tool_input and tool_input["agent_type"] != REVIEWER_TYPE:
        return deny_tool("Independent reviewer type is invalid.")
    if "task_name" in tool_input and tool_input["task_name"] != REVIEWER_TYPE:
        return deny_tool("Independent reviewer task identity is invalid.")
    loop.atomic_json(
        state / "review-spawn.json",
        {
            "schema": "sci-loop-review-spawn-v1",
            "tool_use_id": event["tool_use_id"],
            "snapshot_sha256": request["snapshot_sha256"],
            "reviewer_type": REVIEWER_TYPE,
            "fork_turns": "none",
        },
    )
    return {}


def deny_tool(reason: str) -> dict[str, Any]:
    return {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }


def reviewer_start(event: dict[str, Any], state_root: Path) -> dict[str, Any]:
    state = session_state(state_root, event)
    request_path = review_request_path(state)
    if not request_path.is_file():
        return {}
    request = read_state(request_path, "review request")
    validate_review_request(request)
    spawn_path = state / "review-spawn.json"
    spawn = read_state(spawn_path, "review spawn") if spawn_path.is_file() else None
    valid_spawn = (
        isinstance(spawn, dict)
        and isinstance(spawn.get("tool_use_id"), str)
        and bool(spawn["tool_use_id"])
        and spawn == {
            "schema": "sci-loop-review-spawn-v1",
            "tool_use_id": spawn["tool_use_id"],
            "snapshot_sha256": request["snapshot_sha256"],
            "reviewer_type": REVIEWER_TYPE,
            "fork_turns": "none",
        }
    )
    if (
        request["host_isolation_attested"] is not True
        or not valid_spawn
        or event.get("agent_type") != REVIEWER_TYPE
    ):
        loop.atomic_json(
            state / "invalid-reviewer-start.json",
            {
                "schema": "sci-loop-invalid-reviewer-start-v1",
                "agent_id_sha256": digest_text(str(event.get("agent_id", ""))),
                "agent_type": str(event.get("agent_type", "")),
                "snapshot_sha256": request["snapshot_sha256"],
            },
        )
        return {"systemMessage": "Independent audit isolation could not be verified; completion will remain blocked."}
    if not isinstance(event.get("agent_id"), str) or not event["agent_id"]:
        raise AdapterError("reviewer agent id is invalid")
    spawn_path.unlink()
    loop.atomic_json(
        state / "reviewer-start.json",
        {
            "schema": "sci-loop-reviewer-start-v1",
            "agent_id": event["agent_id"],
            "agent_type": event["agent_type"],
            "snapshot_sha256": request["snapshot_sha256"],
            "parent_history_shared": False,
            "host_isolation_attested": True,
        },
    )
    return {
        "hookSpecificOutput": {
            "hookEventName": "SubagentStart",
            "additionalContext": (
                "Act only as the independent completion auditor. Read the canonical snapshot named in the "
                "delegation, make no changes, and return only the required JSON object."
            ),
        }
    }


def atomic_copy(source: Path, target: Path, limit: int) -> None:
    if source.is_symlink():
        raise AdapterError("reviewer transcript is missing or unsafe")
    source = source.resolve()
    if not source.is_file() or not 1 <= source.stat().st_size <= limit:
        raise AdapterError("reviewer transcript is missing or unsafe")
    target.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    descriptor, raw_temporary = tempfile.mkstemp(prefix=f".{target.name}.", dir=target.parent)
    temporary = Path(raw_temporary)
    try:
        with source.open("rb") as input_handle, os.fdopen(descriptor, "wb") as output_handle:
            copied = 0
            while chunk := input_handle.read(min(1024 * 1024, limit + 1 - copied)):
                copied += len(chunk)
                if copied > limit:
                    raise AdapterError("reviewer transcript exceeds the size limit")
                output_handle.write(chunk)
            if not copied:
                raise AdapterError("reviewer transcript is empty")
            output_handle.flush()
            os.fsync(output_handle.fileno())
        temporary.chmod(0o600)
        os.replace(temporary, target)
    finally:
        temporary.unlink(missing_ok=True)


def reviewer_stop(project: Path, event: dict[str, Any], state_root: Path) -> dict[str, Any]:
    state = session_state(state_root, event)
    request_path = review_request_path(state)
    start_path = state / "reviewer-start.json"
    if not request_path.is_file():
        return {}
    request = read_state(request_path, "review request")
    validate_review_request(request)
    if event.get("agent_type") != REVIEWER_TYPE:
        return {}
    if not start_path.is_file():
        return invalid_reviewer_output(event, "Independent reviewer start was not observed.")
    start = read_state(start_path, "reviewer start")
    expected_start = {
        "schema": "sci-loop-reviewer-start-v1",
        "agent_id": event.get("agent_id"),
        "agent_type": REVIEWER_TYPE,
        "snapshot_sha256": request["snapshot_sha256"],
        "parent_history_shared": False,
        "host_isolation_attested": True,
    }
    if start != expected_start or event.get("agent_type") != REVIEWER_TYPE:
        return invalid_reviewer_output(event, "Independent reviewer identity changed before completion.")
    message = event.get("last_assistant_message")
    if not isinstance(message, str) or len(message.encode("utf-8")) > audit.MAX_JSON_BYTES:
        return invalid_reviewer_output(event, "Independent reviewer did not return a bounded JSON result.")
    try:
        outcome = json.loads(message)
        if not isinstance(outcome, dict):
            raise ValueError("root is not an object")
        snapshot_path = project / ".ai-loop" / "runs" / request["phase_id"] / "audit-snapshot.json"
        snapshot = audit.read_object(snapshot_path, "audit snapshot")
        if audit.canonical_hash(snapshot) != request["snapshot_sha256"]:
            raise ValueError("the independent review snapshot changed")
        _, request_hash = audit.read_object_with_hash(snapshot_path.with_name("request-envelope.json"), "request envelope")
        if request_hash != snapshot.get("source_hashes", {}).get("request_envelope_sha256"):
            raise ValueError("the user request changed during independent review")
        audit.validate_outcome(snapshot, outcome)
        if outcome.get("reviewer_thread_id") != event["agent_id"]:
            raise ValueError("reviewer result thread identity does not match the observed subagent")
    except (ValueError, json.JSONDecodeError, audit.AuditProtocolError) as exc:
        return invalid_reviewer_output(event, f"Independent reviewer result is invalid: {exc}")
    transcript_raw = event.get("agent_transcript_path")
    if not isinstance(transcript_raw, str) or not transcript_raw:
        return invalid_reviewer_output(event, "Independent reviewer transcript is unavailable.")
    candidate = private_directory(state / "review-candidate", state_root)
    transcript_path = Path(transcript_raw).expanduser()
    atomic_copy(transcript_path, candidate / "reviewer-transcript.log", audit.MAX_REVIEWER_TRANSCRIPT_BYTES)
    loop.atomic_json(candidate / "audit-outcome.json", outcome)
    loop.atomic_json(
        candidate / "reviewer-observation.json",
        {
            "schema": "sci-loop-reviewer-observation-v1",
            "reviewer_thread_id": event["agent_id"],
            "reviewer_type": REVIEWER_TYPE,
            "snapshot_sha256": request["snapshot_sha256"],
            "isolation": "clean-room-read-only",
            "parent_history_shared": False,
            "started": True,
            "stopped": True,
        },
    )
    loop.atomic_json(
        candidate / "candidate.json",
        {
            "schema": "sci-loop-review-candidate-v1",
            "phase_id": request["phase_id"],
            "snapshot_sha256": request["snapshot_sha256"],
            "outcome_sha256": audit.canonical_hash(outcome),
            "host_signature_pending": True,
        },
    )
    return {"continue": True}


def invalid_reviewer_output(event: dict[str, Any], reason: str) -> dict[str, Any]:
    if event.get("stop_hook_active") is True:
        return {"continue": False, "stopReason": reason, "systemMessage": "Independent audit output was rejected."}
    return {"decision": "block", "reason": reason}


def stop_reason(phase: dict[str, Any], request: dict[str, Any] | None) -> str:
    if phase.get("status") in {"started", "collecting"}:
        return "Finish the scoped sci-loop work and collect deterministic evidence."
    if phase.get("status") == "evidence_collected":
        return "Prepare the canonical sci-loop audit package and snapshot."
    if request is None:
        return (
            "Continue the sci-loop closeout. If the request, workspace, or verification changed, run collect "
            "and audit-pack again. Create the current canonical audit snapshot before requesting review."
        )
    return (
        "Continue the sci-loop closeout. After LumiForge attests the read-only boundary, spawn exactly "
        "independent_completion_auditor with fork_turns=none and the following exact message, then wait for "
        "the signed host receipt: "
        + json.dumps(request["delegation_message"], ensure_ascii=False)
    )


def stop_denied(reason: str) -> dict[str, Any]:
    return {"continue": False, "stopReason": reason, "systemMessage": reason}


def stop_hook(project: Path, event: dict[str, Any], state_root: Path) -> dict[str, Any]:
    phase_context = current_phase(project)
    if phase_context is None:
        return stop_denied("Managed sci-loop has no phase with a signed completion decision.")
    paths, phase = phase_context
    phase_id = phase["phase_id"]
    control = phase_control_path(session_state(state_root, event), project, phase_id)
    control_state = read_phase_control(control)
    if control_state["state"] == "paused":
        return stop_denied(f"sci-loop paused. Send `{RESUME_PROMPT}` to resume.")
    if phase["status"] in {"blocked", "rework"}:
        return stop_denied(f"sci-loop phase {phase_id} is {phase['status']} and requires follow-up.")
    trusted_raw = os.environ.get("LUMIFORGE_SCI_LOOP_TRUSTED_ROOT", "")
    if not trusted_raw:
        return stop_denied("Managed sci-loop requires a protected receipt root.")
    protected = audit.trusted_root(trusted_raw, project)
    if phase["status"] in {"audit_prepared", "accepted"}:
        try:
            payload, _exit_code = audit.gate(project, phase_id, protected)
            if payload["state"] == "ALLOW_COMPLETE":
                audit.apply_terminal_decision(project, phase_id, payload)
                return {"continue": True}
            if payload["state"] == "BLOCK_REQUIRES_USER":
                audit.apply_terminal_decision(project, phase_id, payload)
                return stop_denied("Independent audit requires user input before sci-loop can complete.")
        except (audit.AuditProtocolError, loop.LoopError):
            pass
    if phase["status"] == "accepted":
        return stop_denied("The historical sci-loop acceptance could not be revalidated against current evidence.")
    if event["stop_hook_active"] or control_state["state"] == "continuation-used":
        return stop_denied(f"Completion remains denied. Send `{RESUME_PROMPT}` to authorize another continuation.")
    request = None
    try:
        if phase["status"] == "audit_prepared":
            request = prepare_review_request(project, event, state_root, protected, paths, phase)
    except (audit.AuditProtocolError, loop.LoopError):
        pass
    loop.atomic_json(control, {**control_state, "state": "continuation-used"})
    return {"decision": "block", "reason": stop_reason(phase, request)}


def session_start(project: Path, event: dict[str, Any], state_root: Path) -> dict[str, Any]:
    runtime_bootstrap(project, event, state_root)
    return {"continue": True}


def error_output(command: str, error: Exception, event: dict[str, Any] | None) -> dict[str, Any]:
    _ = error
    message = "sci-loop adapter failed closed; inspect the private LumiForge runtime audit state."
    if command == "reviewer-pre-tool":
        return deny_tool(message)
    if command == "user-prompt-submit":
        return {"decision": "block", "reason": message}
    if command == "reviewer-start":
        return {"systemMessage": message}
    if command == "stop":
        return stop_denied(message)
    if command == "reviewer-stop":
        if event and event.get("stop_hook_active") is not True:
            return {"decision": "block", "reason": message}
        return {"continue": False, "stopReason": message, "systemMessage": "sci-loop failed closed."}
    return {"continue": False, "stopReason": message, "systemMessage": "sci-loop runtime certification failed."}


def emit(value: dict[str, Any]) -> None:
    print(json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")))


def managed_hook_mode() -> bool:
    """Return true only for a LumiForge-managed Goal runtime.

    The plugin is also useful as a portable collection of skills and commands.
    Installing it into a normal Codex home must therefore not make its strict,
    version-certified lifecycle adapter global.  Check the host-owned activation
    marker before parsing a hook payload so an unrelated Codex schema update
    cannot fail-close an ordinary session.
    """

    return os.environ.get("LUMIFORGE_SCI_LOOP_MODE") == "goal"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=sorted(COMMAND_EVENTS))
    args = parser.parse_args()
    if not managed_hook_mode():
        emit({})
        return 0
    event: dict[str, Any] | None = None
    try:
        event = read_event(COMMAND_EVENTS[args.command])
        project = git_project(event["cwd"])
        if project is None:
            raise AdapterError("managed sci-loop requires a Git project")
        state_root = plugin_data()
        if args.command == "session-start":
            output = session_start(project, event, state_root)
        else:
            if args.command == "user-prompt-submit":
                runtime_bootstrap(project, event, state_root)
            lock = loop.project_lock(project) if loop.control_paths(project)["config"].is_file() else nullcontext()
            with lock:
                if args.command == "user-prompt-submit":
                    output = capture_request(project, event, state_root)
                elif args.command == "reviewer-pre-tool":
                    output = pre_tool(event, state_root)
                elif args.command == "reviewer-start":
                    output = reviewer_start(event, state_root)
                elif args.command == "reviewer-stop":
                    output = reviewer_stop(project, event, state_root)
                else:
                    output = stop_hook(project, event, state_root)
        emit(output)
    except Exception as exc:
        emit(error_output(args.command, exc, event))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

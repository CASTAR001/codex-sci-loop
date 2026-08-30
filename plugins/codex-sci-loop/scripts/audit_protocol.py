#!/usr/bin/env python3
"""Canonical clean-room audit snapshots, receipts, and completion gating."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import stat
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any, NoReturn

import sci_loop as loop


SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
ID_RE = re.compile(r"^[A-Za-z][A-Za-z0-9._-]{0,63}$")
OUTCOMES = {"PASS", "FAIL", "UNVERIFIED", "BLOCKED"}
REVIEWER_TYPE = "independent_completion_auditor"
EXIT_CODES = {
    "ALLOW_COMPLETE": 0,
    "BLOCK_REQUIRES_USER": 20,
    "BLOCK_STALE": 30,
    "BLOCK_AUDIT": 31,
    "BLOCK_INVALID": 32,
}
MAX_JSON_BYTES = 8 * 1024 * 1024
MAX_REVIEWER_TRANSCRIPT_BYTES = 64 * 1024 * 1024


class AuditProtocolError(RuntimeError):
    """A fail-closed protocol error with a stable gate state."""

    def __init__(self, state: str, message: str):
        super().__init__(message)
        self.state = state


def canonical_bytes(value: Any) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")


def canonical_hash(value: Any) -> str:
    return hashlib.sha256(canonical_bytes(value)).hexdigest()


def file_hash(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while chunk := handle.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def read_object(path: Path, label: str) -> dict[str, Any]:
    try:
        if path.stat().st_size > MAX_JSON_BYTES:
            raise AuditProtocolError("BLOCK_INVALID", f"{label} exceeds the JSON size limit")
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise AuditProtocolError("BLOCK_INVALID", f"{label} is missing") from exc
    except (OSError, json.JSONDecodeError) as exc:
        raise AuditProtocolError("BLOCK_INVALID", f"{label} is not valid JSON: {exc}") from exc
    if not isinstance(value, dict):
        raise AuditProtocolError("BLOCK_INVALID", f"{label} root must be an object")
    return value


def exact_fields(value: dict[str, Any], fields: set[str], label: str) -> None:
    if set(value) != fields:
        raise AuditProtocolError("BLOCK_INVALID", f"{label} fields do not match the v1 protocol")


def nonempty_text(value: Any, label: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise AuditProtocolError("BLOCK_INVALID", f"{label} must be non-empty text")
    return value


def identifier(value: Any, label: str) -> str:
    if not isinstance(value, str) or ID_RE.fullmatch(value) is None:
        raise AuditProtocolError("BLOCK_INVALID", f"{label} is invalid")
    return value


def opaque_identifier(value: Any, label: str) -> str:
    if (
        not isinstance(value, str)
        or not value
        or len(value) > 256
        or any(ord(character) < 0x20 or ord(character) == 0x7F for character in value)
    ):
        raise AuditProtocolError("BLOCK_INVALID", f"{label} is invalid")
    return value


def sha256(value: Any, label: str) -> str:
    if not isinstance(value, str) or SHA256_RE.fullmatch(value) is None:
        raise AuditProtocolError("BLOCK_INVALID", f"{label} must be a lowercase SHA-256")
    return value


def validate_request(value: dict[str, Any]) -> None:
    exact_fields(value, {"schema", "request_id", "original_request", "revisions"}, "request envelope")
    if value["schema"] != "sci-loop-request-envelope-v1":
        raise AuditProtocolError("BLOCK_INVALID", "request envelope schema is invalid")
    identifier(value["request_id"], "request id")
    nonempty_text(value["original_request"], "original request")
    revisions = value["revisions"]
    if not isinstance(revisions, list):
        raise AuditProtocolError("BLOCK_INVALID", "request revisions must be an array")
    seen: set[str] = set()
    for revision in revisions:
        if not isinstance(revision, dict):
            raise AuditProtocolError("BLOCK_INVALID", "request revision must be an object")
        exact_fields(revision, {"revision_id", "text"}, "request revision")
        revision_id = identifier(revision["revision_id"], "request revision id")
        if revision_id in seen:
            raise AuditProtocolError("BLOCK_INVALID", "request revision ids must be unique")
        seen.add(revision_id)
        nonempty_text(revision["text"], "request revision text")


def validate_criteria(value: dict[str, Any]) -> list[str]:
    exact_fields(value, {"schema", "criteria"}, "acceptance criteria")
    if value["schema"] != "sci-loop-acceptance-criteria-v1" or not isinstance(value["criteria"], list):
        raise AuditProtocolError("BLOCK_INVALID", "acceptance criteria schema is invalid")
    if not value["criteria"]:
        raise AuditProtocolError("BLOCK_INVALID", "acceptance criteria cannot be empty")
    ids: list[str] = []
    for item in value["criteria"]:
        if not isinstance(item, dict):
            raise AuditProtocolError("BLOCK_INVALID", "acceptance criterion must be an object")
        exact_fields(item, {"id", "statement", "evidence_required"}, "acceptance criterion")
        criterion_id = identifier(item["id"], "acceptance criterion id")
        if criterion_id in ids:
            raise AuditProtocolError("BLOCK_INVALID", "acceptance criterion ids must be unique")
        ids.append(criterion_id)
        nonempty_text(item["statement"], "acceptance criterion statement")
        required = item["evidence_required"]
        if not isinstance(required, list) or not required or any(not isinstance(entry, str) or not entry for entry in required):
            raise AuditProtocolError("BLOCK_INVALID", "criterion evidence requirements must be non-empty strings")
    return ids


def validate_claims(value: dict[str, Any], criterion_ids: list[str]) -> list[str]:
    exact_fields(value, {"schema", "claims"}, "completion claims")
    if value["schema"] != "sci-loop-completion-claims-v1" or not isinstance(value["claims"], list):
        raise AuditProtocolError("BLOCK_INVALID", "completion claims schema is invalid")
    if not value["claims"]:
        raise AuditProtocolError("BLOCK_INVALID", "completion claims cannot be empty")
    ids: list[str] = []
    covered: set[str] = set()
    allowed = set(criterion_ids)
    for item in value["claims"]:
        if not isinstance(item, dict):
            raise AuditProtocolError("BLOCK_INVALID", "completion claim must be an object")
        exact_fields(item, {"id", "statement", "criterion_ids"}, "completion claim")
        claim_id = identifier(item["id"], "completion claim id")
        if claim_id in ids:
            raise AuditProtocolError("BLOCK_INVALID", "completion claim ids must be unique")
        ids.append(claim_id)
        nonempty_text(item["statement"], "completion claim statement")
        linked = item["criterion_ids"]
        if not isinstance(linked, list) or not linked or len(set(linked)) != len(linked):
            raise AuditProtocolError("BLOCK_INVALID", "claim criterion ids must be a unique non-empty array")
        if any(not isinstance(entry, str) or entry not in allowed for entry in linked):
            raise AuditProtocolError("BLOCK_INVALID", "claim references an unknown acceptance criterion")
        covered.update(linked)
    if covered != allowed:
        raise AuditProtocolError("BLOCK_INVALID", "every acceptance criterion must be covered by a completion claim")
    return ids


def receipt_public_key() -> Path:
    path = Path(__file__).resolve().parents[1] / "certifications" / "receipt-authority-public.pub"
    if path.is_symlink() or not path.is_file():
        raise AuditProtocolError("BLOCK_INVALID", "receipt authority public key is not configured safely")
    if not 1 <= path.stat().st_size <= 4096:
        raise AuditProtocolError("BLOCK_INVALID", "receipt authority public key size is invalid")
    try:
        result = subprocess.run(
            ["openssl", "pkey", "-pubin", "-in", str(path), "-noout"],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
            timeout=10,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise AuditProtocolError("BLOCK_INVALID", f"receipt public key verifier is unavailable: {exc}") from exc
    if result.returncode != 0:
        raise AuditProtocolError("BLOCK_INVALID", "receipt authority public key is not valid")
    return path


def validate_certification(value: dict[str, Any], public_key: Path) -> None:
    exact_fields(
        value,
        {
            "schema",
            "state",
            "runtime",
            "runtime_version",
            "plugin_version",
            "adapter_id",
            "certificate_sha256",
            "probe_sha256",
            "runtime_artifact_sha256",
            "plugin_tree_sha256",
            "receipt_authority_public_key_sha256",
            "receipt_signature_algorithm",
        },
        "runtime certification",
    )
    if value["schema"] != "sci-loop-runtime-certification-identity-v1" or value["state"] != "CERTIFIED":
        raise AuditProtocolError("BLOCK_INVALID", "runtime certification is not certified")
    if value["runtime"] != "codex":
        raise AuditProtocolError("BLOCK_INVALID", "runtime certification runtime is invalid")
    for field in ("runtime_version", "plugin_version", "adapter_id"):
        nonempty_text(value[field], f"runtime certification {field}")
    for field in ("certificate_sha256", "probe_sha256", "runtime_artifact_sha256", "plugin_tree_sha256"):
        sha256(value[field], f"runtime certification {field}")
    sha256(value["receipt_authority_public_key_sha256"], "runtime certification receipt public key")
    if value["receipt_authority_public_key_sha256"] != file_hash(public_key):
        raise AuditProtocolError("BLOCK_INVALID", "runtime certification does not bind the receipt public key")
    if value["receipt_signature_algorithm"] != "ed25519":
        raise AuditProtocolError("BLOCK_INVALID", "runtime certification receipt signature algorithm is invalid")


def evidence_entry(identifier_value: str, path: Path) -> dict[str, Any]:
    if not path.is_file() or path.is_symlink():
        raise AuditProtocolError("BLOCK_INVALID", f"evidence file is missing or unsafe: {path.name}")
    return {"id": identifier_value, "sha256": file_hash(path), "bytes": path.stat().st_size}


def current_workspace(
    root: Path,
    config: dict[str, Any],
    phase: dict[str, Any],
    run_dir: Path,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    repositories = loop.resolve_evidence_repositories(root, config)
    heads = phase.get("repository_heads")
    if not isinstance(heads, dict) or set(heads) != set(repositories):
        raise AuditProtocolError("BLOCK_STALE", "evidence repository identities changed")
    patches: list[str] = []
    statuses: list[str] = []
    changed: list[str] = []
    records: list[dict[str, Any]] = []
    for repository_id, repository in repositories.items():
        base = heads.get(repository_id)
        if not isinstance(base, str) or not base:
            raise AuditProtocolError("BLOCK_INVALID", "repository base commit is missing")
        patch = loop.tracked_patch(repository_id, repository, base)
        patch += loop.untracked_business_patch(root, repository_id, repository)
        status = loop.business_status(repository_id, repository)
        files = loop.changed_files(repository_id, repository, base)
        patches.append(patch)
        statuses.append(loop.prefix_lines(repository_id, status))
        changed.extend(item if repository_id == "." else f"{repository_id}/{item}" for item in files)
        records.append(
            {
                "repository": repository_id,
                "base_commit": base,
                "current_head": loop.git(repository, "rev-parse", "HEAD").strip(),
                "status_sha256": hashlib.sha256(status.encode("utf-8")).hexdigest(),
                "patch_sha256": hashlib.sha256(patch.encode("utf-8")).hexdigest(),
                "changed_files_sha256": canonical_hash(files),
            }
        )
    actual_patch = "".join(patches)
    actual_status = "".join(statuses)
    actual_changed = "\n".join(sorted(set(changed))) + "\n"
    expected = {
        "diff.patch": actual_patch,
        "status_after.txt": actual_status,
        "changed_files.txt": actual_changed,
    }
    for name, content in expected.items():
        path = run_dir / name
        try:
            captured = path.read_text(encoding="utf-8")
        except OSError as exc:
            raise AuditProtocolError("BLOCK_INVALID", f"captured evidence is unreadable: {name}") from exc
        if captured != content:
            raise AuditProtocolError("BLOCK_STALE", f"captured evidence is stale: {name}")
    manifest = [
        evidence_entry("workspace.patch", run_dir / "diff.patch"),
        evidence_entry("workspace.status", run_dir / "status_after.txt"),
        evidence_entry("workspace.changed-files", run_dir / "changed_files.txt"),
        evidence_entry("verification.log", run_dir / "verify.log"),
    ]
    return records, manifest


def phase_by_id(status: dict[str, Any], phase_id: str) -> dict[str, Any]:
    current = status.get("current_phase")
    if not isinstance(current, dict) or current.get("phase_id") != phase_id:
        raise AuditProtocolError("BLOCK_INVALID", "phase is not current")
    if current.get("status") != "audit_prepared":
        raise AuditProtocolError("BLOCK_INVALID", "phase is not ready for independent audit")
    if current.get("verify_exit_code") != 0:
        raise AuditProtocolError("BLOCK_AUDIT", "deterministic verification did not pass")
    return current


def trusted_root(raw: str, project_root: Path) -> Path:
    candidate_raw = Path(raw).expanduser()
    if candidate_raw.is_symlink():
        raise AuditProtocolError("BLOCK_INVALID", "trusted root must not be a symlink")
    candidate = candidate_raw.resolve()
    if not candidate.is_dir():
        raise AuditProtocolError("BLOCK_INVALID", "trusted root is not a directory")
    try:
        candidate.relative_to(project_root)
        raise AuditProtocolError("BLOCK_INVALID", "trusted root must be outside the project")
    except ValueError:
        pass
    try:
        project_root.relative_to(candidate)
        raise AuditProtocolError("BLOCK_INVALID", "trusted root must not contain the project")
    except ValueError:
        pass
    metadata = candidate.stat()
    if metadata.st_uid != os.geteuid() or stat.S_IMODE(metadata.st_mode) != 0o700:
        raise AuditProtocolError("BLOCK_INVALID", "trusted root must be owned by the gate user with mode 0700")
    return candidate


def protected_file(root: Path, name: str, required: bool = True) -> Path:
    if not name or Path(name).name != name:
        raise AuditProtocolError("BLOCK_INVALID", "protected file name is invalid")
    path = root / name
    if not path.exists() and not required:
        return path
    if path.is_symlink() or not path.is_file():
        raise AuditProtocolError("BLOCK_INVALID", f"protected file is missing or unsafe: {name}")
    metadata = path.stat()
    if metadata.st_uid != os.geteuid() or stat.S_IMODE(metadata.st_mode) != 0o600:
        raise AuditProtocolError("BLOCK_INVALID", f"protected file must be owned by the gate user with mode 0600: {name}")
    return path


def build_snapshot(project_root: Path, phase_id: str, certification_path: Path) -> dict[str, Any]:
    paths, config, status = loop.validate_project(project_root)
    phase = phase_by_id(status, phase_id)
    run_dir = paths["runs"] / phase_id
    request_path = run_dir / "request-envelope.json"
    criteria_path = run_dir / "acceptance-criteria.json"
    claims_path = run_dir / "completion-claims.json"
    request = read_object(request_path, "request envelope")
    criteria = read_object(criteria_path, "acceptance criteria")
    claims = read_object(claims_path, "completion claims")
    certification = read_object(certification_path, "runtime certification")
    validate_request(request)
    criterion_ids = validate_criteria(criteria)
    validate_claims(claims, criterion_ids)
    validate_certification(certification, receipt_public_key())
    repositories, manifest = current_workspace(project_root, config, phase, run_dir)
    manifest.append(evidence_entry("runtime.certification", certification_path))
    verify_log = run_dir / "verify.log"
    return {
        "schema": "sci-loop-audit-snapshot-v1",
        "phase_id": phase_id,
        "phase_title": nonempty_text(phase.get("title"), "phase title"),
        "phase_objective": nonempty_text(phase.get("objective"), "phase objective"),
        "request": request,
        "acceptance_criteria": criteria,
        "completion_claims": claims,
        "source_hashes": {
            "request_envelope_sha256": file_hash(request_path),
            "acceptance_criteria_sha256": file_hash(criteria_path),
            "completion_claims_sha256": file_hash(claims_path),
            "runtime_certification_sha256": file_hash(certification_path),
        },
        "workspace": {"repositories": repositories},
        "verification": {
            "command": nonempty_text(phase.get("verify_command"), "verification command"),
            "exit_code": 0,
            "log_sha256": file_hash(verify_log),
            "log_bytes": verify_log.stat().st_size,
        },
        "evidence_manifest": sorted(manifest, key=lambda item: item["id"]),
        "runtime_certification": certification,
    }


def derived_outcome(results: list[dict[str, Any]]) -> str:
    values = {item["outcome"] for item in results}
    for state in ("FAIL", "UNVERIFIED", "BLOCKED"):
        if state in values:
            return state
    return "PASS"


def validate_results(
    raw: Any,
    expected_ids: list[str],
    evidence_ids: set[str],
    label: str,
) -> list[dict[str, Any]]:
    if not isinstance(raw, list) or len(raw) != len(expected_ids):
        raise AuditProtocolError("BLOCK_AUDIT", f"{label} must cover every id exactly once")
    results: list[dict[str, Any]] = []
    ids: list[str] = []
    for item in raw:
        if not isinstance(item, dict):
            raise AuditProtocolError("BLOCK_AUDIT", f"{label} entry must be an object")
        exact_fields(item, {"id", "outcome", "evidence_refs", "rationale"}, f"{label} entry")
        item_id = identifier(item["id"], f"{label} id")
        ids.append(item_id)
        if item["outcome"] not in OUTCOMES:
            raise AuditProtocolError("BLOCK_AUDIT", f"{label} outcome is invalid")
        references = item["evidence_refs"]
        if not isinstance(references, list) or len(set(references)) != len(references):
            raise AuditProtocolError("BLOCK_AUDIT", f"{label} evidence refs must be a unique array")
        if any(not isinstance(reference, str) or reference not in evidence_ids for reference in references):
            raise AuditProtocolError("BLOCK_AUDIT", f"{label} references unknown evidence")
        if item["outcome"] == "PASS" and not references:
            raise AuditProtocolError("BLOCK_AUDIT", f"passing {label} entries require evidence")
        nonempty_text(item["rationale"], f"{label} rationale")
        results.append(item)
    if set(ids) != set(expected_ids) or len(ids) != len(set(ids)):
        raise AuditProtocolError("BLOCK_AUDIT", f"{label} ids do not match the snapshot")
    return results


def validate_outcome(snapshot: dict[str, Any], outcome: dict[str, Any]) -> str:
    exact_fields(
        outcome,
        {
            "schema",
            "snapshot_sha256",
            "reviewer_thread_id",
            "requirement_results",
            "claim_results",
            "overall",
            "blocked_requires_user",
            "summary",
        },
        "audit outcome",
    )
    if outcome["schema"] != "sci-loop-independent-audit-outcome-v1":
        raise AuditProtocolError("BLOCK_AUDIT", "audit outcome schema is invalid")
    if outcome["snapshot_sha256"] != canonical_hash(snapshot):
        raise AuditProtocolError("BLOCK_STALE", "audit outcome targets a stale snapshot")
    opaque_identifier(outcome["reviewer_thread_id"], "reviewer thread id")
    criteria_ids = [item["id"] for item in snapshot["acceptance_criteria"]["criteria"]]
    claim_ids = [item["id"] for item in snapshot["completion_claims"]["claims"]]
    evidence_ids = {item["id"] for item in snapshot["evidence_manifest"]}
    requirement_results = validate_results(
        outcome["requirement_results"], criteria_ids, evidence_ids, "requirement results"
    )
    claim_results = validate_results(outcome["claim_results"], claim_ids, evidence_ids, "claim results")
    expected = derived_outcome(requirement_results + claim_results)
    if outcome["overall"] != expected:
        raise AuditProtocolError("BLOCK_AUDIT", "audit overall does not match per-item outcomes")
    if not isinstance(outcome["blocked_requires_user"], bool):
        raise AuditProtocolError("BLOCK_AUDIT", "blocked_requires_user must be boolean")
    if outcome["blocked_requires_user"] != (expected == "BLOCKED"):
        raise AuditProtocolError("BLOCK_AUDIT", "only a BLOCKED outcome may require the user")
    nonempty_text(outcome["summary"], "audit outcome summary")
    return expected


def validate_observation(value: dict[str, Any], snapshot_hash: str, reviewer_thread_id: str) -> None:
    exact_fields(
        value,
        {
            "schema",
            "reviewer_thread_id",
            "reviewer_type",
            "snapshot_sha256",
            "isolation",
            "parent_history_shared",
            "started",
            "stopped",
        },
        "reviewer observation",
    )
    expected = {
        "schema": "sci-loop-reviewer-observation-v1",
        "reviewer_thread_id": reviewer_thread_id,
        "reviewer_type": REVIEWER_TYPE,
        "snapshot_sha256": snapshot_hash,
        "isolation": "clean-room-read-only",
        "parent_history_shared": False,
        "started": True,
        "stopped": True,
    }
    for field, expected_value in expected.items():
        if value.get(field) != expected_value:
            raise AuditProtocolError("BLOCK_AUDIT", f"reviewer observation failed: {field}")


def verify_receipt_signature(receipt: dict[str, Any], signature_path: Path) -> None:
    public_key = receipt_public_key()
    if signature_path.stat().st_size != 64:
        raise AuditProtocolError("BLOCK_AUDIT", "audit receipt signature size is invalid")
    with tempfile.TemporaryDirectory(prefix="sci-loop-receipt-verify-") as raw:
        payload_path = Path(raw) / "receipt.json"
        payload_path.write_bytes(canonical_bytes(receipt))
        try:
            result = subprocess.run(
                [
                    "openssl",
                    "pkeyutl",
                    "-verify",
                    "-pubin",
                    "-inkey",
                    str(public_key),
                    "-rawin",
                    "-in",
                    str(payload_path),
                    "-sigfile",
                    str(signature_path),
                ],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                check=False,
                timeout=15,
            )
        except (OSError, subprocess.TimeoutExpired) as exc:
            raise AuditProtocolError("BLOCK_INVALID", f"receipt signature verifier is unavailable: {exc}") from exc
    if result.returncode != 0:
        raise AuditProtocolError("BLOCK_AUDIT", "audit receipt signature is invalid")


def gate(project_root: Path, phase_id: str, protected_root: Path) -> tuple[dict[str, Any], int]:
    certification_path = protected_file(protected_root, "runtime-certification.json")
    run_dir = project_root / ".ai-loop" / "runs" / phase_id
    snapshot_path = run_dir / "audit-snapshot.json"
    saved_snapshot = read_object(snapshot_path, "audit snapshot")
    current_snapshot = build_snapshot(project_root, phase_id, certification_path)
    if canonical_bytes(saved_snapshot) != canonical_bytes(current_snapshot):
        raise AuditProtocolError("BLOCK_STALE", "audit snapshot is no longer current")
    snapshot_hash = canonical_hash(saved_snapshot)
    outcome_path = protected_file(protected_root, "audit-outcome.json")
    observation_path = protected_file(protected_root, "reviewer-observation.json")
    transcript_path = protected_file(protected_root, "reviewer-transcript.log")
    receipt_path = protected_file(protected_root, "audit-receipt.json", required=False)
    signature_path = protected_file(protected_root, "audit-receipt.sig", required=False)
    outcome = read_object(outcome_path, "audit outcome")
    overall = validate_outcome(saved_snapshot, outcome)
    observation = read_object(observation_path, "reviewer observation")
    validate_observation(observation, snapshot_hash, outcome["reviewer_thread_id"])
    transcript_size = transcript_path.stat().st_size
    if not 1 <= transcript_size <= MAX_REVIEWER_TRANSCRIPT_BYTES:
        raise AuditProtocolError("BLOCK_AUDIT", "reviewer transcript size is invalid")
    if not receipt_path.is_file() or not signature_path.is_file():
        raise AuditProtocolError("BLOCK_AUDIT", "audit receipt or signature is missing")
    receipt = read_object(receipt_path, "audit receipt")
    verify_receipt_signature(receipt, signature_path)
    expected_receipt = {
        "schema": "sci-loop-audit-receipt-v1",
        "issued_by": "lumiforge-independent-audit-host-v1",
        "snapshot_sha256": snapshot_hash,
        "audit_outcome_sha256": file_hash(outcome_path),
        "reviewer_transcript_sha256": file_hash(transcript_path),
        "reviewer_observation_sha256": file_hash(observation_path),
        "runtime_certification_sha256": file_hash(certification_path),
        "receipt_authority_public_key_sha256": file_hash(receipt_public_key()),
        "receipt_signature_algorithm": "ed25519",
        "reviewer_thread_id": outcome["reviewer_thread_id"],
        "verdict": overall,
    }
    exact_fields(receipt, set(expected_receipt), "audit receipt")
    for key, value in expected_receipt.items():
        if receipt.get(key) != value:
            raise AuditProtocolError("BLOCK_STALE", f"audit receipt binding is stale or invalid: {key}")
    if overall == "PASS":
        return gate_result("ALLOW_COMPLETE", [], phase_id, snapshot_hash), EXIT_CODES["ALLOW_COMPLETE"]
    if overall == "BLOCKED" and outcome["blocked_requires_user"] is True:
        return gate_result("BLOCK_REQUIRES_USER", ["independent_audit_requires_user"], phase_id, snapshot_hash), EXIT_CODES[
            "BLOCK_REQUIRES_USER"
        ]
    return gate_result("BLOCK_AUDIT", [f"independent_audit_{overall.lower()}"], phase_id, snapshot_hash), EXIT_CODES[
        "BLOCK_AUDIT"
    ]


def gate_result(state: str, reasons: list[str], phase_id: str, snapshot_hash: str = "") -> dict[str, Any]:
    return {
        "schema": "sci-loop-completion-decision-v1",
        "ok": state == "ALLOW_COMPLETE",
        "state": state,
        "phase_id": phase_id,
        "snapshot_sha256": snapshot_hash,
        "reasons": reasons,
    }


def cmd_snapshot(project_root: Path, args: argparse.Namespace) -> int:
    protected_root = trusted_root(args.trusted_root, project_root)
    certification_path = protected_file(protected_root, "runtime-certification.json")
    snapshot = build_snapshot(project_root, args.phase_id, certification_path)
    output = project_root / ".ai-loop" / "runs" / args.phase_id / "audit-snapshot.json"
    loop.atomic_json(output, snapshot)
    print(json.dumps({"ok": True, "snapshot_sha256": canonical_hash(snapshot)}, sort_keys=True))
    return 0


def cmd_validate_outcome(_project_root: Path | None, args: argparse.Namespace) -> int:
    snapshot = read_object(Path(args.snapshot).expanduser().resolve(), "audit snapshot")
    outcome = read_object(Path(args.outcome).expanduser().resolve(), "audit outcome")
    overall = validate_outcome(snapshot, outcome)
    print(json.dumps({"ok": overall == "PASS", "overall": overall}, sort_keys=True))
    return 0 if overall == "PASS" else EXIT_CODES["BLOCK_AUDIT"]


def apply_terminal_decision(
    project_root: Path,
    phase_id: str,
    payload: dict[str, Any],
) -> None:
    if payload["state"] not in {"ALLOW_COMPLETE", "BLOCK_REQUIRES_USER"}:
        raise AuditProtocolError("BLOCK_AUDIT", "non-terminal gate state cannot finalize a phase")
    paths, _config, status = loop.validate_project(project_root)
    decision = "accepted" if payload["state"] == "ALLOW_COMPLETE" else "blocked"
    decided_at = loop.utc_now()
    status = loop.update_phase(status, phase_id, status=decision, decided_at=decided_at)
    status["last_decision"] = decision.upper()
    loop.atomic_json(paths["status"], status)
    loop.append_event(
        paths,
        "phase_decided_by_receipt",
        phase_id,
        decision=decision.upper(),
        snapshot_sha256=payload["snapshot_sha256"],
    )


def run_gate_command(project_root: Path, args: argparse.Namespace, finalize: bool) -> int:
    protected_root = trusted_root(args.trusted_root, project_root)
    payload, exit_code = gate(project_root, args.phase_id, protected_root)
    if finalize and payload["state"] in {"ALLOW_COMPLETE", "BLOCK_REQUIRES_USER"}:
        apply_terminal_decision(project_root, args.phase_id, payload)
    print(json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":")))
    return exit_code


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    subparsers = result.add_subparsers(dest="command", required=True)
    snapshot = subparsers.add_parser("snapshot")
    snapshot.add_argument("--project-root", required=True)
    snapshot.add_argument("--phase-id", required=True)
    snapshot.add_argument("--trusted-root", required=True)
    snapshot.set_defaults(handler=cmd_snapshot, project_optional=False)
    validate = subparsers.add_parser("validate-outcome")
    validate.add_argument("--snapshot", required=True)
    validate.add_argument("--outcome", required=True)
    validate.set_defaults(handler=cmd_validate_outcome, project_optional=True)
    for name in ("completion-gate", "finalize"):
        item = subparsers.add_parser(name)
        item.add_argument("--project-root", required=True)
        item.add_argument("--phase-id", required=True)
        item.add_argument("--trusted-root", required=True)
        item.set_defaults(handler=lambda root, args, final=name == "finalize": run_gate_command(root, args, final))
        item.set_defaults(project_optional=False)
    return result


def fail(error: AuditProtocolError, phase_id: str) -> NoReturn:
    payload = gate_result(error.state, [str(error)], phase_id)
    print(json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":")))
    raise SystemExit(EXIT_CODES[error.state])


def main() -> int:
    args = parser().parse_args()
    try:
        root = None if getattr(args, "project_optional", False) else loop.resolve_project(args.project_root)
        return int(args.handler(root, args))
    except (AuditProtocolError, loop.LoopError) as exc:
        error = exc if isinstance(exc, AuditProtocolError) else AuditProtocolError("BLOCK_INVALID", str(exc))
        fail(error, str(getattr(args, "phase_id", "")))
    return EXIT_CODES["BLOCK_INVALID"]


if __name__ == "__main__":
    raise SystemExit(main())

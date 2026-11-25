#!/usr/bin/env python3
"""Destructive fixtures for canonical sci-loop audit receipts and freshness."""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import Any

import jsonschema


ROOT = Path(__file__).resolve().parents[1]
PLUGIN = ROOT / "plugins" / "codex-sci-loop"
CORE = PLUGIN / "scripts" / "sci_loop.py"
PROTOCOL = PLUGIN / "scripts" / "audit_protocol.py"
SCHEMAS = PLUGIN / "schemas"
PHASE_ID = "receipt-fixture"
SIGNING_KEY: Path | None = None


def run(*command: str, cwd: Path | None = None, expect: int = 0) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        command,
        cwd=cwd or ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
        timeout=120,
        env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"},
    )
    assert result.returncode == expect, f"expected {expect}, got {result.returncode}: {' '.join(command)}\n{result.stdout}"
    return result


def write_json(path: Path, value: dict[str, Any], protected: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if protected:
        path.chmod(0o600)


def write_protected_text(path: Path, value: str) -> None:
    path.write_text(value, encoding="utf-8")
    path.chmod(0o600)


def file_hash(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical_hash(value: Any) -> str:
    return hashlib.sha256(
        json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
    ).hexdigest()


def schema(name: str) -> dict[str, Any]:
    return json.loads((SCHEMAS / name).read_text(encoding="utf-8"))


def certification() -> dict[str, Any]:
    manifest = json.loads((PLUGIN / ".codex-plugin" / "plugin.json").read_text(encoding="utf-8"))
    return {
        "schema": "sci-loop-runtime-certification-identity-v1",
        "state": "CERTIFIED",
        "runtime": "codex",
        "runtime_version": "0.147.0",
        "plugin_version": manifest["version"],
        "adapter_id": "codex-hooks-0.147-v1",
        "certificate_sha256": "1" * 64,
        "probe_sha256": "2" * 64,
        "runtime_artifact_sha256": "3" * 64,
        "plugin_tree_sha256": "4" * 64,
        "receipt_authority_public_key_sha256": file_hash(
            PLUGIN / "certifications" / "receipt-authority-public.pub"
        ),
        "receipt_signature_algorithm": "ed25519",
    }


def request_envelope() -> dict[str, Any]:
    return {
        "schema": "sci-loop-request-envelope-v1",
        "request_id": "request-001",
        "original_request": "Implement the bounded feature and prove every requirement.",
        "revisions": [{"revision_id": "revision-001", "text": "Do not touch production."}],
    }


def acceptance_criteria() -> dict[str, Any]:
    return {
        "schema": "sci-loop-acceptance-criteria-v1",
        "criteria": [
            {"id": "R01", "statement": "The business change is captured.", "evidence_required": ["diff"]},
            {"id": "R02", "statement": "Verification succeeds.", "evidence_required": ["verify log"]},
        ],
    }


def completion_claims() -> dict[str, Any]:
    return {
        "schema": "sci-loop-completion-claims-v1",
        "claims": [
            {"id": "C01", "statement": "The requested change exists.", "criterion_ids": ["R01"]},
            {"id": "C02", "statement": "The change passed verification.", "criterion_ids": ["R02"]},
        ],
    }


def result(item_id: str, outcome: str = "PASS") -> dict[str, Any]:
    return {
        "id": item_id,
        "outcome": outcome,
        "evidence_refs": ["workspace.patch", "verification.log"] if outcome == "PASS" else ["workspace.patch"],
        "rationale": f"Independent fixture result for {item_id}: {outcome}.",
    }


def outcome(snapshot: dict[str, Any], state: str = "PASS") -> dict[str, Any]:
    requirement_states = [state, "PASS"] if state != "PASS" else ["PASS", "PASS"]
    claim_states = [state, "PASS"] if state != "PASS" else ["PASS", "PASS"]
    return {
        "schema": "sci-loop-independent-audit-outcome-v1",
        "snapshot_sha256": canonical_hash(snapshot),
        "reviewer_thread_id": "reviewer-001",
        "requirement_results": [result("R01", requirement_states[0]), result("R02", requirement_states[1])],
        "claim_results": [result("C01", claim_states[0]), result("C02", claim_states[1])],
        "overall": state,
        "blocked_requires_user": state == "BLOCKED",
        "summary": f"Independent fixture verdict: {state}.",
    }


def observation(snapshot: dict[str, Any]) -> dict[str, Any]:
    return {
        "schema": "sci-loop-reviewer-observation-v1",
        "reviewer_thread_id": "reviewer-001",
        "reviewer_type": "independent_completion_auditor",
        "snapshot_sha256": canonical_hash(snapshot),
        "isolation": "clean-room-read-only",
        "parent_history_shared": False,
        "started": True,
        "stopped": True,
    }


def receipt(trusted: Path, verdict: str) -> dict[str, Any]:
    audit_outcome = json.loads((trusted / "audit-outcome.json").read_text(encoding="utf-8"))
    return {
        "schema": "sci-loop-audit-receipt-v1",
        "issued_by": "lumiforge-independent-audit-host-v1",
        "snapshot_sha256": audit_outcome["snapshot_sha256"],
        "audit_outcome_sha256": file_hash(trusted / "audit-outcome.json"),
        "reviewer_transcript_sha256": file_hash(trusted / "reviewer-transcript.log"),
        "reviewer_observation_sha256": file_hash(trusted / "reviewer-observation.json"),
        "runtime_certification_sha256": file_hash(trusted / "runtime-certification.json"),
        "receipt_authority_public_key_sha256": file_hash(
            PLUGIN / "certifications" / "receipt-authority-public.pub"
        ),
        "receipt_signature_algorithm": "ed25519",
        "reviewer_thread_id": audit_outcome["reviewer_thread_id"],
        "verdict": verdict,
    }


def sign_receipt(trusted: Path, private_key: Path | None = None) -> None:
    key = private_key or SIGNING_KEY
    assert key is not None
    receipt_value = json.loads((trusted / "audit-receipt.json").read_text(encoding="utf-8"))
    payload = trusted / ".receipt-signing-input"
    payload.write_bytes(
        json.dumps(receipt_value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
    )
    payload.chmod(0o600)
    signature = trusted / "audit-receipt.sig"
    try:
        run(
            "openssl",
            "pkeyutl",
            "-sign",
            "-inkey",
            str(key),
            "-rawin",
            "-in",
            str(payload),
            "-out",
            str(signature),
        )
    finally:
        payload.unlink(missing_ok=True)
    signature.chmod(0o600)


def set_audit(trusted: Path, snapshot: dict[str, Any], state: str) -> None:
    write_json(trusted / "audit-outcome.json", outcome(snapshot, state), protected=True)
    write_json(trusted / "reviewer-observation.json", observation(snapshot), protected=True)
    write_protected_text(trusted / "reviewer-transcript.log", "opaque reviewer transcript fixture\n")
    write_json(trusted / "audit-receipt.json", receipt(trusted, state), protected=True)
    sign_receipt(trusted)


def command(name: str, project: Path, trusted: Path, expect: int) -> dict[str, Any]:
    output = run(
        "python3",
        str(PROTOCOL),
        name,
        "--project-root",
        str(project),
        "--phase-id",
        PHASE_ID,
        "--trusted-root",
        str(trusted),
        expect=expect,
    ).stdout
    return json.loads(output)


def prepare(temporary: Path) -> tuple[Path, Path, Path, dict[str, Any]]:
    project = temporary / "project"
    trusted = temporary / "trusted"
    project.mkdir()
    trusted.mkdir(mode=0o700)
    trusted.chmod(0o700)
    run("git", "init", "-q", cwd=project)
    run("git", "config", "user.name", "LumiForge Test", cwd=project)
    run("git", "config", "user.email", "test.invalid@example.invalid", cwd=project)
    fixture = project / "fixture.txt"
    fixture.write_text("baseline\n", encoding="utf-8")
    run("git", "add", "fixture.txt", cwd=project)
    run("git", "commit", "-qm", "fixture", cwd=project)
    run("python3", str(CORE), "init", "--project-root", str(project))
    run("git", "add", ".ai-loop", cwd=project)
    run("git", "commit", "-qm", "track control plane", cwd=project)
    run(
        "python3",
        str(CORE),
        "start",
        "--project-root",
        str(project),
        "--phase-id",
        PHASE_ID,
        "--title",
        "Receipt fixture",
        "--objective",
        "Exercise a canonical independent audit receipt.",
        "--verify-command",
        "python3 -c 'print(\"receipt verification: OK\")'",
    )
    run_dir = project / ".ai-loop" / "runs" / PHASE_ID
    fixture.write_text("candidate\n", encoding="utf-8")
    write_json(run_dir / "request-envelope.json", request_envelope())
    write_json(run_dir / "acceptance-criteria.json", acceptance_criteria())
    write_json(run_dir / "completion-claims.json", completion_claims())
    (run_dir / "report.md").write_text("# Worker report\n\nThis prose is not authority.\n", encoding="utf-8")
    run("python3", str(CORE), "collect", "--project-root", str(project), "--phase-id", PHASE_ID)
    run("python3", str(CORE), "audit-pack", "--project-root", str(project), "--phase-id", PHASE_ID)
    assert ".ai-loop" not in (run_dir / "diff.patch").read_text(encoding="utf-8")
    assert ".ai-loop" not in (run_dir / "changed_files.txt").read_text(encoding="utf-8")
    assert ".ai-loop" not in (run_dir / "status_after.txt").read_text(encoding="utf-8")
    write_json(trusted / "runtime-certification.json", certification(), protected=True)
    command("snapshot", project, trusted, 0)
    snapshot = json.loads((run_dir / "audit-snapshot.json").read_text(encoding="utf-8"))
    set_audit(trusted, snapshot, "PASS")
    return project, trusted, fixture, snapshot


def validate_fixture_schemas(trusted: Path, snapshot: dict[str, Any]) -> None:
    jsonschema.validate(snapshot["request"], schema("request-envelope.schema.json"))
    jsonschema.validate(snapshot["acceptance_criteria"], schema("acceptance-criteria.schema.json"))
    jsonschema.validate(snapshot["completion_claims"], schema("completion-claims.schema.json"))
    jsonschema.validate(snapshot["runtime_certification"], schema("runtime-certification-identity.schema.json"))
    jsonschema.validate(snapshot, schema("audit-snapshot.schema.json"))
    jsonschema.validate(
        json.loads((trusted / "audit-outcome.json").read_text(encoding="utf-8")),
        schema("independent-audit-outcome.schema.json"),
    )
    jsonschema.validate(
        json.loads((trusted / "reviewer-observation.json").read_text(encoding="utf-8")),
        schema("reviewer-observation.schema.json"),
    )
    jsonschema.validate(
        json.loads((trusted / "audit-receipt.json").read_text(encoding="utf-8")),
        schema("audit-receipt.schema.json"),
    )


def main() -> None:
    global PLUGIN, CORE, PROTOCOL, SCHEMAS, SIGNING_KEY
    source_plugin = PLUGIN
    source = PROTOCOL.read_text(encoding="utf-8")
    assert "issue-receipt" not in source
    for hook_name in ("UserPromptSubmit", "SubagentStart", "SubagentStop", "Stop"):
        assert hook_name not in source
    with tempfile.TemporaryDirectory(prefix="lumiforge-audit-receipt-") as raw:
        temporary = Path(raw).resolve()
        plugin_copy = temporary / "plugin"
        shutil.copytree(source_plugin, plugin_copy)
        authority_private = temporary / "authority-private.pem"
        run("openssl", "genpkey", "-algorithm", "ED25519", "-out", str(authority_private))
        authority_private.chmod(0o600)
        run(
            "openssl",
            "pkey",
            "-in",
            str(authority_private),
            "-pubout",
            "-out",
            str(plugin_copy / "certifications" / "receipt-authority-public.pub"),
        )
        PLUGIN = plugin_copy
        CORE = plugin_copy / "scripts" / "sci_loop.py"
        PROTOCOL = plugin_copy / "scripts" / "audit_protocol.py"
        SCHEMAS = plugin_copy / "schemas"
        SIGNING_KEY = authority_private
        project, trusted, fixture, snapshot = prepare(temporary)
        validate_fixture_schemas(trusted, snapshot)
        assert snapshot["request"]["original_request"] == request_envelope()["original_request"]
        assert snapshot["request"]["revisions"] == request_envelope()["revisions"]
        assert "report" not in snapshot

        decision = command("completion-gate", project, trusted, 0)
        assert decision["state"] == "ALLOW_COMPLETE" and decision["ok"] is True

        fixture.write_text("changed after audit\n", encoding="utf-8")
        decision = command("completion-gate", project, trusted, 30)
        assert decision["state"] == "BLOCK_STALE"
        fixture.write_text("candidate\n", encoding="utf-8")

        request_path = project / ".ai-loop" / "runs" / PHASE_ID / "request-envelope.json"
        request = request_envelope()
        request["revisions"][0]["text"] = "Changed after audit."
        write_json(request_path, request)
        decision = command("completion-gate", project, trusted, 30)
        assert decision["state"] == "BLOCK_STALE"
        assert "verification is stale" in command("snapshot", project, trusted, 30)["reasons"][0]
        write_json(request_path, request_envelope())

        verify_path = request_path.with_name("verify.log")
        log = verify_path.read_bytes()
        verify_path.write_bytes(log + b"extra line\n")
        assert "verification is stale" in command("snapshot", project, trusted, 30)["reasons"][0]
        verify_path.write_bytes(log)

        status_path = project / ".ai-loop" / "status.json"
        status_bytes = status_path.read_bytes()
        legacy_status = json.loads(status_bytes)
        legacy_status["current_phase"].pop("verification_binding")
        legacy_status["phases"][-1].pop("verification_binding")
        write_json(status_path, legacy_status)
        assert "verification is stale" in command("snapshot", project, trusted, 30)["reasons"][0]
        status_path.write_bytes(status_bytes)

        changed_certification = certification()
        changed_certification["runtime_artifact_sha256"] = "9" * 64
        write_json(trusted / "runtime-certification.json", changed_certification, protected=True)
        decision = command("completion-gate", project, trusted, 30)
        assert decision["state"] == "BLOCK_STALE"
        write_json(trusted / "runtime-certification.json", certification(), protected=True)

        set_audit(trusted, snapshot, "UNVERIFIED")
        decision = command("completion-gate", project, trusted, 31)
        assert decision["state"] == "BLOCK_AUDIT" and "unverified" in decision["reasons"][0]

        set_audit(trusted, snapshot, "FAIL")
        decision = command("completion-gate", project, trusted, 31)
        assert decision["state"] == "BLOCK_AUDIT" and "fail" in decision["reasons"][0]

        mismatched = outcome(snapshot, "UNVERIFIED")
        mismatched["overall"] = "PASS"
        mismatched["blocked_requires_user"] = False
        write_json(trusted / "audit-outcome.json", mismatched, protected=True)
        write_json(trusted / "audit-receipt.json", receipt(trusted, "PASS"), protected=True)
        sign_receipt(trusted)
        decision = command("completion-gate", project, trusted, 31)
        assert decision["state"] == "BLOCK_AUDIT" and "overall" in decision["reasons"][0]

        set_audit(trusted, snapshot, "BLOCKED")
        decision = command("completion-gate", project, trusted, 20)
        assert decision["state"] == "BLOCK_REQUIRES_USER" and decision["ok"] is False

        set_audit(trusted, snapshot, "PASS")
        unsupported_pass = outcome(snapshot, "PASS")
        unsupported_pass["requirement_results"][0]["evidence_refs"] = []
        write_json(trusted / "audit-outcome.json", unsupported_pass, protected=True)
        write_json(trusted / "audit-receipt.json", receipt(trusted, "PASS"), protected=True)
        decision = command("completion-gate", project, trusted, 31)
        assert decision["state"] == "BLOCK_AUDIT"

        set_audit(trusted, snapshot, "PASS")
        invalid_observation = observation(snapshot)
        invalid_observation["parent_history_shared"] = True
        write_json(trusted / "reviewer-observation.json", invalid_observation, protected=True)
        decision = command("completion-gate", project, trusted, 31)
        assert decision["state"] == "BLOCK_AUDIT"

        set_audit(trusted, snapshot, "PASS")
        wrong_reviewer = observation(snapshot)
        wrong_reviewer["reviewer_type"] = "different_reviewer"
        write_json(trusted / "reviewer-observation.json", wrong_reviewer, protected=True)
        write_json(trusted / "audit-receipt.json", receipt(trusted, "PASS"), protected=True)
        sign_receipt(trusted)
        decision = command("completion-gate", project, trusted, 31)
        assert decision["state"] == "BLOCK_AUDIT" and "reviewer_type" in decision["reasons"][0]

        set_audit(trusted, snapshot, "PASS")
        (trusted / "audit-receipt.sig").unlink()
        decision = command("completion-gate", project, trusted, 31)
        assert decision["state"] == "BLOCK_AUDIT" and "signature" in decision["reasons"][0]

        set_audit(trusted, snapshot, "PASS")
        receipt_path = trusted / "audit-receipt.json"
        stale_receipt = receipt(trusted, "PASS")
        stale_receipt["snapshot_sha256"] = "0" * 64
        write_json(receipt_path, stale_receipt, protected=True)
        sign_receipt(trusted)
        decision = command("completion-gate", project, trusted, 30)
        assert decision["state"] == "BLOCK_STALE"

        set_audit(trusted, snapshot, "PASS")
        (trusted / "audit-outcome.json").write_text("review looks good\n", encoding="utf-8")
        (trusted / "audit-outcome.json").chmod(0o600)
        decision = command("completion-gate", project, trusted, 32)
        assert decision["state"] == "BLOCK_INVALID"

        set_audit(trusted, snapshot, "PASS")
        receipt_path.chmod(0o644)
        decision = command("completion-gate", project, trusted, 32)
        assert decision["state"] == "BLOCK_INVALID"
        receipt_path.chmod(0o600)

        unsafe_root = project / "forged-receipts"
        unsafe_root.mkdir(mode=0o700)
        decision = command("completion-gate", project, unsafe_root, 32)
        assert decision["state"] == "BLOCK_INVALID"

        forged_root = temporary / "attacker-receipts"
        forged_root.mkdir(mode=0o700)
        forged_root.chmod(0o700)
        for name in (
            "runtime-certification.json",
            "audit-outcome.json",
            "reviewer-observation.json",
            "reviewer-transcript.log",
            "audit-receipt.json",
        ):
            shutil.copyfile(trusted / name, forged_root / name)
            (forged_root / name).chmod(0o600)
        attacker_private = temporary / "attacker-private.pem"
        run("openssl", "genpkey", "-algorithm", "ED25519", "-out", str(attacker_private))
        attacker_private.chmod(0o600)
        sign_receipt(forged_root, attacker_private)
        decision = command("completion-gate", project, forged_root, 31)
        assert decision["state"] == "BLOCK_AUDIT" and "signature" in decision["reasons"][0]

        audit = project / ".ai-loop" / "audits" / f"{PHASE_ID}-audit.md"
        audit.write_text("# Prose-only audit\n\nDecision: ACCEPTED\n", encoding="utf-8")
        assert "host-authorized" in run(
            "python3",
            str(CORE),
            "decide",
            "--project-root",
            str(project),
            "--phase-id",
            PHASE_ID,
            "--decision",
            "accepted",
            expect=1,
        ).stdout

        write_json(request_path, request)
        fixture.write_text("staged candidate one\n", encoding="utf-8")
        run("git", "add", "fixture.txt", cwd=project)
        fixture.write_text("candidate\n", encoding="utf-8")
        run("python3", str(CORE), "collect", "--project-root", str(project), "--phase-id", PHASE_ID)
        run("python3", str(CORE), "audit-pack", "--project-root", str(project), "--phase-id", PHASE_ID)
        refreshed = command("snapshot", project, trusted, 0)
        updated_snapshot = json.loads(request_path.with_name("audit-snapshot.json").read_text(encoding="utf-8"))
        assert updated_snapshot["request"] == request and refreshed["snapshot_sha256"] != canonical_hash(snapshot)
        assert command("completion-gate", project, trusted, 30)["state"] == "BLOCK_STALE"
        set_audit(trusted, updated_snapshot, "PASS")
        decision = command("finalize", project, trusted, 0)
        assert decision["state"] == "ALLOW_COMPLETE"
        assert command("completion-gate", project, trusted, 0) == decision
        assert command("finalize", project, trusted, 0) == decision
        fixture.write_text("staged candidate two\n", encoding="utf-8")
        run("git", "add", "fixture.txt", cwd=project)
        fixture.write_text("candidate\n", encoding="utf-8")
        assert "verification is stale" in command("completion-gate", project, trusted, 30)["reasons"][0]
        fixture.write_text("changed after finalize\n", encoding="utf-8")
        assert command("completion-gate", project, trusted, 30)["state"] == "BLOCK_STALE"
        resumed = json.loads(
            run("python3", str(CORE), "resume", "--project-root", str(project), "--json").stdout
        )
        assert resumed["decision"] == "READY_FOR_NEXT_PHASE" and resumed["status"] == "accepted"

    print(
        json.dumps(
            {
                "ok": True,
                "allowed": "PASS",
                "blocked": ["FAIL", "UNVERIFIED", "BLOCKED", "STALE", "INVALID"],
                "prose_acceptance": False,
            },
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Exercise Codex 0.147 hook adapter events without installing the plugin."""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
SOURCE_PLUGIN = ROOT / "plugins" / "codex-sci-loop"
PHASE_ID = "hook-fixture"
REVIEWER = "independent_completion_auditor"


def run(
    *command: str,
    cwd: Path | None = None,
    expect: int = 0,
    env: dict[str, str] | None = None,
    stdin: str | None = None,
) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        command,
        cwd=cwd or ROOT,
        input=stdin,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
        timeout=120,
        env=env or {**os.environ, "PYTHONDONTWRITEBYTECODE": "1"},
    )
    assert result.returncode == expect, f"expected {expect}, got {result.returncode}: {' '.join(command)}\n{result.stdout}"
    return result


def write_json(path: Path, value: dict[str, Any], mode: int | None = None) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if mode is not None:
        path.chmod(mode)


def file_hash(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while chunk := handle.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def canonical_hash(value: Any) -> str:
    return hashlib.sha256(
        json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
    ).hexdigest()


def plugin_tree_hash(plugin: Path) -> str:
    digest = hashlib.sha256()
    for path in sorted(plugin.rglob("*"), key=lambda item: item.as_posix()):
        relative = path.relative_to(plugin)
        if "__pycache__" in relative.parts or path.suffix == ".pyc" or path.name == ".DS_Store":
            continue
        assert not path.is_symlink(), relative
        if not path.is_file():
            continue
        encoded = relative.as_posix().encode("utf-8")
        content = path.read_bytes()
        digest.update(len(encoded).to_bytes(8, "big"))
        digest.update(encoded)
        digest.update(len(content).to_bytes(8, "big"))
        digest.update(content)
    return digest.hexdigest()


def common(project: Path, event: str, turn: str | None = None) -> dict[str, Any]:
    value: dict[str, Any] = {
        "session_id": "session-001",
        "transcript_path": None,
        "cwd": str(project),
        "hook_event_name": event,
        "model": "gpt-5.6",
        "permission_mode": "default",
    }
    if turn is not None:
        value["turn_id"] = turn
    return value


def hook(adapter: Path, command: str, event: dict[str, Any], environment: dict[str, str]) -> dict[str, Any]:
    output = run(
        "python3",
        str(adapter),
        command,
        env=environment,
        stdin=json.dumps(event, ensure_ascii=False),
    ).stdout
    return json.loads(output)


def make_project(temporary: Path, core: Path) -> tuple[Path, Path]:
    project = temporary / "project"
    project.mkdir()
    run("git", "init", "-q", cwd=project)
    run("git", "config", "user.name", "LumiForge Test", cwd=project)
    run("git", "config", "user.email", "test.invalid@example.invalid", cwd=project)
    fixture = project / "fixture.txt"
    fixture.write_text("baseline\n", encoding="utf-8")
    run("git", "add", "fixture.txt", cwd=project)
    run("git", "commit", "-qm", "fixture", cwd=project)
    run("python3", str(core), "init", "--project-root", str(project))
    run(
        "python3",
        str(core),
        "start",
        "--project-root",
        str(project),
        "--phase-id",
        PHASE_ID,
        "--title",
        "Hook fixture",
        "--objective",
        "Exercise the certified Codex hook adapter.",
        "--verify-command",
        "python3 -c 'print(\"hook verification: OK\")'",
    )
    return project, fixture


def configure_authority(plugin: Path, temporary: Path) -> Path:
    private_key = temporary / "host-private.pem"
    run("openssl", "genpkey", "-algorithm", "ED25519", "-out", str(private_key))
    private_key.chmod(0o600)
    run(
        "openssl",
        "pkey",
        "-in",
        str(private_key),
        "-pubout",
        "-out",
        str(plugin / "certifications" / "receipt-authority-public.pub"),
    )
    return private_key


def configure_capability(plugin: Path, temporary: Path) -> tuple[Path, Path, dict[str, Any]]:
    required_path = plugin / "capabilities" / "required.json"
    adapter_path = plugin / "adapters" / "codex-0.147.json"
    required = json.loads(required_path.read_text(encoding="utf-8"))
    adapter = json.loads(adapter_path.read_text(encoding="utf-8"))
    manifest = json.loads((plugin / ".codex-plugin" / "plugin.json").read_text(encoding="utf-8"))
    probe = {
        "schema": "sci-loop-runtime-probe-v1",
        "runtime": "codex",
        "runtime_version": "0.147.0",
        "plugin_version": manifest["version"],
        "adapter_id": adapter["adapter_id"],
        "plugin_tree_sha256": plugin_tree_hash(plugin),
        "runtime_artifact_sha256": "1" * 64,
        "behavior_evidence_sha256": "2" * 64,
        "capabilities": {name: int(constraint[2:]) for name, constraint in required["required"].items()},
        "preconditions": {name: True for name in required["required_preconditions"]},
        "observed_runtime_capabilities": [
            "SessionStart",
            "UserPromptSubmit",
            "PreToolUse:Agent",
            "SubagentStart",
            "SubagentStop",
            "Stop",
        ],
    }
    probe_path = temporary / "runtime-probe.json"
    write_json(probe_path, probe)
    certificates = temporary / "capability-certificates"
    certificates.mkdir()
    certificate = {
        "schema": "sci-loop-runtime-certificate-v1",
        "status": "CERTIFIED",
        "issued_by": "lumiforge-runtime-certifier-v1",
        "runtime": "codex",
        "runtime_version": "0.147.0",
        "plugin_version": probe["plugin_version"],
        "adapter_id": adapter["adapter_id"],
        "plugin_tree_sha256": probe["plugin_tree_sha256"],
        "runtime_artifact_sha256": probe["runtime_artifact_sha256"],
        "behavior_evidence_sha256": probe["behavior_evidence_sha256"],
        "required_contract_sha256": file_hash(required_path),
        "adapter_sha256": file_hash(adapter_path),
        "behavior_probe_sha256": file_hash(probe_path),
        "observed_runtime_capabilities_sha256": canonical_hash(sorted(probe["observed_runtime_capabilities"])),
    }
    certificate_path = certificates / "codex-0.147.0.json"
    write_json(certificate_path, certificate)
    return probe_path, certificates, certificate


def runtime_identity(plugin: Path, probe: Path, certificate: dict[str, Any], certificate_path: Path) -> dict[str, Any]:
    return {
        "schema": "sci-loop-runtime-certification-identity-v1",
        "state": "CERTIFIED",
        "runtime": "codex",
        "runtime_version": "0.147.0",
        "plugin_version": certificate["plugin_version"],
        "adapter_id": certificate["adapter_id"],
        "certificate_sha256": file_hash(certificate_path),
        "probe_sha256": file_hash(probe),
        "runtime_artifact_sha256": certificate["runtime_artifact_sha256"],
        "plugin_tree_sha256": certificate["plugin_tree_sha256"],
        "receipt_authority_public_key_sha256": file_hash(
            plugin / "certifications" / "receipt-authority-public.pub"
        ),
        "receipt_signature_algorithm": "ed25519",
    }


def create_structured_inputs(run_dir: Path) -> None:
    write_json(
        run_dir / "acceptance-criteria.json",
        {
            "schema": "sci-loop-acceptance-criteria-v1",
            "criteria": [
                {"id": "R01", "statement": "Hook behavior is proven.", "evidence_required": ["fixture"]}
            ],
        },
    )
    write_json(
        run_dir / "completion-claims.json",
        {
            "schema": "sci-loop-completion-claims-v1",
            "claims": [{"id": "C01", "statement": "Hook behavior passes.", "criterion_ids": ["R01"]}],
        },
    )
    (run_dir / "report.md").write_text("# Worker report\n\nFixture only.\n", encoding="utf-8")


def audit_outcome(snapshot: dict[str, Any], reviewer_id: str) -> dict[str, Any]:
    evidence = ["workspace.patch", "verification.log"]
    return {
        "schema": "sci-loop-independent-audit-outcome-v1",
        "snapshot_sha256": canonical_hash(snapshot),
        "reviewer_thread_id": reviewer_id,
        "requirement_results": [
            {"id": "R01", "outcome": "PASS", "evidence_refs": evidence, "rationale": "Fixture evidence passes."}
        ],
        "claim_results": [
            {"id": "C01", "outcome": "PASS", "evidence_refs": evidence, "rationale": "Fixture claim passes."}
        ],
        "overall": "PASS",
        "blocked_requires_user": False,
        "summary": "The isolated fixture passes.",
    }


def sign_receipt(trusted: Path, private_key: Path) -> None:
    receipt = json.loads((trusted / "audit-receipt.json").read_text(encoding="utf-8"))
    payload = trusted / ".receipt-payload"
    payload.write_bytes(json.dumps(receipt, sort_keys=True, separators=(",", ":")).encode("utf-8"))
    signature = trusted / "audit-receipt.sig"
    try:
        run(
            "openssl",
            "pkeyutl",
            "-sign",
            "-inkey",
            str(private_key),
            "-rawin",
            "-in",
            str(payload),
            "-out",
            str(signature),
        )
    finally:
        payload.unlink(missing_ok=True)
    signature.chmod(0o600)


def promote_candidate(plugin: Path, plugin_data: Path, trusted: Path, private_key: Path, snapshot: dict[str, Any]) -> None:
    session_key = hashlib.sha256(b"session-001").hexdigest()
    candidate = plugin_data / "sessions" / session_key / "review-candidate"
    for name in ("audit-outcome.json", "reviewer-observation.json", "reviewer-transcript.log"):
        shutil.copyfile(candidate / name, trusted / name)
        (trusted / name).chmod(0o600)
    outcome = json.loads((trusted / "audit-outcome.json").read_text(encoding="utf-8"))
    receipt = {
        "schema": "sci-loop-audit-receipt-v1",
        "issued_by": "lumiforge-independent-audit-host-v1",
        "snapshot_sha256": canonical_hash(snapshot),
        "audit_outcome_sha256": file_hash(trusted / "audit-outcome.json"),
        "reviewer_transcript_sha256": file_hash(trusted / "reviewer-transcript.log"),
        "reviewer_observation_sha256": file_hash(trusted / "reviewer-observation.json"),
        "runtime_certification_sha256": file_hash(trusted / "runtime-certification.json"),
        "receipt_authority_public_key_sha256": file_hash(
            plugin / "certifications" / "receipt-authority-public.pub"
        ),
        "receipt_signature_algorithm": "ed25519",
        "reviewer_thread_id": outcome["reviewer_thread_id"],
        "verdict": "PASS",
    }
    write_json(trusted / "audit-receipt.json", receipt, mode=0o600)
    sign_receipt(trusted, private_key)


def validate_hook_package(plugin: Path) -> None:
    manifest = json.loads((plugin / ".codex-plugin" / "plugin.json").read_text(encoding="utf-8"))
    assert "hooks" not in manifest and not (plugin / "hooks" / "hooks.json").exists()
    hooks = json.loads((plugin / "adapters" / "lumiforge" / "hooks.json").read_text(encoding="utf-8"))["hooks"]
    assert set(hooks) == {"SessionStart", "UserPromptSubmit", "PreToolUse", "SubagentStart", "SubagentStop", "Stop"}
    assert hooks["PreToolUse"][0]["matcher"] == "^Agent$"
    for groups in hooks.values():
        for group in groups:
            for handler in group["hooks"]:
                assert handler["type"] == "command" and handler.get("async") is not True
                assert 'python3 -B "$PLUGIN_ROOT/hooks/codex_adapter.py"' in handler["command"]
    agent = (plugin / "agent-templates" / f"{REVIEWER}.toml").read_text(encoding="utf-8")
    assert f'name = "{REVIEWER}"' in agent
    assert 'sandbox_mode = "read-only"' in agent and 'approval_policy = "never"' in agent
    domain = (plugin / "scripts" / "sci_loop.py").read_text(encoding="utf-8")
    audit_domain = (plugin / "scripts" / "audit_protocol.py").read_text(encoding="utf-8")
    for event in hooks:
        assert event not in domain and event not in audit_domain


def main() -> None:
    validate_hook_package(SOURCE_PLUGIN)
    assert (SOURCE_PLUGIN / "certifications" / "receipt-authority-public.pub").read_text(
        encoding="utf-8"
    ).startswith("UNCONFIGURED:")
    with tempfile.TemporaryDirectory(prefix="lumiforge-codex-hooks-") as raw:
        temporary = Path(raw).resolve()
        plugin = temporary / "plugin"
        shutil.copytree(SOURCE_PLUGIN, plugin)
        private_key = configure_authority(plugin, temporary)
        core = plugin / "scripts" / "sci_loop.py"
        protocol = plugin / "scripts" / "audit_protocol.py"
        adapter = plugin / "hooks" / "codex_adapter.py"
        project, fixture = make_project(temporary, core)
        plugin_data = temporary / "plugin-data"
        trusted = temporary / "trusted"
        plugin_data.mkdir(mode=0o700)
        trusted.mkdir(mode=0o700)
        plugin_data.chmod(0o700)
        trusted.chmod(0o700)
        probe, certificates, capability_certificate = configure_capability(plugin, temporary)
        certificate_path = certificates / "codex-0.147.0.json"
        write_json(
            trusted / "runtime-certification.json",
            runtime_identity(plugin, probe, capability_certificate, certificate_path),
            mode=0o600,
        )
        environment = {
            **os.environ,
            "PYTHONDONTWRITEBYTECODE": "1",
            "PLUGIN_ROOT": str(plugin),
            "PLUGIN_DATA": str(plugin_data),
            "LUMIFORGE_SCI_LOOP_PROBE": str(probe),
            "LUMIFORGE_SCI_LOOP_CERTIFICATE_ROOT": str(certificates),
            "LUMIFORGE_SCI_LOOP_TRUSTED_ROOT": str(trusted),
            "LUMIFORGE_SCI_LOOP_MODE": "goal",
        }

        session = {**common(project, "SessionStart"), "source": "startup"}
        unmanaged_environment = {
            key: value for key, value in environment.items() if not key.startswith("LUMIFORGE_")
        }
        assert hook(adapter, "session-start", session, unmanaged_environment) == {}
        assert hook(adapter, "session-start", {"unexpected": True}, unmanaged_environment) == {}
        managed_missing_environment = dict(environment)
        for name in (
            "LUMIFORGE_SCI_LOOP_PROBE",
            "LUMIFORGE_SCI_LOOP_CERTIFICATE_ROOT",
            "LUMIFORGE_SCI_LOOP_TRUSTED_ROOT",
        ):
            managed_missing_environment.pop(name)
        denied = hook(adapter, "session-start", session, managed_missing_environment)
        assert denied["continue"] is False
        identity_path = trusted / "runtime-certification.json"
        identity = json.loads(identity_path.read_text(encoding="utf-8"))
        mismatched_identity = dict(identity)
        mismatched_identity["adapter_id"] = "codex-hooks-wrong-adapter"
        write_json(identity_path, mismatched_identity, mode=0o600)
        assert hook(adapter, "session-start", session, environment)["continue"] is False
        write_json(identity_path, identity, mode=0o600)
        allowed = hook(adapter, "session-start", session, environment)
        assert allowed == {"continue": True}

        prompt_text = "  exact follow-up\nwith spacing  "
        prompt_event = {**common(project, "UserPromptSubmit", "turn-001"), "prompt": prompt_text}
        run_dir = project / ".ai-loop" / "runs" / PHASE_ID
        assert hook(adapter, "user-prompt-submit", prompt_event, unmanaged_environment) == {}
        assert hook(adapter, "user-prompt-submit", prompt_event, managed_missing_environment)["decision"] == "block"
        assert not (run_dir / "request-envelope.json").exists()
        assert hook(adapter, "user-prompt-submit", prompt_event, environment) == {}
        assert hook(adapter, "user-prompt-submit", prompt_event, environment) == {}
        envelope = json.loads((run_dir / "request-envelope.json").read_text(encoding="utf-8"))
        assert envelope["original_request"] == prompt_text and envelope["revisions"] == []

        create_structured_inputs(run_dir)
        fixture.write_text("candidate\n", encoding="utf-8")
        run("python3", str(core), "collect", "--project-root", str(project), "--phase-id", PHASE_ID)
        run("python3", str(core), "audit-pack", "--project-root", str(project), "--phase-id", PHASE_ID)
        run(
            "python3",
            str(protocol),
            "snapshot",
            "--project-root",
            str(project),
            "--phase-id",
            PHASE_ID,
            "--trusted-root",
            str(trusted),
        )
        snapshot = json.loads((run_dir / "audit-snapshot.json").read_text(encoding="utf-8"))

        stop_event = {
            **common(project, "Stop", "turn-001"),
            "stop_hook_active": False,
            "last_assistant_message": "I think this is complete.",
        }
        fixture.write_text("stale after snapshot\n", encoding="utf-8")
        stale_block = hook(adapter, "stop", stop_event, environment)
        assert stale_block["decision"] == "block" and "run collect" in stale_block["reason"]
        session_key = hashlib.sha256(b"session-001").hexdigest()
        request_path = plugin_data / "sessions" / session_key / "review-request.json"
        assert not request_path.exists()
        fixture.write_text("candidate\n", encoding="utf-8")
        later_stop = {**stop_event, "turn_id": "turn-later"}
        assert hook(adapter, "stop", later_stop, environment)["continue"] is False
        pause_event = {**prompt_event, "turn_id": "turn-pause", "prompt": "sci-loop pause"}
        pause = hook(adapter, "user-prompt-submit", pause_event, environment)
        assert pause["decision"] == "block" and "paused" in pause["reason"]
        paused = hook(adapter, "stop", later_stop, environment)
        assert paused["continue"] is False and "paused" in paused["systemMessage"]
        ordinary_while_paused = {**prompt_event, "turn_id": "turn-other", "prompt": "still paused"}
        assert hook(adapter, "user-prompt-submit", ordinary_while_paused, environment)["decision"] == "block"
        assert json.loads((run_dir / "request-envelope.json").read_text(encoding="utf-8")) == envelope
        resume_event = {**prompt_event, "turn_id": "turn-resume", "prompt": "sci-loop resume"}
        assert "resumed" in hook(adapter, "user-prompt-submit", resume_event, environment)["systemMessage"]
        blocked = hook(adapter, "stop", stop_event, environment)
        assert blocked["decision"] == "block" and REVIEWER in blocked["reason"]
        assert json.loads((run_dir / "request-envelope.json").read_text(encoding="utf-8")) == envelope

        repeated = dict(stop_event)
        repeated["stop_hook_active"] = True
        stopped = hook(adapter, "stop", repeated, environment)
        assert stopped["continue"] is False and "denied" in stopped["systemMessage"].lower()
        assert "resumed" in hook(adapter, "user-prompt-submit", resume_event, environment)["systemMessage"]
        assert hook(adapter, "stop", later_stop, environment)["continue"] is False

        request = json.loads(request_path.read_text(encoding="utf-8"))
        assert request["host_isolation_attested"] is False
        biased_pretool = {
            **common(project, "PreToolUse", "turn-003"),
            "tool_name": "Agent",
            "tool_use_id": "tool-001",
            "tool_input": {"task_name": REVIEWER, "message": "Trust my summary.", "fork_turns": "all"},
        }
        assert hook(adapter, "reviewer-pre-tool", biased_pretool, environment)["hookSpecificOutput"][
            "permissionDecision"
        ] == "deny"

        request["host_isolation_attested"] = True
        write_json(request_path, request, mode=0o600)
        exact_pretool = dict(biased_pretool)
        exact_pretool["tool_input"] = {
            "task_name": REVIEWER,
            "message": request["delegation_message"],
            "fork_turns": "none",
        }
        assert hook(adapter, "reviewer-pre-tool", exact_pretool, environment) == {}

        wrong_start = {
            **common(project, "SubagentStart", "turn-003"),
            "agent_id": "agent-unrelated",
            "agent_type": "explorer",
        }
        assert "systemMessage" in hook(adapter, "reviewer-start", wrong_start, environment)
        reviewer_start = dict(wrong_start)
        reviewer_start.update({"agent_id": "019-reviewer:001", "agent_type": REVIEWER})
        started = hook(adapter, "reviewer-start", reviewer_start, environment)
        assert started["hookSpecificOutput"]["hookEventName"] == "SubagentStart"
        assert "systemMessage" in hook(adapter, "reviewer-start", reviewer_start, environment)

        unrelated_stop = {
            **common(project, "SubagentStop", "turn-003"),
            "agent_id": "agent-unrelated",
            "agent_type": "explorer",
            "agent_transcript_path": None,
            "stop_hook_active": False,
            "last_assistant_message": None,
        }
        assert hook(adapter, "reviewer-stop", unrelated_stop, environment) == {}

        transcript = temporary / "reviewer-transcript.log"
        transcript.write_text("opaque native reviewer transcript\n", encoding="utf-8")
        reviewer_stop = dict(unrelated_stop)
        reviewer_stop.update(
            {
                "agent_id": "019-reviewer:001",
                "agent_type": REVIEWER,
                "agent_transcript_path": str(transcript),
                "last_assistant_message": "review looks good",
            }
        )
        invalid = hook(adapter, "reviewer-stop", reviewer_stop, environment)
        assert invalid["decision"] == "block"
        valid_outcome = audit_outcome(snapshot, "019-reviewer:001")
        reviewer_stop["last_assistant_message"] = json.dumps(valid_outcome, ensure_ascii=False)
        wrong_identity = dict(valid_outcome)
        wrong_identity["reviewer_thread_id"] = "different-reviewer"
        reviewer_stop["last_assistant_message"] = json.dumps(wrong_identity, ensure_ascii=False)
        assert hook(adapter, "reviewer-stop", reviewer_stop, environment)["decision"] == "block"
        reviewer_stop["last_assistant_message"] = json.dumps(valid_outcome, ensure_ascii=False)
        completed = hook(adapter, "reviewer-stop", reviewer_stop, environment)
        assert completed == {"continue": True}
        candidate = plugin_data / "sessions" / session_key / "review-candidate" / "candidate.json"
        assert json.loads(candidate.read_text(encoding="utf-8"))["host_signature_pending"] is True
        assert not (candidate.parent / "audit-receipt.json").exists()

        promote_candidate(plugin, plugin_data, trusted, private_key, snapshot)
        assert hook(adapter, "user-prompt-submit", {**pause_event, "turn_id": "turn-final-pause"}, environment)[
            "decision"
        ] == "block"
        assert hook(adapter, "stop", stop_event, environment)["continue"] is False
        assert "resumed" in hook(adapter, "user-prompt-submit", {**resume_event, "turn_id": "turn-final-resume"}, environment)[
            "systemMessage"
        ]
        final = hook(adapter, "stop", stop_event, environment)
        assert final == {"continue": True}
        assert hook(adapter, "stop", stop_event, environment) == {"continue": True}
        fixture.write_text("changed after acceptance\n", encoding="utf-8")
        no_longer_current = hook(adapter, "stop", stop_event, environment)
        assert no_longer_current["continue"] is False and "historical" in no_longer_current["systemMessage"]
        fixture.write_text("candidate\n", encoding="utf-8")
        resumed = json.loads(
            run("python3", str(core), "resume", "--project-root", str(project), "--json").stdout
        )
        assert resumed["decision"] == "READY_FOR_NEXT_PHASE" and resumed["status"] == "accepted"

        pending_root = plugin_data / "pending-requests"
        before_pending = sorted(pending_root.glob("*.json")) if pending_root.exists() else []
        non_goal_environment = dict(environment)
        non_goal_environment.pop("LUMIFORGE_SCI_LOOP_MODE")
        ordinary_prompt = {
            **common(project, "UserPromptSubmit", "turn-ordinary"),
            "prompt": "ordinary non-goal prompt must not be retained",
        }
        assert hook(adapter, "user-prompt-submit", ordinary_prompt, non_goal_environment) == {}
        after_pending = sorted(pending_root.glob("*.json")) if pending_root.exists() else []
        assert after_pending == before_pending

        goal_prompt = {**common(project, "UserPromptSubmit", "turn-next-goal"), "prompt": "next exact goal request"}
        goal_missing_environment = dict(environment)
        for name in (
            "LUMIFORGE_SCI_LOOP_PROBE",
            "LUMIFORGE_SCI_LOOP_CERTIFICATE_ROOT",
            "LUMIFORGE_SCI_LOOP_TRUSTED_ROOT",
        ):
            goal_missing_environment.pop(name)
        goal_session = {**common(project, "SessionStart"), "source": "resume"}
        assert hook(adapter, "session-start", goal_session, goal_missing_environment)["continue"] is False
        assert hook(adapter, "session-start", goal_session, environment) == {"continue": True}
        pending_before_denied = sorted(pending_root.glob("*.json")) if pending_root.exists() else []
        assert hook(adapter, "user-prompt-submit", goal_prompt, goal_missing_environment)["decision"] == "block"
        assert sorted(pending_root.glob("*.json")) == pending_before_denied
        assert hook(adapter, "user-prompt-submit", goal_prompt, environment) == {}
        pending_files = sorted(pending_root.glob("*.json"))
        assert len(pending_files) == len(before_pending) + 1
        pending = json.loads(pending_files[-1].read_text(encoding="utf-8"))
        assert pending["schema"] == "sci-loop-pending-request-v1"
        assert pending["envelope"]["original_request"] == "next exact goal request"

        malformed = dict(stop_event)
        malformed["unexpected"] = True
        failed_closed = hook(adapter, "stop", malformed, environment)
        assert failed_closed["continue"] is False

        pending_project = temporary / "pending-project"
        pending_project.mkdir()
        run("git", "init", "-q", cwd=pending_project)
        pending_prompt = {**common(pending_project, "UserPromptSubmit", "turn-pending"), "prompt": "first request"}
        assert hook(adapter, "user-prompt-submit", pending_prompt, environment) == {}
        assert not (pending_project / ".ai-loop").exists()
        assert hook(adapter, "stop", {**stop_event, "cwd": str(pending_project)}, environment)["continue"] is False
        assert hook(adapter, "stop", {**stop_event, "cwd": str(temporary)}, environment)["continue"] is False

        next_phase = "hook-followup"
        run(
            "python3", str(core), "start", "--project-root", str(project), "--phase-id", next_phase,
            "--title", "Follow-up", "--objective", "Preserve the actual user request", "--verify-command", "true",
        )
        fresh_prompt = {**prompt_event, "turn_id": "turn-next-request", "prompt": "new managed request"}
        assert hook(adapter, "user-prompt-submit", fresh_prompt, environment) == {}
        first_stop = hook(adapter, "stop", {**stop_event, "turn_id": "turn-first-stop"}, environment)
        assert first_stop["decision"] == "block"
        same_text = {**prompt_event, "turn_id": "turn-same-text", "prompt": first_stop["reason"]}
        assert hook(adapter, "user-prompt-submit", same_text, environment) == {}
        updated_request = json.loads(
            (project / ".ai-loop" / "runs" / next_phase / "request-envelope.json").read_text(encoding="utf-8")
        )
        assert [item["text"] for item in updated_request["revisions"]] == [first_stop["reason"]]

    print(
        json.dumps(
            {
                "ok": True,
                "events": ["SessionStart", "UserPromptSubmit", "PreToolUse", "SubagentStart", "SubagentStop", "Stop"],
                "clean_room": True,
                "installed": False,
            },
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    main()

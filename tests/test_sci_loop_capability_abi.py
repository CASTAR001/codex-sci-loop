#!/usr/bin/env python3
"""Verify the stable sci-loop Capability ABI and fail-closed certification gate."""

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
GATE = PLUGIN / "scripts" / "capability_gate.py"
REQUIRED = PLUGIN / "capabilities" / "required.json"
ADAPTER = PLUGIN / "adapters" / "codex-0.147.json"
PROBE_SCHEMA = PLUGIN / "schemas" / "runtime-probe.schema.json"
CERTIFICATE_SCHEMA = PLUGIN / "schemas" / "runtime-certificate.schema.json"


def canonical_hash(value: Any) -> str:
    encoded = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def file_hash(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def plugin_tree_hash(plugin_root: Path = PLUGIN) -> str:
    digest = hashlib.sha256()
    for path in sorted(plugin_root.rglob("*"), key=lambda item: item.as_posix()):
        relative = path.relative_to(plugin_root)
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


def write_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def run_gate(
    probe: Path,
    certificates: Path,
    expected_exit: int,
    plugin_root: Path = PLUGIN,
) -> dict[str, Any]:
    result = subprocess.run(
        [
            "python3",
            str(GATE),
            "--probe",
            str(probe),
            "--certificate-root",
            str(certificates),
            "--plugin-root",
            str(plugin_root),
        ],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
        timeout=30,
        env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"},
    )
    assert result.returncode == expected_exit, result.stdout
    return json.loads(result.stdout)


def complete_probe(plugin_root: Path = PLUGIN) -> dict[str, Any]:
    contract = json.loads((plugin_root / "capabilities" / "required.json").read_text(encoding="utf-8"))
    adapter = json.loads((plugin_root / "adapters" / "codex-0.147.json").read_text(encoding="utf-8"))
    return {
        "schema": "sci-loop-runtime-probe-v1",
        "runtime": "codex",
        "runtime_version": "0.147.0",
        "plugin_version": "1.0.0",
        "adapter_id": adapter["adapter_id"],
        "plugin_tree_sha256": plugin_tree_hash(plugin_root),
        "runtime_artifact_sha256": "1" * 64,
        "behavior_evidence_sha256": "2" * 64,
        "capabilities": {name: int(constraint[2:]) for name, constraint in contract["required"].items()},
        "preconditions": {name: True for name in contract["required_preconditions"]},
        "observed_runtime_capabilities": sorted(
            ["hooks", "multi_agent", "plugin_default_hooks"] + list(adapter["event_contract"].values())[:4]
        ),
    }


def certificate(probe_path: Path, probe: dict[str, Any], plugin_root: Path = PLUGIN) -> dict[str, Any]:
    adapter_path = plugin_root / "adapters" / "codex-0.147.json"
    required_path = plugin_root / "capabilities" / "required.json"
    adapter = json.loads(adapter_path.read_text(encoding="utf-8"))
    return {
        "schema": "sci-loop-runtime-certificate-v1",
        "status": "CERTIFIED",
        "issued_by": "lumiforge-runtime-certifier-v1",
        "runtime": "codex",
        "runtime_version": probe["runtime_version"],
        "plugin_version": probe["plugin_version"],
        "adapter_id": probe["adapter_id"],
        "plugin_tree_sha256": probe["plugin_tree_sha256"],
        "runtime_artifact_sha256": probe["runtime_artifact_sha256"],
        "behavior_evidence_sha256": probe["behavior_evidence_sha256"],
        "required_contract_sha256": file_hash(required_path),
        "adapter_sha256": file_hash(adapter_path),
        "behavior_probe_sha256": file_hash(probe_path),
        "observed_runtime_capabilities_sha256": canonical_hash(sorted(probe["observed_runtime_capabilities"])),
    }


def assert_domain_is_adapter_neutral() -> None:
    domain = (PLUGIN / "scripts" / "sci_loop.py").read_text(encoding="utf-8")
    for runtime_name in ("UserPromptSubmit", "SubagentStart", "SubagentStop", "Stop"):
        assert runtime_name not in domain
    adapter_text = ADAPTER.read_text(encoding="utf-8")
    for runtime_name in ("UserPromptSubmit", "SubagentStart", "SubagentStop", "Stop"):
        assert runtime_name in adapter_text


def main() -> None:
    assert_domain_is_adapter_neutral()
    contract = json.loads(REQUIRED.read_text(encoding="utf-8"))
    assert contract["protocol"] == "sci-loop-capabilities/v1"
    assert set(contract["required"]) == {
        "request.capture",
        "evidence.snapshot",
        "reviewer.spawn",
        "reviewer.isolation",
        "reviewer.observe_completion",
        "audit.receipt",
        "completion.block",
        "runtime.bootstrap",
    }
    probe_schema = json.loads(PROBE_SCHEMA.read_text(encoding="utf-8"))
    certificate_schema = json.loads(CERTIFICATE_SCHEMA.read_text(encoding="utf-8"))

    with tempfile.TemporaryDirectory(prefix="lumiforge-capability-abi-") as raw:
        temporary = Path(raw)
        certificates = temporary / "certificates"
        certificates.mkdir()
        probe_path = temporary / "probe.json"

        unknown = complete_probe()
        unknown["runtime_version"] = "0.148.0"
        write_json(probe_path, unknown)
        jsonschema.validate(unknown, probe_schema)
        decision = run_gate(probe_path, certificates, 20)
        assert decision["state"] == "QUARANTINED_NEW_VERSION"

        probe = complete_probe()
        write_json(probe_path, probe)
        jsonschema.validate(probe, probe_schema)
        decision = run_gate(probe_path, certificates, 20)
        assert decision["reasons"] == ["behavior_certificate_missing"]

        malformed = complete_probe()
        malformed["unexpected"] = True
        write_json(probe_path, malformed)
        decision = run_gate(probe_path, certificates, 21)
        assert decision["state"] == "INCOMPATIBLE"
        assert decision["reasons"][0].startswith("invalid_gate_input:")

        missing = complete_probe()
        missing["capabilities"].pop("reviewer.isolation")
        write_json(probe_path, missing)
        decision = run_gate(probe_path, certificates, 21)
        assert decision["state"] == "INCOMPATIBLE"
        assert "missing_capability:reviewer.isolation" in decision["reasons"]

        unsafe = complete_probe()
        unsafe["preconditions"]["reviewer_read_only_isolation"] = False
        write_json(probe_path, unsafe)
        decision = run_gate(probe_path, certificates, 21)
        assert "failed_precondition:reviewer_read_only_isolation" in decision["reasons"]

        unsigned = complete_probe()
        unsigned["preconditions"]["receipt_authority_configured"] = False
        write_json(probe_path, unsigned)
        decision = run_gate(probe_path, certificates, 21)
        assert "failed_precondition:receipt_authority_configured" in decision["reasons"]

        probe = complete_probe()
        write_json(probe_path, probe)
        cert = certificate(probe_path, probe)
        jsonschema.validate(cert, certificate_schema)
        cert_path = certificates / "codex-0.147.0.json"
        write_json(cert_path, cert)
        decision = run_gate(probe_path, certificates, 0)
        assert decision["state"] == "CERTIFIED" and decision["ok"] is True

        changed_runtime = dict(probe)
        changed_runtime["runtime_artifact_sha256"] = "3" * 64
        write_json(probe_path, changed_runtime)
        decision = run_gate(probe_path, certificates, 22)
        assert decision["reasons"] == ["certificate_binding_stale_or_invalid"]

        changed_evidence = dict(probe)
        changed_evidence["behavior_evidence_sha256"] = "4" * 64
        write_json(probe_path, changed_evidence)
        decision = run_gate(probe_path, certificates, 22)
        assert decision["reasons"] == ["certificate_binding_stale_or_invalid"]

        write_json(probe_path, probe)
        rejected = dict(cert)
        rejected["status"] = "INCOMPATIBLE"
        write_json(cert_path, rejected)
        decision = run_gate(probe_path, certificates, 21)
        assert decision["state"] == "INCOMPATIBLE" and decision["ok"] is False

        stale = dict(cert)
        stale["plugin_version"] = "0.9.0"
        write_json(cert_path, stale)
        decision = run_gate(probe_path, certificates, 22)
        assert decision["state"] == "PLUGIN_UPDATE_REQUIRED"

        write_json(cert_path, cert)
        probe["observed_runtime_capabilities"].append("new_relevant_hook_behavior")
        write_json(probe_path, probe)
        decision = run_gate(probe_path, certificates, 22)
        assert decision["reasons"] == ["certificate_binding_stale_or_invalid"]

        plugin_copy = temporary / "plugin-copy"
        shutil.copytree(PLUGIN, plugin_copy)
        copied_probe = complete_probe(plugin_copy)
        write_json(probe_path, copied_probe)
        copied_cert = certificate(probe_path, copied_probe, plugin_copy)
        write_json(cert_path, copied_cert)
        decision = run_gate(probe_path, certificates, 0, plugin_copy)
        assert decision["state"] == "CERTIFIED"
        (plugin_copy / "distribution-change.txt").write_text("changed\n", encoding="utf-8")
        decision = run_gate(probe_path, certificates, 22, plugin_copy)
        assert decision["reasons"] == ["plugin_distribution_changed"]

    print(
        json.dumps(
            {
                "ok": True,
                "protocol": contract["protocol"],
                "adapter": "codex-hooks-0.147-v1",
                "states": sorted(["CERTIFIED", "INCOMPATIBLE", "PLUGIN_UPDATE_REQUIRED", "QUARANTINED_NEW_VERSION"]),
            },
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    main()

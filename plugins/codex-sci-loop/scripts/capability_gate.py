#!/usr/bin/env python3
"""Fail-closed runtime capability and behavior-certificate gate."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any


STATES = {
    "CERTIFIED": 0,
    "QUARANTINED_NEW_VERSION": 20,
    "INCOMPATIBLE": 21,
    "PLUGIN_UPDATE_REQUIRED": 22,
}
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
VERSION_RE = re.compile(r"^[0-9A-Za-z][0-9A-Za-z.+-]{0,63}$")


class GateError(RuntimeError):
    pass


def read_object(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise GateError(f"cannot read valid JSON from {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise GateError(f"JSON root must be an object: {path}")
    return value


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def sha256_json(value: Any) -> str:
    payload = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def sha256_plugin_tree(plugin_root: Path) -> str:
    """Hash the immutable plugin distribution without runtime cache files."""
    digest = hashlib.sha256()
    for path in sorted(plugin_root.rglob("*"), key=lambda item: item.as_posix()):
        relative = path.relative_to(plugin_root)
        if "__pycache__" in relative.parts or path.suffix == ".pyc" or path.name == ".DS_Store":
            continue
        if path.is_symlink():
            raise GateError(f"plugin distribution contains a symlink: {relative}")
        if not path.is_file():
            continue
        encoded = relative.as_posix().encode("utf-8")
        content = path.read_bytes()
        digest.update(len(encoded).to_bytes(8, "big"))
        digest.update(encoded)
        digest.update(len(content).to_bytes(8, "big"))
        digest.update(content)
    return digest.hexdigest()


def result(state: str, reasons: list[str], **identity: Any) -> tuple[dict[str, Any], int]:
    payload = {
        "schema": "sci-loop-capability-decision-v1",
        "ok": state == "CERTIFIED",
        "state": state,
        "reasons": reasons,
        **identity,
    }
    return payload, STATES[state]


def minimum_version(value: Any, capability: str) -> int:
    if not isinstance(value, str) or re.fullmatch(r">=([1-9][0-9]*)", value) is None:
        raise GateError(f"invalid requirement for {capability}")
    return int(value[2:])


def validate_probe(probe: dict[str, Any]) -> None:
    required = {
        "schema",
        "runtime",
        "runtime_version",
        "plugin_version",
        "adapter_id",
        "plugin_tree_sha256",
        "runtime_artifact_sha256",
        "behavior_evidence_sha256",
        "capabilities",
        "preconditions",
        "observed_runtime_capabilities",
    }
    if set(probe) != required:
        raise GateError("runtime probe fields do not match the v1 schema")
    if probe.get("schema") != "sci-loop-runtime-probe-v1" or probe.get("runtime") != "codex":
        raise GateError("runtime probe identity is invalid")
    if not isinstance(probe.get("runtime_version"), str) or not VERSION_RE.fullmatch(probe["runtime_version"]):
        raise GateError("runtime probe version is invalid")
    if not isinstance(probe.get("plugin_version"), str) or not probe["plugin_version"]:
        raise GateError("runtime probe plugin version is invalid")
    if not isinstance(probe.get("adapter_id"), str) or not probe["adapter_id"]:
        raise GateError("runtime probe adapter id is invalid")
    for field in ("plugin_tree_sha256", "runtime_artifact_sha256", "behavior_evidence_sha256"):
        if not isinstance(probe.get(field), str) or not SHA256_RE.fullmatch(probe[field]):
            raise GateError(f"runtime probe {field} is invalid")
    capabilities = probe.get("capabilities")
    preconditions = probe.get("preconditions")
    observed = probe.get("observed_runtime_capabilities")
    if not isinstance(capabilities, dict) or any(
        isinstance(value, bool) or not isinstance(value, int) or value < 0 for value in capabilities.values()
    ):
        raise GateError("runtime probe capabilities must be nonnegative integer versions")
    if not isinstance(preconditions, dict) or any(not isinstance(value, bool) for value in preconditions.values()):
        raise GateError("runtime probe preconditions must be booleans")
    if not isinstance(observed, list) or any(not isinstance(value, str) or not value for value in observed):
        raise GateError("observed runtime capabilities must be non-empty strings")
    if len(set(observed)) != len(observed):
        raise GateError("observed runtime capabilities must be unique")


def decide(plugin_root: Path, probe_path: Path, certificate_root: Path) -> tuple[dict[str, Any], int]:
    required_path = plugin_root / "capabilities" / "required.json"
    adapter_path = plugin_root / "adapters" / "codex-0.147.json"
    manifest_path = plugin_root / ".codex-plugin" / "plugin.json"
    policy_path = plugin_root / "certifications" / "policy.json"
    required = read_object(required_path)
    adapter = read_object(adapter_path)
    manifest = read_object(manifest_path)
    policy = read_object(policy_path)
    probe = read_object(probe_path)
    validate_probe(probe)

    identity = {
        "runtime": probe["runtime"],
        "runtime_version": probe["runtime_version"],
        "plugin_version": probe["plugin_version"],
        "adapter_id": probe["adapter_id"],
    }
    supported = adapter.get("supported_versions")
    targets = policy.get("target_versions")
    if not isinstance(supported, list) or not isinstance(targets, list):
        raise GateError("adapter or certification policy versions are invalid")
    if probe["runtime_version"] not in supported or probe["runtime_version"] not in targets:
        return result("QUARANTINED_NEW_VERSION", ["runtime_version_not_certifiable"], **identity)

    if probe["plugin_version"] != manifest.get("version") or probe["adapter_id"] != adapter.get("adapter_id"):
        return result("PLUGIN_UPDATE_REQUIRED", ["runtime_plugin_or_adapter_identity_changed"], **identity)
    plugin_tree_sha256 = sha256_plugin_tree(plugin_root)
    if probe["plugin_tree_sha256"] != plugin_tree_sha256:
        return result("PLUGIN_UPDATE_REQUIRED", ["plugin_distribution_changed"], **identity)
    if required.get("protocol") != adapter.get("capability_protocol"):
        return result("PLUGIN_UPDATE_REQUIRED", ["capability_protocol_changed"], **identity)

    missing: list[str] = []
    required_capabilities = required.get("required")
    if not isinstance(required_capabilities, dict):
        raise GateError("required capabilities are invalid")
    for name, constraint in required_capabilities.items():
        minimum = minimum_version(constraint, name)
        actual = probe["capabilities"].get(name)
        if isinstance(actual, bool) or not isinstance(actual, int) or actual < minimum:
            missing.append(name)
    failed_preconditions: list[str] = []
    preconditions = required.get("required_preconditions")
    if not isinstance(preconditions, list) or any(not isinstance(name, str) for name in preconditions):
        raise GateError("required preconditions are invalid")
    for name in preconditions:
        if probe["preconditions"].get(name) is not True:
            failed_preconditions.append(name)
    if missing or failed_preconditions:
        reasons = [f"missing_capability:{name}" for name in sorted(missing)]
        reasons.extend(f"failed_precondition:{name}" for name in sorted(failed_preconditions))
        return result("INCOMPATIBLE", reasons, **identity)

    certificate_name = f"codex-{probe['runtime_version']}.json"
    certificate_path = (certificate_root / certificate_name).resolve()
    try:
        certificate_path.relative_to(certificate_root.resolve())
    except ValueError as exc:
        raise GateError("certificate path escapes its root") from exc
    if not certificate_path.is_file():
        return result("QUARANTINED_NEW_VERSION", ["behavior_certificate_missing"], **identity)
    certificate = read_object(certificate_path)
    status = certificate.get("status")
    if status not in STATES:
        return result("PLUGIN_UPDATE_REQUIRED", ["certificate_status_unknown"], **identity)
    if status != "CERTIFIED":
        return result(status, ["certificate_is_not_certified"], **identity)

    expected = {
        "schema": "sci-loop-runtime-certificate-v1",
        "status": "CERTIFIED",
        "issued_by": "lumiforge-runtime-certifier-v1",
        "runtime": probe["runtime"],
        "runtime_version": probe["runtime_version"],
        "plugin_version": manifest.get("version"),
        "adapter_id": adapter.get("adapter_id"),
        "plugin_tree_sha256": plugin_tree_sha256,
        "runtime_artifact_sha256": probe["runtime_artifact_sha256"],
        "behavior_evidence_sha256": probe["behavior_evidence_sha256"],
        "required_contract_sha256": sha256_file(required_path),
        "adapter_sha256": sha256_file(adapter_path),
        "behavior_probe_sha256": sha256_file(probe_path),
        "observed_runtime_capabilities_sha256": sha256_json(sorted(probe["observed_runtime_capabilities"])),
    }
    if set(certificate) != set(expected):
        return result("PLUGIN_UPDATE_REQUIRED", ["certificate_fields_changed"], **identity)
    invalid_hash = any(
        key.endswith("_sha256") and (not isinstance(value, str) or not SHA256_RE.fullmatch(value))
        for key, value in certificate.items()
    )
    if invalid_hash or certificate != expected:
        return result("PLUGIN_UPDATE_REQUIRED", ["certificate_binding_stale_or_invalid"], **identity)
    return result("CERTIFIED", [], **identity)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe", required=True)
    parser.add_argument("--certificate-root", required=True)
    parser.add_argument("--plugin-root", default=str(Path(__file__).resolve().parents[1]))
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        payload, exit_code = decide(
            Path(args.plugin_root).expanduser().resolve(),
            Path(args.probe).expanduser().resolve(),
            Path(args.certificate_root).expanduser().resolve(),
        )
    except GateError as exc:
        payload, exit_code = result("INCOMPATIBLE", [f"invalid_gate_input:{exc}"])
    print(json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":")))
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())

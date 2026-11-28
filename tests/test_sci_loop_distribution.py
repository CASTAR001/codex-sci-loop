#!/usr/bin/env python3
"""Validate the clean, portable codex-sci-loop distribution."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import queue
import re
import shutil
import subprocess
import sys
import tempfile
import threading
from functools import partial
from pathlib import Path
from typing import Callable


ROOT = Path(__file__).resolve().parents[1]
NAME = "codex-sci-loop"
VERSION = "1.4.0-alpha.1"
MARKETPLACE = "codex-sci-loop-local"
PLUGIN = ROOT / "plugins" / NAME
MANIFEST = Path(".codex-plugin") / "plugin.json"
MARKETPLACE_MANIFEST = ROOT / ".agents" / "plugins" / "marketplace.json"
CORE = PLUGIN / "scripts" / "sci_loop.py"
HOOK_MANIFEST = Path("hooks") / "hooks.json"
EXPECTED_SKILLS = {"task-checkpoint", "research-verification"}
PROHIBITED_RUNTIME_PATTERNS = (
    r"claude[-_ ]?mimo",
    r"external[-_ ]?worker",
    r"worker[-_ ]?profiles?",
    r"worker[-_ ]?preflight",
    r"invoke[-_ ]?worker",
    r"require[-_ ]?external[-_ ]?worker[-_ ]?evidence",
    r"worker[-_ ]?profile",
)
RunCommand = Callable[..., subprocess.CompletedProcess[str]]


def isolated_environment(root: Path) -> dict[str, str]:
    home, codex_home, temp = (root / name for name in ("home", "codex", "tmp"))
    for path in (home, codex_home, temp):
        path.mkdir()
    env = {
        key: os.environ[key]
        for key in ("PATH", "SYSTEMROOT", "WINDIR", "COMSPEC", "PATHEXT")
        if key in os.environ
    }
    return {
        **env,
        "HOME": str(home),
        "USERPROFILE": str(home),
        "APPDATA": str(home),
        "LOCALAPPDATA": str(home),
        "XDG_CONFIG_HOME": str(home),
        "XDG_CACHE_HOME": str(home),
        "XDG_DATA_HOME": str(home),
        "XDG_STATE_HOME": str(home),
        "CODEX_HOME": str(codex_home),
        "TMPDIR": str(temp),
        "TMP": str(temp),
        "TEMP": str(temp),
        "GIT_CONFIG_GLOBAL": os.devnull,
        "GIT_CONFIG_NOSYSTEM": "1",
        "PYTHONDONTWRITEBYTECODE": "1",
    }


def run_command(
    *command: str, cwd: Path, env: dict[str, str], expect: int = 0
) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        command,
        cwd=cwd,
        text=True,
        capture_output=True,
        check=False,
        timeout=120,
        env=env,
    )
    if result.returncode != expect:
        raise AssertionError(
            f"command returned {result.returncode}, expected {expect}: {' '.join(command)}\n"
            f"{result.stdout}{result.stderr}"
        )
    return result


def assert_structure() -> None:
    manifest = json.loads((PLUGIN / MANIFEST).read_text(encoding="utf-8"))
    assert manifest["name"] == manifest["id"] == NAME
    assert manifest["version"] == VERSION
    assert manifest["skills"] == "./skills/"
    assert "hooks" not in manifest and not (PLUGIN / HOOK_MANIFEST).exists()
    assert manifest["description"].strip()
    assert manifest["author"]["name"].strip()
    interface = manifest["interface"]
    for field in ("displayName", "shortDescription", "longDescription", "developerName", "category"):
        assert interface[field].strip(), f"empty plugin interface field: {field}"

    marketplace = json.loads(MARKETPLACE_MANIFEST.read_text(encoding="utf-8"))
    assert marketplace["name"] == MARKETPLACE
    assert marketplace["interface"]["displayName"].strip()
    entry, = marketplace["plugins"]
    assert entry["name"] == NAME
    assert entry["source"] == {"source": "local", "path": f"./plugins/{NAME}"}
    assert (ROOT / entry["source"]["path"]).resolve() == PLUGIN
    assert entry["policy"] == {"installation": "AVAILABLE", "authentication": "ON_INSTALL"}
    assert entry["category"] == interface["category"]

    skills = {path.name for path in (PLUGIN / "skills").iterdir() if path.is_dir()}
    assert skills == EXPECTED_SKILLS
    for name in sorted(EXPECTED_SKILLS):
        skill_path = PLUGIN / "skills" / name / "SKILL.md"
        skill_text = skill_path.read_text(encoding="utf-8")
        opening, _, remainder = skill_text.partition("\n")
        frontmatter, closing, body = remainder.partition("\n---\n")
        assert opening == "---" and closing and body.strip(), skill_path
        assert re.findall(r"^name:[ \t]*(.*)$", frontmatter, re.MULTILINE) == [name], skill_path
        descriptions = re.findall(r"^description:[ \t]*(.*)$", frontmatter, re.MULTILINE)
        assert len(descriptions) == 1, skill_path
        description = descriptions[0].strip()
        if description.startswith('"'):
            description = json.loads(description)
        assert description.strip() and len(description) <= 1024, skill_path

    assert {path.name for path in PLUGIN.iterdir() if path.is_dir()} == {".codex-plugin", "scripts", "skills"}
    assert {path.name for path in CORE.parent.iterdir()} == {"checkpoint.py", "exchange.py", "loop_io.py", "sci_loop.py"}
    cache_artifacts = [
        path.relative_to(PLUGIN).as_posix()
        for path in PLUGIN.rglob("*")
        if "__pycache__" in path.parts or path.suffix == ".pyc"
    ]
    assert not cache_artifacts, "distribution contains Python cache artifacts:\n" + "\n".join(cache_artifacts)


def assert_runtime_has_no_removed_routes() -> None:
    matches: list[str] = []
    compiled = [re.compile(pattern, re.IGNORECASE) for pattern in PROHIBITED_RUNTIME_PATTERNS]
    for path in sorted(PLUGIN.rglob("*")):
        if not path.is_file() or "__pycache__" in path.parts or path.suffix == ".pyc":
            continue
        text = path.read_text(encoding="utf-8")
        for pattern in compiled:
            if pattern.search(text):
                matches.append(f"{path.relative_to(ROOT)}:{pattern.pattern}")
    assert not matches, "removed runtime routes remain:\n" + "\n".join(matches)


def assert_core_distribution(run: RunCommand, core: Path) -> None:
    assert run(sys.executable, str(core), "--version").stdout.strip() == VERSION
    assert "DISTRIBUTION: OK" in run(sys.executable, str(core), "validate-distribution").stdout


def assert_codex_install(run: RunCommand, cwd: Path, env: dict[str, str]) -> None:
    codex = shutil.which("codex")
    assert codex is not None, "--codex-install requires the Codex CLI on PATH"
    plugin_id = f"{NAME}@{MARKETPLACE}"
    market = json.loads(run(codex, "plugin", "marketplace", "add", str(ROOT), "--json").stdout)
    assert market["marketplaceName"] == MARKETPLACE
    assert Path(market["installedRoot"]).resolve() == ROOT
    installed = json.loads(run(codex, "plugin", "add", plugin_id, "--json").stdout)
    assert installed["pluginId"] == plugin_id
    assert installed["version"] == VERSION
    bundle = Path(installed["installedPath"]).resolve()
    assert bundle.is_relative_to(Path(env["CODEX_HOME"]) / "plugins" / "cache")
    assert (bundle / MANIFEST).read_bytes() == (PLUGIN / MANIFEST).read_bytes()
    assert not (bundle / HOOK_MANIFEST).exists()
    assert_core_distribution(run, bundle / CORE.relative_to(PLUGIN))
    run(sys.executable, str(bundle / "scripts" / "checkpoint.py"), "--help")
    assert_codex_discovery(codex, cwd, env, plugin_id, bundle)

def assert_codex_discovery(codex: str, cwd: Path, env: dict[str, str], plugin_id: str, bundle: Path) -> None:
    with subprocess.Popen(
        [codex, "app-server", "--stdio"], cwd=cwd, env=env,
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, encoding="utf-8",
    ) as server:
        assert server.stdin is not None and server.stdout is not None
        messages = queue.Queue()

        def read_messages() -> None:
            for line in server.stdout:
                messages.put(line)
            messages.put(None)

        reader = threading.Thread(target=read_messages, daemon=True)
        reader.start()
        requests = (
            {"id": 1, "method": "initialize", "params": {"clientInfo": {"name": NAME, "version": VERSION}}},
            {"method": "initialized"},
            {"id": 2, "method": "skills/list", "params": {"cwds": [str(cwd)]}},
            {"id": 3, "method": "plugin/read", "params": {
                "marketplacePath": str(MARKETPLACE_MANIFEST), "pluginName": NAME,
            }},
        )
        results = {}
        try:
            for request in requests:
                server.stdin.write(json.dumps(request) + "\n")
                server.stdin.flush()
                if "id" not in request:
                    continue
                while True:
                    line = messages.get(timeout=15)
                    assert line is not None, f"Codex closed stdio before replying to {request['method']}"
                    reply = json.loads(line)
                    if reply.get("id") == request["id"]:
                        assert "result" in reply, reply
                        results[request["method"]] = reply["result"]
                        break
        finally:
            server.stdin.close()
            try:
                server.wait(timeout=5)
            except subprocess.TimeoutExpired:
                server.kill()
            reader.join(timeout=5)
    result, = results["skills/list"]["data"]
    assert not result["errors"], result["errors"]
    discovered = {
        skill["name"]: Path(skill["path"]).resolve()
        for skill in result["skills"] if skill.get("pluginId") == plugin_id and skill["enabled"]
    }
    assert discovered == {
        f"{NAME}:{name}": bundle / "skills" / name / "SKILL.md" for name in EXPECTED_SKILLS
    }, discovered
    plugin = results["plugin/read"]["plugin"]
    assert plugin["summary"]["id"] == plugin_id
    assert plugin["summary"]["installed"] and plugin["summary"]["enabled"]
    assert plugin["hooks"] == [], plugin["hooks"]


def commit_fixture(run: RunCommand, project: Path, name: str, contents: str) -> None:
    run("git", "init", "-q", cwd=project)
    (project / name).write_text(contents, encoding="utf-8")
    run("git", "add", name, cwd=project)
    run(
        "git", "-c", "user.name=Sci Loop Fixture", "-c", "user.email=fixture@example.invalid",
        "commit", "-qm", "fixture", cwd=project,
    )


def assert_read_only_phase_recovery(run: RunCommand) -> None:
    with tempfile.TemporaryDirectory(prefix="sci-loop-legacy-phase-") as raw:
        project = Path(raw).resolve()
        commit_fixture(run, project, "fixture.txt", "baseline\n")
        nested = project / "nested"
        nested.mkdir()
        commit_fixture(run, nested, "nested.txt", "nested baseline\n")
        heads = {key: run("git", "rev-parse", "HEAD", cwd=repo).stdout.strip()
                 for key, repo in ((".", project), ("nested", nested))}
        base = project / ".ai-loop"
        phase_id = "fixture-phase"
        phase_dir = base / "runs" / phase_id
        phase_dir.mkdir(parents=True)

        def write(relative: str, contents: str) -> None:
            target = base / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(contents, encoding="utf-8")

        def snapshot() -> dict[Path, bytes]:
            return {path.relative_to(base): path.read_bytes() for path in base.rglob("*") if path.is_file()}

        # Fields and control files written by the legacy Python 2.0 schema.
        write("loop.config.json", json.dumps({
            "schema_version": "2.0", "runtime_mode": "native-codex-loop", "executor": "codex",
            "evidence_repositories": [".", "nested"],
        }))
        for relative in ("README.md", "memory/activeContext.md", "memory/constraint-ledger.md",
                         "gates/pre-action-check.md", "prompts/codex-loop.prompt.md"):
            write(relative, "# Preserved legacy control file\n")
        phase = {
            "phase_id": phase_id, "title": "Fixture phase", "objective": "Preserve legacy evidence.",
            "verify_command": "exit 7", "status": "audit_prepared",
            "base_commit": heads["."], "repository_heads": heads, "run_dir": f".ai-loop/runs/{phase_id}",
            "started_at": "2026-11-24T01:00:00Z", "evidence_collected_at": "2026-11-24T02:00:00Z",
            "audit_prepared_at": "2026-11-24T03:00:00Z", "decided_at": None, "verify_exit_code": 7,
        }
        write(f"runs/{phase_id}/phase.json", json.dumps(phase))
        write(f"runs/{phase_id}/verify.log", "[sci-loop] verify_exit_code=7\n")
        write(f"runs/{phase_id}/prompt.md", "# Fixture phase\n\nPreserve legacy evidence.\n")

        def write_status(current: dict | None, decision: str | None = None) -> None:
            write("status.json", json.dumps({
                "schema_version": "2.0", "current_phase": current, "phases": [current] if current else [],
                "last_decision": decision,
            }))

        args = ("--project-root", str(project))
        for state, expected in (("started", "CONTINUE_ACTIVE_PHASE"), ("collecting", "CONTINUE_ACTIVE_PHASE"),
                                ("evidence_collected", "CONTINUE_ACTIVE_PHASE"), ("audit_prepared", "CONTINUE_ACTIVE_PHASE"),
                                ("blocked", "BLOCKED"), ("rework", "REWORK_REQUIRED"),
                                ("accepted", "READY_FOR_NEXT_PHASE"), ("none", "READY_FOR_NEXT_PHASE")):
            record = None if state == "none" else {**phase, "status": state}
            if state == "accepted":
                record.update(decided_at="2026-11-24T04:00:00Z", verify_exit_code=0, audit_snapshot_sha256="a" * 64)
            write_status(record, state.upper() if state in {"accepted", "blocked", "rework"} else None)
            before = snapshot()
            assert "VALIDATE: OK" in run(sys.executable, str(CORE), "validate", *args).stdout
            result = json.loads(run(sys.executable, str(CORE), "resume", *args, "--json").stdout)
            assert result["decision"] == expected and result["status"] == state
            assert result["phase_id"] == ("" if state == "none" else phase_id)
            assert result["read_only"] is True
            if state == "accepted":
                assert result["acceptance_scope"] == "recorded historical decision only"
                assert result["audit_snapshot_sha256"] == "a" * 64
            assert snapshot() == before

        write_status(phase)
        before = snapshot()
        for action in ("start", "init", "collect", "audit-pack", "decide"):
            run(sys.executable, str(CORE), action, *args, expect=2)
        assert snapshot() == before
        assert not (base / ".lock").exists()
        write("status.json", json.dumps({"schema_version": "2.0", "current_phase": phase, "phases": []}))
        assert "phase history" in run(sys.executable, str(CORE), "resume", *args, expect=1).stderr


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--codex-install", action="store_true", help="also install into a temporary Codex home")
    args = parser.parse_args()
    assert_structure()
    assert_runtime_has_no_removed_routes()
    with tempfile.TemporaryDirectory(prefix="sci-loop-distribution-") as raw:
        root = Path(raw).resolve()
        env = isolated_environment(root)
        run = partial(run_command, cwd=root, env=env)
        assert_core_distribution(run, CORE)
        assert_read_only_phase_recovery(run)
        assert not list(Path(env["CODEX_HOME"]).iterdir())
        assert not (Path(env["HOME"]) / ".codex").exists()
        if args.codex_install:
            assert_codex_install(run, root, env)
    print(json.dumps({
        "ok": True, "plugin": NAME, "version": VERSION,
        "core_sha256": hashlib.sha256(CORE.read_bytes()).hexdigest(),
        "codex_install": "passed" if args.codex_install else "not_requested",
    }))


if __name__ == "__main__":
    main()

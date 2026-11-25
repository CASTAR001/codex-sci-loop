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
VERSION = "1.1.0"
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

    assert CORE.is_file()
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
        "git", "-c", "user.name=LumiForge Test", "-c", "user.email=fixture@example.invalid",
        "commit", "-qm", "fixture", cwd=project,
    )


def assert_native_lifecycle(run: RunCommand) -> None:
    with tempfile.TemporaryDirectory(prefix="lumiforge-sci-loop-") as raw:
        project = Path(raw).resolve()
        commit_fixture(run, project, "fixture.txt", "baseline\n")
        nested = project / "nested"
        nested.mkdir()
        commit_fixture(run, nested, "nested.txt", "nested baseline\n")
        run(sys.executable, str(CORE), "init", "--project-root", str(project))
        assert "refusing to overwrite" in run(
            sys.executable, str(CORE), "init", "--project-root", str(project), expect=1
        ).stderr
        config_path = project / ".ai-loop" / "loop.config.json"
        config = json.loads(config_path.read_text(encoding="utf-8"))
        config["evidence_repositories"] = [".", "nested"]
        config_path.write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")
        run(sys.executable, str(CORE), "validate", "--project-root", str(project))
        run(
            sys.executable,
            str(CORE),
            "start",
            "--project-root",
            str(project),
            "--phase-id",
            "fixture-phase",
            "--title",
            "Fixture phase",
            "--objective",
            "Exercise the native evidence lifecycle.",
            "--verify-command",
            "printf '%s\\n' 'fixture verification: OK'",
        )
        run_dir = project / ".ai-loop" / "runs" / "fixture-phase"
        (project / "fixture.txt").write_text("changed\n", encoding="utf-8")
        (project / "new-evidence.txt").write_text("new\n", encoding="utf-8")
        (nested / "nested.txt").write_text("nested changed\n", encoding="utf-8")
        (nested / "nested-new.txt").write_text("nested new\n", encoding="utf-8")
        (run_dir / "report.md").write_text("# Execution report\n\nFixture completed.\n", encoding="utf-8")
        run(sys.executable, str(CORE), "collect", "--project-root", str(project), "--phase-id", "fixture-phase")
        run(sys.executable, str(CORE), "audit-pack", "--project-root", str(project), "--phase-id", "fixture-phase")
        audit = project / ".ai-loop" / "audits" / "fixture-phase-audit.md"
        audit.write_text("# Audit\n\nDecision: ACCEPTED\n\nEvidence inspected.\n", encoding="utf-8")
        assert "host-authorized" in run(
            sys.executable,
            str(CORE),
            "decide",
            "--project-root",
            str(project),
            "--phase-id",
            "fixture-phase",
            "--decision",
            "accepted",
            expect=1,
        ).stderr
        audit.write_text("# Audit\n\nDecision: REWORK\n\nEvidence inspected.\n", encoding="utf-8")
        run(
            sys.executable,
            str(CORE),
            "decide",
            "--project-root",
            str(project),
            "--phase-id",
            "fixture-phase",
            "--decision",
            "rework",
        )
        resumed = json.loads(
            run(sys.executable, str(CORE), "resume", "--project-root", str(project), "--json").stdout
        )
        assert resumed["decision"] == "REWORK_REQUIRED"
        verify_log = (run_dir / "verify.log").read_text(encoding="utf-8")
        assert "fixture verification: OK" in verify_log
        assert "verify_exit_code=0" in verify_log
        diff = (run_dir / "diff.patch").read_text(encoding="utf-8")
        assert "diff --git a/fixture.txt b/fixture.txt" in diff
        assert "new-evidence.txt" in diff
        assert "diff --git a/nested/nested.txt b/nested/nested.txt" in diff
        assert "nested/nested-new.txt" in diff
        assert ".ai-loop/status.json" not in diff
        heads = json.loads((run_dir / "repository_heads.json").read_text(encoding="utf-8"))
        assert set(heads) == {".", "nested"}
        journal = project / ".ai-loop" / "events" / "state-transitions.ndjson"
        assert journal.is_file()
        if os.name != "nt":
            assert journal.stat().st_mode & 0o777 == 0o600


def assert_failed_verification_cannot_use_prose_acceptance(run: RunCommand) -> None:
    with tempfile.TemporaryDirectory(prefix="lumiforge-sci-loop-failed-") as raw:
        project = Path(raw).resolve()
        commit_fixture(run, project, "fixture.txt", "baseline\n")
        run(sys.executable, str(CORE), "init", "--project-root", str(project))
        run(
            sys.executable,
            str(CORE),
            "start",
            "--project-root",
            str(project),
            "--phase-id",
            "failed-phase",
            "--title",
            "Failed fixture phase",
            "--objective",
            "Prove that failed verification cannot be accepted.",
            "--verify-command",
            "exit 7",
        )
        failed_run = project / ".ai-loop" / "runs" / "failed-phase"
        (failed_run / "report.md").write_text("# Execution report\n\nVerification is expected to fail.\n", encoding="utf-8")
        run(sys.executable, str(CORE), "collect", "--project-root", str(project), "--phase-id", "failed-phase")
        run(sys.executable, str(CORE), "audit-pack", "--project-root", str(project), "--phase-id", "failed-phase")
        failed_audit = project / ".ai-loop" / "audits" / "failed-phase-audit.md"
        failed_audit.write_text("# Audit\n\nDecision: ACCEPTED\n", encoding="utf-8")
        assert "host-authorized" in run(
            sys.executable,
            str(CORE),
            "decide",
            "--project-root",
            str(project),
            "--phase-id",
            "failed-phase",
            "--decision",
            "accepted",
            expect=1,
        ).stderr
        assert "verify_exit_code=7" in (failed_run / "verify.log").read_text(encoding="utf-8")


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
        assert_native_lifecycle(run)
        assert_failed_verification_cannot_use_prose_acceptance(run)
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

#!/usr/bin/env python3
"""Validate the clean, portable codex-sci-loop distribution."""

from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PLUGIN = ROOT / "plugins" / "codex-sci-loop"
CORE = PLUGIN / "scripts" / "sci_loop.py"
SYSTEM_SKILLS = Path.home() / ".codex" / "skills" / ".system"
PLUGIN_VALIDATOR = SYSTEM_SKILLS / "plugin-creator" / "scripts" / "validate_plugin.py"
SKILL_VALIDATOR = SYSTEM_SKILLS / "skill-creator" / "scripts" / "quick_validate.py"
EXPECTED_SKILLS = {
    "independent-completion-auditor",
    "loop-goal-bootstrap",
    "loop-supervisor",
    "loop-auditor",
    "loop-recovery",
    "research-loop-orchestrator",
}
PROHIBITED_RUNTIME_PATTERNS = (
    r"claude[-_ ]?mimo",
    r"external[-_ ]?worker",
    r"worker[-_ ]?profiles?",
    r"worker[-_ ]?preflight",
    r"invoke[-_ ]?worker",
    r"require[-_ ]?external[-_ ]?worker[-_ ]?evidence",
    r"worker[-_ ]?profile",
)


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
    if result.returncode != expect:
        raise AssertionError(
            f"command returned {result.returncode}, expected {expect}: {' '.join(command)}\n{result.stdout}"
        )
    return result


def assert_structure() -> None:
    manifest = json.loads((PLUGIN / ".codex-plugin" / "plugin.json").read_text(encoding="utf-8"))
    assert manifest["name"] == "codex-sci-loop"
    assert manifest["version"] == "1.0.0"
    skills = {path.name for path in (PLUGIN / "skills").iterdir() if path.is_dir()}
    assert skills == EXPECTED_SKILLS
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


def assert_valid_plugin_and_skills() -> None:
    assert PLUGIN_VALIDATOR.is_file()
    assert SKILL_VALIDATOR.is_file()
    output = run("python3", str(PLUGIN_VALIDATOR), str(PLUGIN)).stdout
    assert "Plugin validation passed" in output
    for name in sorted(EXPECTED_SKILLS):
        output = run("python3", str(SKILL_VALIDATOR), str(PLUGIN / "skills" / name)).stdout
        assert "Skill is valid" in output
    assert run("python3", str(CORE), "--version").stdout.strip() == "1.0.0"
    assert "DISTRIBUTION: OK" in run("python3", str(CORE), "validate-distribution").stdout


def commit_fixture(project: Path) -> None:
    run("git", "init", "-q", cwd=project)
    run("git", "config", "user.name", "LumiForge Test", cwd=project)
    run("git", "config", "user.email", "test.invalid@example.invalid", cwd=project)
    (project / "fixture.txt").write_text("baseline\n", encoding="utf-8")
    run("git", "add", "fixture.txt", cwd=project)
    run("git", "commit", "-qm", "fixture", cwd=project)


def nested_fixture(project: Path) -> Path:
    nested = project / "nested"
    nested.mkdir()
    run("git", "init", "-q", cwd=nested)
    run("git", "config", "user.name", "LumiForge Test", cwd=nested)
    run("git", "config", "user.email", "test.invalid@example.invalid", cwd=nested)
    (nested / "nested.txt").write_text("nested baseline\n", encoding="utf-8")
    run("git", "add", "nested.txt", cwd=nested)
    run("git", "commit", "-qm", "nested fixture", cwd=nested)
    return nested


def assert_native_lifecycle() -> None:
    with tempfile.TemporaryDirectory(prefix="lumiforge-sci-loop-") as raw:
        project = Path(raw).resolve()
        commit_fixture(project)
        nested = nested_fixture(project)
        base = (Path.home() / ".codex").stat() if (Path.home() / ".codex").exists() else None
        run("python3", str(CORE), "init", "--project-root", str(project))
        assert "refusing to overwrite" in run(
            "python3", str(CORE), "init", "--project-root", str(project), expect=1
        ).stdout
        config_path = project / ".ai-loop" / "loop.config.json"
        config = json.loads(config_path.read_text(encoding="utf-8"))
        config["evidence_repositories"] = [".", "nested"]
        config_path.write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")
        run("python3", str(CORE), "validate", "--project-root", str(project))
        run(
            "python3",
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
            "python3 -c 'print(\"fixture verification: OK\")'",
        )
        run_dir = project / ".ai-loop" / "runs" / "fixture-phase"
        (project / "fixture.txt").write_text("changed\n", encoding="utf-8")
        (project / "new-evidence.txt").write_text("new\n", encoding="utf-8")
        (nested / "nested.txt").write_text("nested changed\n", encoding="utf-8")
        (nested / "nested-new.txt").write_text("nested new\n", encoding="utf-8")
        (run_dir / "report.md").write_text("# Execution report\n\nFixture completed.\n", encoding="utf-8")
        run("python3", str(CORE), "collect", "--project-root", str(project), "--phase-id", "fixture-phase")
        run("python3", str(CORE), "audit-pack", "--project-root", str(project), "--phase-id", "fixture-phase")
        audit = project / ".ai-loop" / "audits" / "fixture-phase-audit.md"
        audit.write_text("# Audit\n\nDecision: ACCEPTED\n\nEvidence inspected.\n", encoding="utf-8")
        assert "host-authorized" in run(
            "python3",
            str(CORE),
            "decide",
            "--project-root",
            str(project),
            "--phase-id",
            "fixture-phase",
            "--decision",
            "accepted",
            expect=1,
        ).stdout
        audit.write_text("# Audit\n\nDecision: REWORK\n\nEvidence inspected.\n", encoding="utf-8")
        run(
            "python3",
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
            run("python3", str(CORE), "resume", "--project-root", str(project), "--json").stdout
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
        assert (project / ".ai-loop" / "events" / "state-transitions.ndjson").is_file()
        assert (project / ".ai-loop" / "events" / "state-transitions.ndjson").stat().st_mode & 0o777 == 0o600

        after = (Path.home() / ".codex").stat() if (Path.home() / ".codex").exists() else None
        assert (base.st_mtime_ns, base.st_ctime_ns) == (after.st_mtime_ns, after.st_ctime_ns) if base and after else base is after


def assert_failed_verification_cannot_use_prose_acceptance() -> None:
    with tempfile.TemporaryDirectory(prefix="lumiforge-sci-loop-failed-") as raw:
        project = Path(raw).resolve()
        commit_fixture(project)
        run("python3", str(CORE), "init", "--project-root", str(project))
        run(
            "python3",
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
        run("python3", str(CORE), "collect", "--project-root", str(project), "--phase-id", "failed-phase")
        run("python3", str(CORE), "audit-pack", "--project-root", str(project), "--phase-id", "failed-phase")
        failed_audit = project / ".ai-loop" / "audits" / "failed-phase-audit.md"
        failed_audit.write_text("# Audit\n\nDecision: ACCEPTED\n", encoding="utf-8")
        assert "host-authorized" in run(
            "python3",
            str(CORE),
            "decide",
            "--project-root",
            str(project),
            "--phase-id",
            "failed-phase",
            "--decision",
            "accepted",
            expect=1,
        ).stdout
        assert "verify_exit_code=7" in (failed_run / "verify.log").read_text(encoding="utf-8")


def main() -> None:
    assert_structure()
    assert_runtime_has_no_removed_routes()
    assert_valid_plugin_and_skills()
    assert_native_lifecycle()
    assert_failed_verification_cannot_use_prose_acceptance()
    digest = hashlib.sha256(CORE.read_bytes()).hexdigest()
    print(json.dumps({"ok": True, "plugin": "codex-sci-loop", "version": "1.0.0", "core_sha256": digest}))


if __name__ == "__main__":
    main()

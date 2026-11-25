#!/usr/bin/env python3
"""Public CLI regressions using separate processes and disposable real worktrees."""

import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest

CLI = Path(__file__).resolve().parents[1] / "plugins/codex-sci-loop/scripts/checkpoint.py"


class Checkpoints(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name).resolve()
        self.env = {**os.environ, "PYTHONDONTWRITEBYTECODE": "1", "GIT_CONFIG_NOSYSTEM": "1",
                    "GIT_CONFIG_GLOBAL": os.devnull}
        self.env.pop("LUMIFORGE_SCI_LOOP_MODE", None)
        self.command("git", "init", "-q")
        (self.root / ".gitignore").write_text("data.bin\nclock\n", encoding="utf-8")
        self.command("git", "add", ".gitignore")
        self.path = self.root / ".ai-loop/checkpoints/main.json"

    def command(self, *args, stdin=None, code=0):
        p = subprocess.run(args, cwd=self.root, env=self.env, input=stdin, text=True,
                           capture_output=True, timeout=15)
        self.assertEqual(code, p.returncode, (p.stdout, p.stderr))
        return p.stdout + p.stderr

    def cli(self, *args, **options):
        return self.command(sys.executable, "-B", str(CLI), *args, **options)

    def start(self, cmd, *args):
        self.cli("start", "--request-file", "-", "--verify-command", cmd, *args, stdin="Goal A\nKeep ε below 0.01.\n")

    def show(self):
        return json.loads(self.cli("show"))

    def test_revision_notes_and_operator_control(self):
        self.start("exit 0")
        self.cli("note", "--kind", "hypothesis", "--note", "Error decreases quadratically", "--next", "Refine grid")
        self.assertEqual("operator statement", self.show()["notes"][0]["source"])
        self.assertEqual("unverified", self.show()["verification"]["status"])
        self.cli("set-state", "--state", "blocked", "--reason", "Input not available")
        self.assertEqual("blocked", self.show()["mode"])
        self.cli("verify", code=1)
        self.cli("set-state", "--state", "active", "--reason", "Input arrived")
        self.cli("verify")
        self.assertEqual("passed", self.show()["verification"]["status"])
        amended = "Use Goal B only. Drop the old tolerance.\r\n"
        self.cli("revise", "--from-revision", "1", "--request-file", "-", stdin=amended)
        self.cli("revise", "--from-revision", "1", "--request-file", "-", stdin="previous turn", code=1)
        recovered = self.show()
        self.assertEqual(amended, recovered["request"])
        self.assertEqual("", recovered["next"])
        self.assertEqual([], recovered["notes"])
        self.assertEqual("stale", recovered["verification"]["status"])
        state = json.loads(self.path.read_text())
        self.assertEqual("Goal A\nKeep ε below 0.01.\n", state["contracts"][0]["request"])
        self.cli("set-state", "--state", "cancelled", "--reason", "User ended this task")
        self.cli("verify", code=1)
        self.assertEqual("cancelled", self.show()["mode"])

    def test_real_scientific_verifier_and_mutated_inputs(self):
        # A one-point consistency check has a narrow, measurable interpretation.
        script = self.root / "check.py"
        script.write_text("from pathlib import Path\nv = float(Path('data.bin').read_text())\n"
                          "print('measured', v)\nraise SystemExit(abs(v - 2.0) > 0.01)\n")
        data = self.root / "data.bin"
        data.write_text("2.003")
        self.start("python3 check.py", "--input", "data.bin")
        passed = json.loads(self.cli("verify"))
        self.assertEqual(0, passed["exit_code"])
        self.assertIn("2.003", passed["tail"])
        self.assertEqual(hashlib.sha256(b"2.003").hexdigest(), passed["input_sha256"]["data.bin"])
        data.write_text("2.03")
        self.assertEqual("stale", self.show()["verification"]["status"])
        self.assertEqual("failed", json.loads(self.cli("verify", code=1))["status"])
        script.write_text("raise SystemExit(0)\n")
        self.assertEqual("stale", self.show()["verification"]["status"])
        data.unlink()
        self.assertEqual("stale", self.show()["verification"]["status"])
        self.assertEqual("unavailable", json.loads(self.cli("verify", code=1))["status"])

    def test_file_hidden_by_git_status_still_invalidates_check(self):
        self.command("git", "-c", "user.name=Fixture", "-c", "user.email=f@example.invalid", "commit", "-qm", "base")
        self.command("git", "update-index", "--assume-unchanged", ".gitignore")
        self.start("exit 0")
        self.cli("verify")
        (self.root / ".gitignore").write_text("clock\n")
        self.assertEqual("stale", self.show()["verification"]["status"])

    def test_edits_during_verification_bounded_output_and_timeout(self):
        self.start("python3 -c \"open('result.txt','w').write('42')\"")
        self.assertEqual("stale", json.loads(self.cli("verify", code=1))["status"])
        self.cli("revise", "--from-revision", "1", "--request-file", "-", "--verify-command",
                 "python3 -c \"print('x'*100000)\"", stdin="Check output")
        result = json.loads(self.cli("verify"))
        self.assertEqual(100001, result["output_bytes"])
        self.assertEqual(8192, len(result["tail"]))
        self.assertLess(self.path.stat().st_size, 12000)
        self.cli("revise", "--from-revision", "2", "--request-file", "-", "--verify-command",
                 'python3 -c "import time; time.sleep(5)"', stdin="Check deadline")
        self.assertEqual("timeout", json.loads(self.cli("verify", "--timeout", "1", code=1))["status"])

    @unittest.skipUnless(os.name == "posix", "POSIX process interrupt")
    def test_interrupted_verifier_and_concurrent_writer(self):
        self.start("python3 -c \"import pathlib,time; pathlib.Path('clock').touch(); "
                   "time.sleep(.7); pathlib.Path('after-interrupt').touch()\" &")
        with subprocess.Popen([sys.executable, "-B", str(CLI), "verify"], cwd=self.root, env=self.env,
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) as child:
            try:
                deadline = time.monotonic() + 5
                while not (self.root / "clock").exists() and time.monotonic() < deadline:
                    time.sleep(0.02)
                self.assertTrue((self.root / "clock").exists())
                self.assertIn("lock", self.cli("note", "--next", "concurrent write", code=1))
            finally:
                child.send_signal(signal.SIGINT)
                child.wait(timeout=3)
        time.sleep(0.8)
        self.assertFalse((self.root / "after-interrupt").exists())
        self.assertEqual("interrupted", self.show()["verification"]["status"])
        self.cli("set-state", "--state", "paused", "--reason", "Inspect before retrying")
        self.assertEqual("paused", self.show()["mode"])

    def test_review_binds_the_original_subject_and_stays_distinct_from_verification(self):
        self.start("exit 0")
        subject = json.loads(self.cli("show", "--for-review"))["review_subject"]
        args = ("review", "--subject", subject, "--reviewer", "review-thread", "--outcome",
                "inconclusive", "--file", "-")
        self.cli(*args, stdin="The derivation lacks a boundary condition (notes, line 2).")
        report = self.show()
        self.assertEqual("current", report["review"]["freshness"])
        self.assertEqual("unverified", report["verification"]["status"])
        self.cli("note", "--note", "Use periodic boundaries")
        self.assertEqual("stale", self.show()["review"]["freshness"])
        self.cli(*args, stdin="Old review", code=1)
        self.cli("verify")
        self.assertEqual("passed", self.show()["verification"]["status"])
        self.assertEqual("stale", self.show()["review"]["freshness"])

    def test_finish_requires_current_evidence_and_respects_review_and_pending_work(self):
        self.start("exit 0", "--require-review", "--tree-only")
        self.cli("finish", code=1)
        self.assertIn("finished", self.cli("set-state", "--state", "finished", "--reason", "claim", code=2))
        self.cli("verify")
        self.assertIn("review is required", self.cli("finish", code=1))
        subject = json.loads(self.cli("show", "--for-review"))["review_subject"]
        self.cli("review", "--subject", subject, "--reviewer", "reader", "--outcome", "supported",
                 "--file", "-", stdin="Checked the explicit fixture criterion with exit code zero.")
        self.cli("note", "--next", "One more step")
        self.assertIn("pending action", self.cli("finish", code=1))
        self.cli("note", "--next", "")
        self.cli("finish")
        self.assertEqual("finished", self.show()["mode"])
        self.command("git", "add", self.path.relative_to(self.root).as_posix())
        self.command("git", "-c", "user.name=Fixture", "-c", "user.email=f@example.invalid",
                     "commit", "--only", "-qm", "save checkpoint", "--", self.path.relative_to(self.root).as_posix())
        self.assertEqual("finished", self.show()["mode"])
        (self.root / "new-source").write_text("changed")
        self.assertEqual("needs_recheck", self.show()["mode"])
        self.cli("finish", code=1)
        self.cli("set-state", "--state", "active", "--reason", "Recheck changed source")
        self.cli("verify")
        self.assertIn("review is required", self.cli("finish", code=1))

    def test_head_change_invalidates_history_dependent_verification(self):
        identity = ("git", "-c", "user.name=Fixture", "-c", "user.email=f@example.invalid")
        self.command(*identity, "commit", "-qm", "base")
        head = self.command("git", "rev-parse", "HEAD").strip()
        self.start(f'test "$(git rev-parse HEAD)" = "{head}"')
        self.cli("verify")
        self.cli("finish")
        self.command(*identity, "commit", "--allow-empty", "-qm", "new revision")
        self.assertEqual("needs_recheck", self.show()["mode"])

    @unittest.skipUnless(os.name == "posix", "POSIX process groups")
    def test_timeout_is_bounded_with_detached_pipe_writer(self):
        script = self.root / "helper.py"
        script.write_text("""import os
import time
from pathlib import Path

os.setsid()
for _ in range(50):
    if Path('stop-helper').exists() or not Path('helper.py').exists():
        break
    time.sleep(.1)
""")
        self.start("python3 helper.py &")
        start = time.monotonic()
        result = json.loads(self.cli("verify", "--timeout", "1", code=1))
        self.assertEqual("timeout", result["status"])
        (self.root / "stop-helper").touch()
        self.assertLess(time.monotonic() - start, 3)

    def test_unknown_control_and_damaged_state(self):
        self.start("exit 0")
        state = json.loads(self.path.read_text())
        state["mode"] = "success"
        self.path.write_text(json.dumps(state))
        self.assertIn("inconsistent checkpoint", self.cli("show", code=1))
        (self.root / ".ai-loop/loop.config.json").write_text("{}")
        self.assertIn("phase protocol", self.cli("start", "--task", "second", "--request-file", "-",
                                                 stdin="new scope", code=1))


if __name__ == "__main__":
    unittest.main()

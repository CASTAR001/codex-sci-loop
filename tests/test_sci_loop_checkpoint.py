#!/usr/bin/env python3
"""Public CLI regressions using separate processes and disposable real worktrees."""

import hashlib
import json
import os
import shlex
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest

CLI = Path(__file__).resolve().parents[1] / "plugins/codex-sci-loop/scripts/checkpoint.py"


def python_command(*args):
    argv = [sys.executable, *args]
    return subprocess.list2cmdline(argv) if os.name == "nt" else shlex.join(argv)


class Checkpoints(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name).resolve()
        self.env = {**os.environ, "PYTHONDONTWRITEBYTECODE": "1", "GIT_CONFIG_NOSYSTEM": "1",
                    "GIT_CONFIG_GLOBAL": os.devnull, "PYTHONIOENCODING": "utf-8"}
        self.command("git", "init", "-q")
        (self.root / ".gitignore").write_text("data.bin\nclock\n", encoding="utf-8")
        self.command("git", "add", ".gitignore")
        self.path = self.root / ".ai-loop/checkpoints/main.json"

    def command(self, *args, stdin=None, code=0):
        data = None if stdin is None else stdin.encode("utf-8")
        p = subprocess.run(args, cwd=self.root, env=self.env, input=data,
                           capture_output=True, timeout=15)
        self.assertEqual(code, p.returncode, (p.stdout, p.stderr))
        return (p.stdout + p.stderr).decode("utf-8")

    def cli(self, *args, **options):
        return self.command(sys.executable, "-B", str(CLI), *args, **options)

    def start(self, cmd, *args):
        self.cli("start", "--request-file", "-", "--verify-command", cmd, *args, stdin="Goal A\nKeep ε below 0.01.\n")

    def show(self):
        return json.loads(self.cli("show"))

    def test_ordinary_checklist_in_plain_folder_without_git(self):
        with tempfile.TemporaryDirectory() as plain:
            self.env["PATH"] = ""

            def task(action, *args, **options):
                return self.cli(action, "--project-root", plain, *args, **options)

            task("start", "--request-file", "-", stdin="Pack for the weekend. Keep the bag under 8 kg.")
            task("note", "--kind", "packing", "--note", "Carry-on only", "--next", "Pack charger")
            self.assertIn("pending action", task("close", code=1))
            self.assertEqual("Pack charger", json.loads(task("show"))["next"])
            task("note", "--next", "")
            task("finish", code=1)
            task("close")
            saved = json.loads(task("show"))
            self.assertEqual(("closed", "unverified", "operator statement"),
                             (saved["mode"], saved["verification"]["status"], saved["close_basis"]))
            self.assertFalse((Path(plain) / ".git").exists())
            task("set-state", "--state", "active", "--reason", "Add another item")
            self.assertEqual("active", json.loads(task("show"))["mode"])
            recorded, = json.loads(task("history"))["revisions"]
            closed, reopened = recorded["mode_changes"]
            self.assertEqual(("closed", "operator statement"), (closed["mode"], closed["close_basis"]))
            self.assertEqual(("active", "Add another item"), (reopened["mode"], reopened["reason"]))

    def test_plain_folder_checks_use_declared_files(self):
        with tempfile.TemporaryDirectory() as plain:
            root = Path(plain)

            def task(action, *args, **options):
                return self.cli(action, "--project-root", plain, *args, **options)

            (root / "plan.txt").write_text("Tuesday")
            (root / "check.py").write_text("from pathlib import Path\n"
                                           "raise SystemExit(Path('plan.txt').read_text() != 'Tuesday')\n")
            task("start", "--request-file", "-", "--verify-command", python_command("check.py"), stdin="Check the plan")
            self.assertIn("explicit --input", task("verify", code=1))
            task("revise", "--from-revision", "1", "--request-file", "-", "--input", "plan.txt",
                 "--input", "check.py", stdin="Check the plan")
            task("close", code=1)
            self.assertEqual("passed", json.loads(task("verify"))["status"])
            task("finish")
            (root / "unrelated.txt").write_text("Lunch")
            self.assertEqual("finished", json.loads(task("show"))["mode"])
            (root / "plan.txt").write_text("Thursday")
            self.assertEqual("needs_recheck", json.loads(task("show"))["mode"])

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
        state = json.loads(self.path.read_text(encoding="utf-8"))
        self.assertEqual("Goal A\nKeep ε below 0.01.\n", state["contracts"][0]["request"])
        self.cli("set-state", "--state", "cancelled", "--reason", "User ended this task")
        self.cli("verify", code=1)
        self.assertEqual("cancelled", self.show()["mode"])

    def test_atomic_revision_snapshots_and_paginated_history(self):
        original = "Old agreement " + "a" * 2100 + "\r\n"
        self.cli("start", "--request-file", "-", "--note", "Carry-on only", "--next", "Pack charger",
                 stdin=original)
        self.cli("start", "--request-file", "-", "--next", "duplicate", stdin=original, code=1)
        self.cli("note", "--kind", "completed", "--note", "Charger packed", "--next", "Check weather")
        self.cli("revise", "--from-revision", "1", "--request-file", "-", "--next", "incorrect", stdin="", code=1)
        self.assertEqual("Check weather", self.show()["next"])
        self.cli("revise", "--from-revision", "1", "--request-file", "-", "--kind", "decision",
                 "--note", "Leave a day later", "--next", "Move tickets", stdin="Updated trip agreement")
        self.cli("revise", "--from-revision", "1", "--request-file", "-", "--note", "stale retry",
                 stdin="Updated trip agreement", code=1)
        current = self.show()
        self.assertEqual("Move tickets", current["next"])
        self.assertEqual(["Leave a day later"], [note["text"] for note in current["notes"]])
        self.assertNotIn("pending_changes", current)
        current_page = json.loads(self.cli("history", "--limit", "1"))
        self.assertEqual(2, current_page["next_before"])
        current_revision, = current_page["revisions"]
        self.assertTrue(current_revision["is_current"])
        self.assertEqual("Move tickets", current_page["current_next"])
        self.assertEqual("Move tickets", current_revision["pending_changes"][0]["next"])
        old_page = json.loads(self.cli("history", "--before", str(current_page["next_before"]), "--limit", "1"))
        self.assertIsNone(old_page["next_before"])
        old, = old_page["revisions"]
        self.assertFalse(old["is_current"])
        self.assertTrue(old["request_truncated"])
        self.assertEqual(["Carry-on only", "Charger packed"], [note["text"] for note in old["notes"]])
        self.assertEqual(("completed", "operator statement"), (old["notes"][1]["kind"], old["notes"][1]["source"]))
        self.assertEqual([], old["verification"])
        self.assertEqual([("", "Pack charger"), ("Pack charger", "Check weather"), ("Check weather", "")],
                         [(change["previous"], change["next"]) for change in old["pending_changes"]])
        self.assertEqual("revise", old["pending_changes"][-1]["cause"])
        full, = json.loads(self.cli("history", "--revision", "1", "--full"))["revisions"]
        self.assertEqual(original, full["contract"]["request"])

    def test_history_bounds_each_event_type_in_a_long_revision(self):
        self.start("exit 0")
        artifact = self.root / "item.txt"
        long_note = "长" * 3000
        for index in range(10):
            artifact.write_text(str(index))
            self.cli("note", "--note", long_note if index == 9 else str(index),
                     "--next", str(index), "--artifact", artifact.name)
            self.cli("set-state", "--state", "active", "--reason", str(index))
            self.cli("verify")
            subject = json.loads(self.cli("show", "--for-review"))["review_subject"]
            self.cli("review", "--subject", subject, "--reviewer", "reader",
                     "--outcome", "supported", "--file", "-", stdin=f"review {index}")
        self.cli("revise", "--from-revision", "1", "--request-file", "-", stdin="New revision")
        before = self.path.read_bytes()
        current, older = json.loads(self.cli("history"))["revisions"]
        selected, = json.loads(self.cli("history", "--revision", "1"))["revisions"]
        self.assertEqual(older, selected)
        self.assertNotIn("event_totals", current)
        self.assertNotIn("full_query", current)
        self.assertEqual({"notes": 10, "artifacts": 10, "pending_changes": 11, "mode_changes": 10,
                          "verification": 10, "reviews": 10}, older["event_totals"])
        self.assertEqual("history --revision 1 --full --task main", older["full_query"])
        full, = json.loads(self.cli(*older["full_query"].split()))["revisions"]
        self.assertNotIn("event_totals", full)
        for field, count in selected["event_totals"].items():
            with self.subTest(field=field):
                self.assertEqual(count, len(full[field]))
                self.assertEqual(8, len(selected[field]))
                self.assertEqual(full[field][-8:-1], selected[field][:-1])
        self.assertEqual(["text"], selected["notes"][-1]["truncated_fields"])
        self.assertEqual(long_note[:2048], selected["notes"][-1]["text"])
        self.assertEqual(long_note, full["notes"][-1]["text"])
        self.assertEqual(before, self.path.read_bytes())

    def test_artifact_observations_are_revision_scoped_and_bounded(self):
        names = ["会议记录.txt", "minutes.txt", "agenda.txt", "handout.txt"]
        body = "这是文件内容，不应复制到检查点。".encode()
        for name in names:
            (self.root / name).write_bytes(body)
        self.cli("start", "--request-file", "-", "--note", "约定", "--artifact", names[0], stdin="会议")
        for name in names[1:]:
            self.cli("note", "--artifact", name, "--artifact", "./" + name)
        current = self.show()
        self.assertEqual(4, current["artifact_count"])
        self.assertEqual(names[1:], [item["path"] for item in current["artifacts"]])
        self.assertEqual(names, [item["path"] for item in json.loads(self.cli("show", "--full"))["artifacts"]])
        self.assertNotIn(body, self.path.read_bytes())
        (self.root / names[0]).write_bytes(b"revised content")
        self.cli("revise", "--from-revision", "1", "--request-file", "-", "--artifact", names[0], stdin="会议改期")
        (self.root / names[0]).unlink()
        observed, = self.show()["artifacts"]
        self.assertEqual((2, hashlib.sha256(b"revised content").hexdigest()),
                         (observed["revision"], observed["sha256"]))
        history = self.cli("history", "--full")
        self.assertIn("会议改期", history)
        old = json.loads(history)["revisions"][1]["artifacts"][0]
        self.assertEqual((1, names[0], hashlib.sha256(body).hexdigest(), len(body), "observed file contents"),
                         (old["revision"], old["path"], old["sha256"], old["size"], old["source"]))
        self.assertTrue(old["at"])
        self.env["PYTHONIOENCODING"] = "ascii"
        fallback = self.cli("history", "--full")
        self.assertTrue(fallback.isascii())
        self.assertEqual(json.loads(history), json.loads(fallback))

    def test_unusable_artifact_aborts_the_entire_snapshot(self):
        (self.root / "report.txt").write_text("report")
        (self.root / "directory").mkdir()
        self.cli("start", "--request-file", "-", "--artifact", "missing", stdin="Prepare a report", code=1)
        self.assertFalse(self.path.exists())
        self.cli("start", "--request-file", "-", "--next", "Draft report", stdin="Prepare a report")
        before = self.path.read_bytes()
        for name in ("missing", "..", "directory", str(self.root / "report.txt"), ".ai-loop/checkpoints/main.json"):
            with self.subTest(path=name):
                self.cli("note", "--note", "Disallowed", "--next", "", "--artifact", "report.txt",
                         "--artifact", name, code=1)
                self.assertEqual(before, self.path.read_bytes())
        self.cli("revise", "--from-revision", "1", "--request-file", "-", "--artifact", "missing",
                 "--next", "New next", stdin="Wrong revision", code=1)
        self.assertEqual(before, self.path.read_bytes())

    @unittest.skipUnless(os.name == "nt", "Windows code pages and junctions")
    def test_windows_git_path_codepage_and_junction(self):
        project = self.root / "资料 and notes"
        project.mkdir()
        # A private temporary parent can propagate explicit ACEs without an (I) display
        # flag. Give this disposable parent a distinctive inheritable restriction.
        subprocess.run(["icacls.exe", str(project), "/deny", "*S-1-5-7:(OI)(CI)(RX)"],
                       check=True, stdout=subprocess.DEVNULL, timeout=10)
        (project / "reference-directory").mkdir()
        self.command("git", "-C", str(project), "init", "-q")
        request = project / "约定.txt"
        raw = "周一\r\n再核对\n".encode("utf-8")
        request.write_bytes(raw)
        self.env["PYTHONIOENCODING"] = "cp936"
        self.cli("start", "--project-root", str(project), "--request-file", str(request),
                 "--artifact", request.name)
        result = json.loads(self.cli("show", "--project-root", str(project), "--full"))
        self.assertEqual(raw.decode("utf-8"), result["request"])
        self.assertEqual(hashlib.sha256(raw).hexdigest(), result["artifacts"][0]["sha256"])
        # Both Windows clients need the same inherited worktree permissions.
        def access_descriptor(directory):
            return subprocess.check_output([
                "powershell.exe", "-NoProfile", "-NonInteractive", "-Command",
                f"(Get-Acl -LiteralPath '{directory}').GetSecurityDescriptorSddlForm('Access')",
            ], cwd=project, timeout=20).strip()
        expected_acl = access_descriptor("reference-directory")
        self.assertIn(b"(D;", expected_acl)
        self.assertEqual(expected_acl, access_descriptor(".ai-loop"))
        target = self.root / "outside"
        target.mkdir()
        (target / "result.txt").write_bytes(b"outside")
        link = project / "junction"
        subprocess.run(["cmd.exe", "/d", "/c", "mklink", "/J", str(link), str(target)],
                       check=True, stdout=subprocess.DEVNULL, timeout=10)
        self.addCleanup(link.rmdir)
        path = project / ".ai-loop/checkpoints/main.json"
        before = path.read_bytes()
        self.cli("note", "--project-root", str(project), "--artifact", "junction/result.txt", code=1)
        self.assertEqual(before, path.read_bytes())

    @unittest.skipUnless(os.name == "posix", "POSIX symlink and special file fixtures")
    def test_symlinked_and_special_artifacts_are_refused(self):
        target = self.root / "directory"
        target.mkdir()
        source = target / "report.txt"
        source.write_text("report")
        (self.root / "report-link").symlink_to(source)
        (self.root / "directory-link").symlink_to(target, target_is_directory=True)
        os.mkfifo(self.root / "pipe")
        self.cli("start", "--request-file", "-", stdin="Prepare a report")
        before = self.path.read_bytes()
        for name in ("report-link", "directory-link/report.txt", "pipe"):
            with self.subTest(path=name):
                self.cli("note", "--artifact", name, code=1)
                self.assertEqual(before, self.path.read_bytes())

    def test_history_retains_compact_superseded_evidence(self):
        self.start(python_command("-c", "print('evidence', end='')"))
        first = json.loads(self.cli("verify"))
        second = json.loads(self.cli("verify"))
        self.cli("revise", "--from-revision", "1", "--request-file", "-", "--verify-command", "exit 1",
                 stdin="Compare another result")
        self.cli("verify", code=1)
        old, = json.loads(self.cli("history", "--revision", "1"))["revisions"]
        self.assertEqual(["passed", "passed"], [record["recorded_status"] for record in old["verification"]])
        self.assertEqual([first["output_sha256"], second["output_sha256"]],
                         [record["output_sha256"] for record in old["verification"]])
        self.assertTrue(all("tail" not in record and "status" not in record for record in old["verification"]))
        self.assertEqual("failed", self.show()["verification"]["status"])

    def test_history_accepts_existing_checkpoint_without_fabricating_old_actions(self):
        self.start("exit 0")
        self.cli("revise", "--from-revision", "1", "--request-file", "-", stdin="New goal")
        state = json.loads(self.path.read_text(encoding="utf-8"))
        state["next"] = "Already pending in a legacy checkpoint"
        self.path.write_text(json.dumps(state))
        old, = json.loads(self.cli("history", "--revision", "1"))["revisions"]
        self.assertEqual([], old["pending_changes"])
        self.cli("note", "--next", "")
        current, = json.loads(self.cli("history", "--revision", "2"))["revisions"]
        self.assertEqual("Already pending in a legacy checkpoint", current["pending_changes"][0]["previous"])
        self.assertEqual("", current["pending_changes"][0]["next"])

    def test_real_scientific_verifier_and_mutated_inputs(self):
        # A one-point consistency check has a narrow, measurable interpretation.
        script = self.root / "check.py"
        script.write_text("from pathlib import Path\nv = float(Path('data.bin').read_text())\n"
                          "print('measured', v)\nraise SystemExit(abs(v - 2.0) > 0.01)\n")
        data = self.root / "data.bin"
        data.write_text("2.003")
        self.start(python_command("check.py"), "--input", "data.bin")
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
        self.start(python_command("-c", "open('result.txt','w').write('42')"))
        self.assertEqual("stale", json.loads(self.cli("verify", code=1))["status"])
        self.cli("revise", "--from-revision", "1", "--request-file", "-", "--verify-command",
                 python_command("-c", "import sys; sys.stdout.buffer.write(b'x'*100000 + bytes([10]))"),
                 stdin="Check output")
        result = json.loads(self.cli("verify"))
        self.assertEqual(100001, result["output_bytes"])
        self.assertEqual(8192, len(result["tail"]))
        self.assertLess(self.path.stat().st_size, 12000)
        self.cli("revise", "--from-revision", "2", "--request-file", "-", "--verify-command",
                 python_command("-c", "import time; time.sleep(5)"), stdin="Check deadline")
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
        recorded, = json.loads(self.cli("history"))["revisions"]
        self.assertEqual("interrupted", recorded["verification"][0]["recorded_status"])

    def test_review_binds_the_original_subject_and_stays_distinct_from_verification(self):
        self.start("exit 0")
        subject = json.loads(self.cli("show", "--for-review"))["review_subject"]
        args = ("review", "--subject", subject, "--reviewer", "review-thread", "--outcome",
                "inconclusive", "--file", "-")
        self.cli(*args, stdin="The derivation lacks a boundary condition (notes, line 2).")
        self.cli("close", code=1)
        report = self.show()
        self.assertEqual("current", report["review"]["freshness"])
        self.assertEqual("unverified", report["verification"]["status"])
        self.cli("note", "--note", "Use periodic boundaries")
        self.assertEqual("stale", self.show()["review"]["freshness"])
        self.cli(*args, stdin="Old review", code=1)
        self.cli("verify")
        self.assertEqual("passed", self.show()["verification"]["status"])
        self.assertEqual("stale", self.show()["review"]["freshness"])
        subject = json.loads(self.cli("show", "--for-review"))["review_subject"]
        self.cli("review", "--subject", subject, "--reviewer", "review-thread", "--outcome", "supported",
                 "--file", "-", stdin="Rechecked the evidence with periodic boundaries.")
        recorded, = json.loads(self.cli("history"))["revisions"]
        self.assertEqual(["inconclusive", "supported"], [review["outcome"] for review in recorded["reviews"]])
        self.assertTrue(all("report_sha256" in review and "report" not in review for review in recorded["reviews"]))

    def test_finish_requires_current_evidence_and_respects_review_and_pending_work(self):
        self.start("exit 0", "--require-review", "--tree-only")
        self.cli("close", code=1)
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
        self.start(python_command("-c", "import subprocess; "
                                 f"raise SystemExit(subprocess.check_output(['git','rev-parse','HEAD']).strip() != b'{head}')"))
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
        state = json.loads(self.path.read_text(encoding="utf-8"))
        state["mode"] = "success"
        self.path.write_text(json.dumps(state))
        self.assertIn("inconsistent checkpoint", self.cli("show", code=1))
        (self.root / ".ai-loop/loop.config.json").write_text("{}")
        self.assertIn("phase protocol", self.cli("start", "--task", "second", "--request-file", "-",
                                                 stdin="new scope", code=1))


if __name__ == "__main__":
    unittest.main()

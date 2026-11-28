"""Exercise the delivered CLI in separate processes; no credentials, server or model."""

from contextlib import closing
import concurrent.futures
import json
import os
from pathlib import Path
import sqlite3
import subprocess
import sys
import tempfile
import unittest

HERE = Path(__file__).resolve().parents[1]
CLI = HERE / "plugins/codex-sci-loop/scripts/exchange.py"
if not CLI.is_file():
    CLI = HERE / "exchange/exchange.py"


class Mailbox(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name) / "测试 workspace"
        self.root.mkdir()
        self.db = self.root / ".ai-loop/exchange/v1/mailbox.sqlite3"

    def call(self, actor, op, fail=None, host="codex", **k):
        proc = subprocess.run(
            [sys.executable, "-IB", str(CLI), "--root", str(self.root), "--host", host],
            env={**os.environ, "CODEX_THREAD_ID": actor, "OPENCODE_EXCHANGE_SESSION": actor},
            input=json.dumps({"protocol": 1, "op": op, **k}).encode(),
            capture_output=True,
            timeout=10,
        )
        data = json.loads(proc.stdout)
        if fail:
            self.assertFalse(data["ok"])
            self.assertIn(fail, data["error"])
            return
        self.assertTrue(data["ok"], data)
        return data["data"]

    def pair(self, a="main", b="worker"):
        self.call(a, "join", alias=a)
        self.call(b, "join", alias=b)
        self.call(a, "link", peer=b)
        self.call(b, "link", peer=a)

    def read(self, a, b):
        page = self.call(a, "sync", peer=b)
        if page["entries"]:
            self.call(a, "ack", peer=b, seqs=[r["seq"] for r in page["entries"]], receipt=page["receipt"])
        return {b: page["basis"]}

    def send(self, a, b, body, key, kind="status", **k):
        return self.call(a, "publish", peer=b, basis=self.read(a, b), body=body, key=key, kind=kind, **k)

    def test_offline_amendment_and_receipts(self):
        self.pair()
        self.send("worker", "main", "初版可以发布", "approval", "constraint")
        old = self.read("main", "worker")
        draft = dict(peer="worker", basis=old, body="准备交接", kind="handoff", key="closure")
        self.send("worker", "main", "现在只允许本机验收", "revoke", "correct", ref=1)
        self.call("main", "publish", fail="stale", **draft)
        page = self.call("main", "sync", peer="worker")
        self.assertEqual(page["entries"][0]["body"], "现在只允许本机验收")
        self.call("main", "ack", peer="worker", seqs=[2], receipt="guessed", fail="receipt")
        draft["basis"] = self.read("main", "worker")
        first = self.call("main", "publish", **draft)
        again = self.call("main", "publish", **draft)
        self.assertEqual(first["seq"], again["seq"])
        self.assertTrue(again["duplicate"])
        draft["body"] = "其他结果"
        self.call("main", "publish", fail="idempotency", **draft)
        self.assertEqual(self.call("main", "inspect", peer="worker")["open_count"], 1)

    def test_pagination_takeover_and_scope(self):
        self.pair()
        for n in range(7):
            self.send("worker", "main", str(n), str(n), "question")
        page = self.call("main", "sync", peer="worker")
        self.assertTrue(page["more"])
        self.call(
            "main",
            "ack",
            peer="worker",
            seqs=[page["entries"][-1]["seq"]],
            receipt=page["receipt"],
            fail="receipt",
        )
        self.read("main", "worker")
        self.read("main", "worker")
        self.assertEqual(self.call("main", "sync", peer="worker")["entries"], [])
        reply = self.send("main", "worker", "answer", "a", "reply", ref=1)
        self.assertGreater(reply["seq"], 7)
        self.assertEqual(self.call("main", "inspect", peer="worker")["open_count"], 6)
        self.call("outside", "join", alias="outsider")
        self.call("outside", "inspect", peer="worker", fail="mutual")
        self.call("outside", "link", peer="worker")
        self.call("outside", "sync", peer="worker", fail="mutual")
        self.call("main", "inspect", peer="worker", host="opencode", fail="not joined")
        ticket = self.call("main", "offer")["ticket"]
        self.call("new", "claim", ticket=ticket)
        self.call("main", "sync", fail="not joined")
        self.call("third", "claim", ticket=ticket, fail="invalid")
        self.assertEqual(self.call("new", "inspect", peer="worker")["open_count"], 6)

    def test_withdrawing_corrected_answer_reopens_question(self):
        self.pair()
        q = self.send("worker", "main", "approve?", "q", "question")["seq"]
        answer = self.send("main", "worker", "yes", "a", "reply", ref=q)["seq"]
        amend = self.send("main", "worker", "only local", "b", "correct", ref=answer)["seq"]
        self.assertEqual(self.call("main", "inspect", peer="worker")["open_count"], 0)
        self.send("main", "worker", "pending", "c", "withdraw", ref=amend)
        self.assertEqual(self.call("main", "inspect", peer="worker")["open_count"], 1)
        self.send("main", "worker", "confirmed locally", "d", "reply", ref=q)
        self.assertEqual(self.call("main", "inspect", peer="worker")["open_count"], 0)

    def test_atomic_writes_and_versions(self):
        self.pair()
        req = dict(peer="worker", basis=self.read("main", "worker"), body="one", kind="status", key="retry")
        with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
            replies = list(pool.map(lambda _: self.call("main", "publish", **req), range(12)))
        self.assertEqual(sum(not r["duplicate"] for r in replies), 1)
        with closing(sqlite3.connect(self.db)) as db:
            db.execute("PRAGMA user_version=99")
        self.call("main", "publish", fail="unsupported mailbox format", **req)

    def test_checkpoint_projection(self):
        self.call("main", "join", alias="master")
        self.call("worker", "join", alias="impl", checkpoint="impl")
        self.call("main", "link", peer="impl")
        self.call("worker", "link", peer="master", fields=["next"])
        p = self.root / ".ai-loop/checkpoints/impl.json"
        p.parent.mkdir()
        p.write_text(
            json.dumps(
                {
                    "schema": "sci-loop-checkpoint-v1",
                    "task": "impl",
                    "contracts": [{"request": "PRIVATE"}],
                    "next": "检查 Word",
                    "mode": "active",
                }
            ),
            encoding="utf-8",
        )
        self.call("worker", "snapshot", peer="master", basis=self.read("worker", "master"), key="check-1")
        view = self.call("main", "sync", peer="impl")["entries"][0]["body"]
        self.assertEqual(json.loads(view), {"revision": 1, "next": "检查 Word"})
        self.assertTrue(
            self.call(
                "worker", "snapshot", peer="master", basis=self.read("worker", "master"), key="check-2"
            )["unchanged"]
        )

    def test_checkpoint_delivery_and_evidence(self):
        import hashlib

        self.call("worker", "join", alias="worker", checkpoint="report")
        self.call("main", "join", alias="main")
        self.call("main", "link", peer="worker")
        self.call("worker", "link", peer="main", fields=["next", "artifacts"])
        path = self.root / "report.md"
        path.write_bytes(b"first")
        script = CLI.parent / "checkpoint.py"

        def save(*args):
            return subprocess.run(
                [sys.executable, "-B", str(script), *args, "--task", "report"],
                cwd=self.root,
                env={**os.environ, "CODEX_THREAD_ID": "worker"},
                input=b"private contract",
                check=True,
                capture_output=True,
            )

        save("start", "--request-file", "-", "--next", "review", "--artifact", "report.md")
        page = self.call("main", "sync", peer="worker")
        seq = page["entries"][0]["seq"]
        body = json.loads(page["entries"][0]["body"])
        self.assertEqual(
            body["artifacts"], [{"path": "report.md", "sha256": hashlib.sha256(b"first").hexdigest()}]
        )
        self.assertNotIn("private", str(body))
        self.assertEqual(self.call("main", "evidence", peer="worker", seq=seq, index=0)["state"], "unchanged")
        path.write_bytes(b"second")
        self.assertEqual(self.call("main", "evidence", peer="worker", seq=seq, index=0)["state"], "changed")
        path.unlink()
        self.assertEqual(
            self.call("main", "evidence", peer="worker", seq=seq, index=0)["state"], "unavailable"
        )
        self.send("main", "worker", "hold release", "hold", "constraint")
        save("note", "--next", "waiting")
        self.assertEqual(self.call("main", "sync", peer="worker")["entries"], [])
        self.read("worker", "main")
        self.assertEqual(self.call("worker", "refresh")["published"], ["main"])
        self.assertEqual(self.call("worker", "refresh")["published"], [])
        self.assertEqual(
            json.loads(self.call("main", "sync", peer="worker")["entries"][0]["body"])["next"], "waiting"
        )

    def test_takeover_keeps_history_but_requires_new_sharing_consent(self):
        self.call("old", "join", alias="old", checkpoint="notes")
        self.call("main", "join", alias="main")
        self.call("old", "link", peer="main", fields=["next"])
        self.call("main", "link", peer="old")
        self.send("old", "main", "current", "1")
        self.read("main", "old")
        ticket = self.call("old", "offer")["ticket"]
        self.call("new", "claim", ticket=ticket, host="opencode")
        result = self.call("new", "milestone", host="opencode", progress={"next": ["private"]})
        self.assertEqual(result["published"], [])
        self.assertEqual(self.call("main", "inspect", peer="old")["recent"][0]["excerpt"], "current")
        self.assertFalse(self.call("main", "notice")["pending"])

    def test_empty_sandbox_git_marker_is_an_ordinary_workspace(self):
        marker = self.root / ".git"
        marker.mkdir()
        self.assertEqual(self.call("main", "join", alias="main")["joined"], "main")
        marker.rmdir()
        marker.touch()
        self.assertEqual(self.call("main", "peers")["self"], "main")

    def test_link_generation_and_aborted_transaction(self):
        self.pair()
        self.send("worker", "main", "first", "msg")
        old = self.call("main", "sync", peer="worker")
        self.call("worker", "unlink", peer="main")
        self.call("main", "link", peer="worker")
        self.call("worker", "link", peer="main")
        self.call("main", "ack", peer="worker", seqs=[1], receipt=old["receipt"], fail="receipt")
        cmd = "import os,sqlite3,sys; db=sqlite3.connect(sys.argv[1]); db.execute('BEGIN IMMEDIATE'); db.execute('DELETE FROM events'); os._exit(6)"
        self.assertEqual(subprocess.run([sys.executable, "-IB", "-c", cmd, str(self.db)]).returncode, 6)
        self.assertEqual(self.call("main", "sync", peer="worker")["entries"][0]["body"], "first")

    def test_worktree_and_redirect_isolation(self):
        other = self.root.parent / "other workspace"
        env = {**os.environ, "GIT_CONFIG_GLOBAL": os.devnull, "GIT_CONFIG_NOSYSTEM": "1"}

        def git(*args):
            subprocess.run(["git", "-C", str(self.root), *args], env=env, check=True, capture_output=True)

        git("init", "-q")
        git(
            "-c",
            "user.name=Fixture",
            "-c",
            "user.email=fixture@invalid.example",
            "commit",
            "-q",
            "--allow-empty",
            "-m",
            "fixture",
        )
        git("worktree", "add", "--detach", str(other))
        self.pair()
        self.root = other
        self.assertFalse(self.call("main", "notice")["pending"])
        self.assertFalse((other / ".ai-loop").exists())
        where = other / ".ai-loop"
        if os.name == "nt":
            subprocess.run(
                ["cmd", "/c", "mklink", "/J", str(where), str(self.db.parents[2])],
                check=True,
                capture_output=True,
            )
        else:
            where.symlink_to(self.db.parents[2], target_is_directory=True)
        self.call("main", "join", alias="bad", fail="redirected")

    def test_no_implicit_mailbox_or_legacy_conversion(self):
        self.assertFalse(self.call("main", "notice")["pending"])
        self.assertFalse((self.root / ".ai-loop").exists())
        (self.root / ".ai-loop").mkdir()
        (self.root / ".ai-loop/loop.config.json").write_text("{}")
        self.call("main", "join", alias="main", fail="legacy")
        self.assertFalse(self.db.exists())


if __name__ == "__main__":
    unittest.main()

"""Project-local conversation mailbox. Protocol 1: UTF-8 JSON on stdin/stdout."""

from __future__ import annotations

import argparse
import contextlib
import hashlib
import hmac
import json
import os
from pathlib import Path
import re
import secrets
import sqlite3
import stat
import subprocess
import sys
import unicodedata
import uuid

VERSION = 1
PAGE = 4
KINDS = {"status", "question", "reply", "constraint", "withdraw", "correct", "handoff"}
DDL = (
    "CREATE TABLE workspace(id TEXT PRIMARY KEY, receipt_secret BLOB NOT NULL)",
    "CREATE TABLE peers(id INTEGER PRIMARY KEY, task TEXT NOT NULL, alias TEXT NOT NULL, session TEXT UNIQUE, claim TEXT, checkpoint TEXT, UNIQUE(task,alias))",
    "CREATE TABLE edges(owner INTEGER NOT NULL, peer INTEGER NOT NULL, fields TEXT NOT NULL, epoch TEXT NOT NULL, seen INTEGER NOT NULL DEFAULT 0, PRIMARY KEY(owner,peer))",
    "CREATE TABLE events(seq INTEGER PRIMARY KEY, sender INTEGER NOT NULL, dest INTEGER NOT NULL, key TEXT NOT NULL, kind TEXT NOT NULL, topic TEXT NOT NULL, body TEXT NOT NULL, ref INTEGER, reply_to INTEGER, source TEXT NOT NULL, basis TEXT NOT NULL, fingerprint TEXT NOT NULL, at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, UNIQUE(sender,key))",
    "CREATE INDEX inbox ON events(dest,sender,seq)",
    "CREATE INDEX sent ON events(sender,dest,seq)",
    "CREATE INDEX related ON events(ref)",
    "CREATE INDEX answers ON events(reply_to)",
    "CREATE TABLE reused_snapshots(sender INTEGER NOT NULL, key TEXT NOT NULL, seq INTEGER NOT NULL, fingerprint TEXT NOT NULL, PRIMARY KEY(sender,key))",
    """CREATE VIEW active_answers AS SELECT a.reply_to AS question, a.seq FROM events a
        WHERE a.reply_to IS NOT NULL AND NOT EXISTS (SELECT 1 FROM events n WHERE n.ref=a.seq AND n.kind IN ('correct','withdraw'))""",
    "CREATE TABLE drafts(owner INTEGER NOT NULL, peer INTEGER NOT NULL, body TEXT NOT NULL, PRIMARY KEY(owner,peer))",
)


class Refused(ValueError):
    pass


def require(ok, message):
    if not ok:
        raise Refused(message)


def string(value, limit, label):
    require(isinstance(value, str) and 0 < len(value) <= limit and value.strip(), "invalid " + label)
    return value


def name(value):
    value = string(value, 90, "name")
    require(
        value == unicodedata.normalize("NFC", value).strip()
        and all(c.isalnum() or c in "-_. " for c in value),
        "invalid name",
    )
    return value


def digest(value):
    raw = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False)
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def project(directory):
    root = Path(directory).resolve(strict=True)
    require(root.is_dir(), "workspace must be a directory")
    def has_git_metadata(folder):
        marker = folder / ".git"
        # A workspace-write sandbox may mount an empty read-only marker even
        # in an ordinary folder. Real worktrees have HEAD or a gitdir file.
        if marker.is_dir():
            return (marker / "HEAD").is_file() or (marker / "commondir").is_file()
        return marker.is_file() and marker.stat().st_size > 0

    if any(has_git_metadata(p) for p in (root, *root.parents)):
        paths = [
            p
            for p in os.get_exec_path()
            if os.path.isabs(p) and Path(p).resolve() not in (root, Path.cwd().resolve())
        ]
        git = next(
            (
                str(Path(p) / exe)
                for p in paths
                for exe in (("git.exe",) if os.name == "nt" else ("git",))
                if (Path(p) / exe).is_file() and os.access(Path(p) / exe, os.X_OK)
            ),
            None,
        )
        require(git, "Git executable unavailable; cannot identify worktree")
        result = subprocess.run(
            [git, "-C", str(root), "rev-parse", "--show-toplevel"],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            timeout=4,
            check=True,
        )
        root = Path(result.stdout.decode("utf-8").rstrip("\r\n")).resolve(strict=True)
    return root


def plain(path):
    if not os.path.lexists(path):
        return
    try:
        st = path.lstat()
    except FileNotFoundError:
        return
    require(
        not stat.S_ISLNK(st.st_mode) and not getattr(st, "st_file_attributes", 0) & 1024,
        "linked or redirected mailbox path",
    )


def database(root, create):
    parent = root
    for component in (".ai-loop", "exchange", "v1"):
        parent = parent / component
        plain(parent)
        if component == ".ai-loop":
            require(not os.path.lexists(parent / "loop.config.json"), "legacy phase workspace")
        if create:
            parent.mkdir(mode=0o777 if os.name == "nt" else 0o700, exist_ok=True)
        if not parent.is_dir():
            return None
    dbfile = parent / "mailbox.sqlite3"
    if create:
        try:
            with (parent / ".gitignore").open("x", encoding="ascii") as f:
                f.write("*\n")
        except FileExistsError:
            pass
    for suffix in ("", "-journal", "-shm", "-wal"):
        file = parent / (dbfile.name + suffix)
        plain(file)
        try:
            st = file.stat()
        except FileNotFoundError:  # SQLite may have just removed its rollback journal.
            continue
        require(stat.S_ISREG(st.st_mode) and st.st_nlink == 1, "invalid or shared mailbox file")
    if not dbfile.exists() and not create:
        return None
    if create:
        try:
            fd = os.open(dbfile, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
        except FileExistsError:
            pass
        else:
            os.close(fd)
    require(dbfile.is_file(), "invalid mailbox")
    return sqlite3.connect(dbfile.as_uri() + "?mode=rw", uri=True, timeout=3, isolation_level=None)


def row_dict(row):
    return {k: row[k] for k in ("seq", "kind", "body", "ref", "source", "at")}


def dispatch(root, client, session, req):
    require(
        isinstance(req, dict) and type(req.get("protocol")) is int and req["protocol"] == VERSION,
        "unsupported protocol",
    )
    op = req.get("op")
    if op == "capabilities":
        return {"protocol": VERSION, "storage": VERSION, "page": PAGE}
    identity = digest([client, string(session, 256, "host session")])
    create = op == "join"
    conn = database(root, create)
    if conn is None:
        if op == "notice":
            return {"pending": False}
        raise Refused("workspace has no mailbox; join first")
    with contextlib.closing(conn):
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA trusted_schema=OFF")
        reads = {"peers", "evidence", "inspect", "sync", "notice", "export"}
        conn.execute("BEGIN" if op in reads else "BEGIN IMMEDIATE")
        version = conn.execute("PRAGMA user_version").fetchone()[0]
        if not version and create:
            require(
                not conn.execute("SELECT 1 FROM sqlite_master LIMIT 1").fetchone(), "unrecognized database"
            )
            for sql in DDL:
                conn.execute(sql)
            conn.execute("INSERT INTO workspace VALUES (?,?)", (uuid.uuid4().hex, secrets.token_bytes(32)))
            conn.execute("PRAGMA user_version=1")
            version = 1
        require(version == VERSION, "unsupported mailbox format")
        result = operate(conn, root, client, identity, req)
        conn.commit()
        return result


def operate(db, root, client, identity, req):
    op = req["op"]
    me = db.execute("SELECT * FROM peers WHERE session=?", (identity,)).fetchone()
    if op == "join":
        alias, task = name(req.get("alias")), name(req.get("task", "main"))
        checkpoint = req.get("checkpoint")
        if checkpoint is not None:
            require(client == "codex", "local checkpoint binding is Codex-only")
            require(
                isinstance(checkpoint, str)
                and re.fullmatch(r"[a-z0-9][a-z0-9._-]{0,95}", checkpoint)
                and not re.match(r"^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)", checkpoint),
                "invalid checkpoint ID",
            )
        if me:
            require(
                (me["alias"], me["task"], me["checkpoint"]) == (alias, task, checkpoint),
                "session already bound",
            )
        else:
            require(
                not db.execute("SELECT 1 FROM peers WHERE alias=? AND task=?", (alias, task)).fetchone(),
                "alias already bound",
            )
            db.execute(
                "INSERT INTO peers(task,alias,session,checkpoint) VALUES(?,?,?,?)",
                (task, alias, identity, checkpoint),
            )
        return {"joined": alias, "task": task}
    if op == "claim":
        require(not me, "session already bound")
        secret = string(req.get("ticket"), 128, "handoff ticket")
        changed = db.execute(
            "UPDATE peers SET claim=NULL,session=? WHERE claim=?", (identity, digest(secret))
        )
        require(changed.rowcount == 1, "invalid or consumed ticket")
        return {"claimed": True}
    if op == "notice" and not me:
        return {"pending": False}
    require(me, "session has not joined")
    who = me["id"]
    if op == "offer":
        ticket = secrets.token_urlsafe(32)
        db.execute("UPDATE peers SET claim=? WHERE id=?", (digest(ticket), who))
        return {"ticket": ticket}
    if op == "peers":
        return {
            "self": me["alias"],
            "task": me["task"],
            "peers": [
                dict(r)
                for r in db.execute(
                    """SELECT p.alias, EXISTS(SELECT 1 FROM edges WHERE owner=? AND peer=p.id) AS selected,
            EXISTS(SELECT 1 FROM edges WHERE owner=p.id AND peer=?) AS invited,
            (SELECT MAX(seq) FROM events WHERE sender=p.id AND dest=?) AS last_shared
            FROM peers p WHERE task=? AND id<>? ORDER BY p.alias""",
                    (who, who, who, me["task"], who),
                )
            ],
        }
    linked = db.execute(
        """SELECT p.id,p.alias,a.seen,a.fields,a.epoch AS owner_epoch,b.epoch AS peer_epoch FROM edges a JOIN edges b
        ON b.owner=a.peer AND b.peer=a.owner JOIN peers p ON p.id=a.peer WHERE a.owner=? ORDER BY p.alias""",
        (who,),
    ).fetchall()
    buddies = {r["alias"]: r for r in linked}
    workspace, secret = db.execute("SELECT id,receipt_secret FROM workspace").fetchone()

    def head(peer):
        one = (
            db.execute("SELECT max(seq) FROM events WHERE sender=? AND dest=?", (who, peer)).fetchone()[0]
            or 0
        )
        two = (
            db.execute("SELECT max(seq) FROM events WHERE sender=? AND dest=?", (peer, who)).fetchone()[0]
            or 0
        )
        return max(one, two), two

    by_id = {r["id"]:r for r in linked}

    def link_epoch(peer):
        edge = by_id[peer]
        return [edge["owner_epoch"], edge["peer_epoch"]]

    def basis(peer):
        seq, _ = head(peer)
        return digest([workspace, who, peer, link_epoch(peer), seq])

    def receipt(peer, seqs):
        return hmac.new(
            secret, digest([identity, peer, link_epoch(peer), seqs]).encode(), hashlib.sha256
        ).hexdigest()

    def inbox(peer, seen):
        return db.execute(
            "SELECT * FROM events WHERE sender=? AND dest=? AND seq>? ORDER BY seq LIMIT ?",
            (peer, who, seen, PAGE),
        ).fetchall()

    if op == "notice":
        return {
            "pending": any(head(r["id"])[1] > r["seen"] for r in linked),
            "has_history": any(r["seen"] > 0 for r in linked),
        }
    if op == "export":
        return {
            "workspace": workspace,
            "self": me["alias"],
            "events": [
                dict(r)
                for r in db.execute(
                    """SELECT e.seq,a.alias AS sender,b.alias AS recipient,e.kind,e.body,e.source,e.at,e.ref,e.basis
            FROM events e JOIN peers a ON a.id=e.sender JOIN peers b ON b.id=e.dest
            WHERE e.sender=? OR e.dest=? ORDER BY e.seq""",
                    (who, who),
                )
            ],
        }
    alias = req.get("peer")
    if op == "link":
        peer = db.execute(
            "SELECT id FROM peers WHERE task=? AND alias=?", (me["task"], name(alias))
        ).fetchone()
        require(peer and peer[0] != who, "unknown peer in this task")
        fields = req.get("fields", [])
        require(
            isinstance(fields, list)
            and all(
                isinstance(f, str)
                and f
                in ({"mode", "next", "artifacts"} if client == "codex" else {"constraints", "done", "next"})
                for f in fields
            ),
            "invalid checkpoint fields",
        )
        allowed = json.dumps(sorted(set(fields)))
        old = db.execute("SELECT fields FROM edges WHERE owner=? AND peer=?", (who, peer[0])).fetchone()
        db.execute(
            """INSERT INTO edges(owner,peer,fields,epoch) VALUES(?,?,?,?) ON CONFLICT(owner,peer)
                   DO UPDATE SET fields=excluded.fields""",
            (who, peer[0], allowed, secrets.token_hex(12)),
        )
        if old and old[0] != allowed:
            db.execute("DELETE FROM drafts WHERE owner=? AND peer=?", (who, peer[0]))
        accepted = db.execute("SELECT 1 FROM edges WHERE owner=? AND peer=?", (peer[0], who)).fetchone()
        return {"peer": alias, "paired": bool(accepted), "fields": sorted(set(fields))}
    if op == "unlink":
        peer = db.execute(
            "SELECT id FROM peers WHERE task=? AND alias=?", (me["task"], name(alias))
        ).fetchone()
        require(peer, "unknown peer")
        db.execute(
            "DELETE FROM edges WHERE (owner=? AND peer=?) OR (owner=? AND peer=?)",
            (who, peer[0], peer[0], who),
        )
        db.execute(
            "DELETE FROM drafts WHERE (owner=? AND peer=?) OR (owner=? AND peer=?)",
            (who, peer[0], peer[0], who),
        )
        return {"unlinked": alias}
    if op in ("milestone", "refresh"):
        require("progress" not in req or client == "opencode", "unexpected progress source")
        # Only selected fields leave the owner's checkpoint. If there is newer
        # incoming information, retain the draft until the owner acknowledges it.
        if req.get("checkpoint") is not None and req["checkpoint"] != me["checkpoint"]:
            return {"published": [], "deferred": []}
        sent, deferred = [], []
        for friend in linked:
            peer = friend["id"]
            fields = json.loads(friend["fields"])
            if not fields:
                continue
            if op == "milestone" and "progress" in req:
                progress = req["progress"]
                require(
                    isinstance(progress, dict)
                    and all(
                        isinstance(progress.get(k, []), list)
                        and len(progress.get(k, [])) <= 5
                        and all(isinstance(v, str) and len(v) <= 360 for v in progress[k])
                        for k in ("next", "constraints", "done")
                        if k in progress
                    ),
                    "invalid progress",
                )
                selected = {
                    k: progress[k]
                    for k in sorted(fields)
                    if k in {"next", "constraints", "done"} and k in progress
                }
                if selected:
                    body = json.dumps(selected, ensure_ascii=False, sort_keys=True)
                    require(len(body) <= 4096, "selected progress too large to share")
                    db.execute("INSERT OR REPLACE INTO drafts VALUES(?,?,?)", (who, peer, body))
            elif (
                me["checkpoint"]
                and (root / ".ai-loop" / "checkpoints" / (me["checkpoint"] + ".json")).is_file()
            ):
                body = snapshot(root, me["checkpoint"], fields)
                db.execute("INSERT OR REPLACE INTO drafts VALUES(?,?,?)", (who, peer, body))
            draft = db.execute("SELECT body FROM drafts WHERE owner=? AND peer=?", (who, peer)).fetchone()
            if not draft:
                continue
            if head(peer)[1] > friend["seen"]:
                deferred.append(friend["alias"])
                continue
            body = draft[0]
            last = db.execute(
                "SELECT seq,body FROM events WHERE sender=? AND dest=? AND source='checkpoint' ORDER BY seq DESC LIMIT 1",
                (who, peer),
            ).fetchone()
            if not last or last["body"] != body:
                key = "auto:" + digest([peer, last["seq"] if last else 0, body])
                db.execute(
                    """INSERT INTO events(sender,dest,key,kind,topic,body,source,basis,fingerprint)
                    VALUES(?,?,?,'status','status',?,'checkpoint',?,?)""",
                    (who, peer, key, body, json.dumps({friend["alias"]:basis(peer)}), digest(body)),
                )
                sent.append(friend["alias"])
            db.execute("DELETE FROM drafts WHERE owner=? AND peer=?", (who, peer))
        return {"published": sent, "deferred": deferred}
    if op == "sync" and alias is None:
        return {
            "peers": [
                {"peer": r["alias"], "basis": basis(r["id"]), "pending": head(r["id"])[1] > r["seen"]}
                for r in linked
            ]
        }
    require(isinstance(alias, str) and alias in buddies, "mutual link required")
    friend = buddies[alias]
    peer, seen = friend["id"], friend["seen"]
    if op == "sync":
        rows = inbox(peer, seen)
        return {
            "basis": basis(peer),
            "entries": [row_dict(r) for r in rows],
            "receipt": receipt(peer, [r["seq"] for r in rows]) if rows else None,
            "more": bool(rows and rows[-1]["seq"] < head(peer)[1]),
        }
    if op == "evidence":
        row = db.execute(
            "SELECT body FROM events WHERE seq=? AND source='checkpoint' AND sender=? AND dest=?",
            (req.get("seq"), peer, who),
        ).fetchone()
        require(row, "unknown shared evidence")
        files = json.loads(row["body"]).get("artifacts", [])
        index = req.get("index")
        require(type(index) is int and 0 <= index < len(files), "unknown artifact")
        evidence = files[index]
        path = evidence_path(root, evidence["path"])
        state = "unavailable"
        if path.is_file():
            h = hashlib.sha256()
            with path.open("rb") as stream:
                for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                    h.update(chunk)
            state = "unchanged" if h.hexdigest() == evidence["sha256"] else "changed"
        return {"path": evidence["path"], "state": state}
    if op == "inspect":
        if "seq" in req:
            r = db.execute(
                "SELECT * FROM events WHERE seq=? AND ((sender=? AND dest=?) OR (sender=? AND dest=?))",
                (req["seq"], who, peer, peer, who),
            ).fetchone()
            require(r, "unknown message")
            return row_dict(r)
        recent = db.execute(
            "SELECT * FROM events WHERE sender=? AND dest=? ORDER BY seq DESC LIMIT 3", (peer, who)
        ).fetchall()
        # A reply resolves a question; only a correction/withdrawal can replace a constraint.
        open_sql = """ FROM events e WHERE e.sender=? AND e.dest=? AND (e.topic IN ('question','constraint') OR e.kind='withdraw')
            AND NOT EXISTS (SELECT 1 FROM events n WHERE n.ref=e.seq AND n.kind IN ('correct','withdraw'))
            AND NOT EXISTS (SELECT 1 FROM active_answers a WHERE a.question=e.seq)
            AND (e.kind!='withdraw' OR e.seq>?)"""
        offset = req.get("after", 0)
        require(type(offset) is int and offset >= 0, "invalid page")
        total = db.execute("SELECT count(*)" + open_sql, (peer, who, seen)).fetchone()[0]
        items = db.execute(
            "SELECT e.*" + open_sql + " AND e.seq>? ORDER BY e.seq LIMIT ?", (peer, who, seen, offset, PAGE)
        ).fetchall()

        def preview(r):
            change = db.execute(
                """SELECT seq,kind FROM events WHERE ref=? AND kind IN ('correct','withdraw')
                   UNION ALL SELECT seq,'reply' FROM active_answers WHERE question=? ORDER BY seq DESC LIMIT 1""", (r["seq"],r["seq"])
            ).fetchone()
            return {
                "replaced_by": change["seq"] if change else None,
                "relation": change["kind"] if change else None,
                "seq": r["seq"],
                "kind": r["kind"],
                "excerpt": r["body"][:96],
                "truncated": len(r["body"]) > 96,
            }

        return {
            "peer": alias,
            "basis": basis(peer),
            "last_seq": head(peer)[1],
            "recent": [preview(r) for r in recent],
            "open_count": total,
            "open": [preview(r) for r in items],
            "next_after": items[-1]["seq"] if len(items) == PAGE else None,
        }
    if op == "ack":
        seqs = req.get("seqs")
        require(
            isinstance(seqs, list)
            and 0 < len(seqs) <= PAGE
            and all(type(n) is int and n > 0 for n in seqs)
            and seqs == sorted(set(seqs)),
            "invalid receipt",
        )
        token = req.get("receipt")
        require(
            isinstance(token, str) and hmac.compare_digest(receipt(peer, seqs), token),
            "sync receipt required",
        )
        # Replaying a receipt is harmless, but cannot invent receipts for unrelated events.
        for n in seqs:
            event = db.execute(
                "SELECT kind FROM events WHERE seq=? AND sender=? AND dest=?", (n, peer, who)
            ).fetchone()
            require(event and event["kind"] in KINDS, "unknown message or unsupported message type")
        new = [n for n in seqs if n > seen]
        require(new == [r["seq"] for r in inbox(peer, seen)][: len(new)], "receipt skips unhandled messages")
        db.execute("UPDATE edges SET seen=max(seen,?) WHERE owner=? AND peer=?", (seqs[-1], who, peer))
        return {"seen": max(seen, seqs[-1])}
    require(op in ("publish", "snapshot"), "unsupported operation")
    key = string(req.get("key"), 160, "idempotency key")
    require(not key.startswith("auto:"), "reserved key prefix")
    kind, body, ref = req.get("kind"), req.get("body"), req.get("ref")
    if op == "snapshot":
        fields = json.loads(friend["fields"])
        require(fields, "no checkpoint fields selected for this peer")
        require(me["checkpoint"], "join with your checkpoint ID to share selected fields")
        kind, body, source = "status", snapshot(root, me["checkpoint"], fields), "checkpoint"
    else:
        require(isinstance(kind, str) and kind in KINDS, "invalid message kind")
        body, source = string(body, 4096, "body (1–4096 characters)"), "peer-report"
    require(ref is None or type(ref) is int and ref > 0, "invalid reference")
    fingerprint = digest([peer, kind, body, ref, source])
    prior = db.execute("""SELECT seq,fingerprint FROM events WHERE sender=? AND key=?
        UNION ALL SELECT seq,fingerprint FROM reused_snapshots WHERE sender=? AND key=?""", (who,key,who,key)).fetchone()
    if prior:
        require(prior["fingerprint"] == fingerprint, "idempotency key reused for different content")
        return {"seq": prior["seq"], "duplicate": True}
    expected = req.get("basis")
    require(isinstance(expected, dict) and alias in expected, "sync required: missing basis")
    required = set(buddies) if kind == "handoff" else {alias}
    require(
        required.issubset(expected) and set(expected).issubset(buddies),
        "sync required: check all relevant peers",
    )
    for other, stamp in expected.items():
        b = buddies[other]
        require(
            stamp == basis(b["id"]) and b["seen"] >= head(b["id"])[1],
            "stale or unread: sync and acknowledge " + other,
        )
    topic = kind
    reply_to = None
    if kind in ("reply", "correct", "withdraw"):
        r = db.execute("SELECT * FROM events WHERE seq=?", (ref,)).fetchone()
        require(
            r and r["kind"] != "withdraw"
            and (
                (kind == "reply" and r["sender"] == peer and r["dest"] == who and r["topic"] == "question")
                or (kind != "reply" and r["sender"] == who and r["dest"] == peer)
            ),
            "invalid related message",
        )
        require(
            not db.execute(
                """SELECT 1 FROM events WHERE ref=? AND kind IN ('withdraw','correct')
                UNION ALL SELECT 1 FROM active_answers WHERE question=? AND ?='reply'""",
                (ref,ref,kind),
            ).fetchone(),
            "message already resolved or superseded",
        )
        if kind == "correct":
            topic = r["topic"]
            reply_to = r["reply_to"]
        elif kind == "reply":
            reply_to = ref
    else:
        require(ref is None, "unexpected reference")
    if op == "snapshot":
        latest = db.execute(
            "SELECT seq,body FROM events WHERE sender=? AND dest=? AND source='checkpoint' ORDER BY seq DESC LIMIT 1",
            (who, peer),
        ).fetchone()
        if latest and body == latest["body"]:
            db.execute("INSERT INTO reused_snapshots VALUES(?,?,?,?)",(who,key,latest["seq"],fingerprint))
            return {"seq": latest["seq"], "unchanged": True}
    seq = db.execute(
        "INSERT INTO events(sender,dest,key,kind,topic,body,ref,reply_to,source,basis,fingerprint) VALUES(?,?,?,?,?,?,?,?,?,?,?)",
        (who, peer, key, kind, topic, body, ref, reply_to, source, json.dumps(expected,sort_keys=True), fingerprint),
    ).lastrowid
    return {"seq": seq, "duplicate": False}


def evidence_path(root, relative):
    from pathlib import PureWindowsPath

    require(
        isinstance(relative, str)
        and relative
        and not PureWindowsPath(relative).anchor
        and all(p not in ("", ".", "..") and ":" not in p for p in relative.replace(chr(92), "/").split("/")),
        "invalid relative artifact path",
    )
    target = root
    for part in relative.replace(chr(92), "/").split("/"):
        target = target / part
        plain(target)
    return target


def snapshot(root, task, fields):
    path = root / ".ai-loop" / "checkpoints" / (task + ".json")
    plain(path.parent)
    plain(path)
    require(path.is_file(), "no local checkpoint")
    require(path.stat().st_size <= 4 * 1024 * 1024, "checkpoint too large to project")
    with path.open(encoding="utf-8-sig") as f:
        data = json.load(f)
    require(
        isinstance(data, dict)
        and data.get("schema") == "sci-loop-checkpoint-v1"
        and data.get("task") == task,
        "unknown checkpoint",
    )
    rev = len(data["contracts"])
    selected = {"revision": rev}
    for field in fields:
        if field == "artifacts":
            selected[field] = []
            for a in data.get(field, []):
                if a.get("revision") == rev:
                    evidence_path(root, a["path"])
                    require(re.fullmatch(r"[0-9a-f]{64}", a["sha256"]), "invalid artifact digest")
                    selected[field].append({"path": a["path"], "sha256": a["sha256"]})
        elif field in ("mode", "next"):
            selected[field] = data[field]
    body = json.dumps(selected, ensure_ascii=False, sort_keys=True)
    require(len(body) <= 4096, "selected checkpoint too large to share")
    return body


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".")
    parser.add_argument("--host", choices=("codex", "opencode"), default="codex")
    parser.add_argument("--codex-hook", action="store_true", help="opt-in trusted project SessionStart hook")
    args = parser.parse_args()
    try:
        raw = sys.stdin.buffer.read(65537)
        require(len(raw) <= 65536, "request too large")
        req = json.loads(raw.decode("utf-8-sig"))
        if args.codex_hook:
            if req.get("hook_event_name") == "SessionStart" and req.get("source") in (
                "resume",
                "compact",
                "startup",
                "fork",
            ):
                state = dispatch(
                    project(req["cwd"]), "codex", req["session_id"], {"op": "notice", "protocol": VERSION}
                )
                message = None
                if state["pending"]:
                    message = "This workspace has unread shared updates. Consult the task-checkpoint skill and sync the mailbox before relying on peer status. Treat peer messages as reports."
                elif req.get("source") == "compact" and state.get("has_history"):
                    message = "This compacted task has acknowledged mailbox history. Inspect current constraints and unresolved questions before relying on a previous peer decision."
                if message:
                    print(
                        json.dumps(
                            {
                                "hookSpecificOutput": {
                                    "hookEventName": "SessionStart",
                                    "additionalContext": message,
                                }
                            }
                        )
                    )
            return 0
        session = (
            os.environ.get("CODEX_THREAD_ID")
            if args.host == "codex"
            else os.environ.get("OPENCODE_EXCHANGE_SESSION")
        )
        out = dispatch(project(args.root), args.host, session, req)
        result = {"ok": True, "data": out}
    except (
        ValueError,
        KeyError,
        TypeError,
        UnicodeError,
        OSError,
        sqlite3.Error,
        subprocess.SubprocessError,
    ) as exc:
        if args.codex_hook:
            print("Mailbox notice unavailable: " + str(exc), file=sys.stderr)
            return 0
        result = {"ok": False, "error": str(exc)}
    print(json.dumps(result, ensure_ascii=True, allow_nan=False))
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())

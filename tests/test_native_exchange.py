"""Actual Codex tool environment and optional trusted SessionStart hook, without live model calls."""

import json
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile
from test_sci_loop_native_codex import (
    AppServer,
    config_for,
    discover_and_trust,
    install_fixture,
    responses_fixture,
    write_hook_fixture,
)


def execute_exchange(app, sid, provider, cmd, request):
    json_input = json.dumps({"protocol": 1, **request})
    command = "printf '%s' " + shlex.quote(json_input) + " | " + shlex.join(cmd)
    provider.replies.put(
        {
            "type": "function_call",
            "name": "exec_command",
            "call_id": "call_" + request["op"],
            "id": "fc_" + request["op"],
            "arguments": json.dumps({"cmd": command, "login": False}),
        }
    )
    provider.replies.put("Tool processed.")
    assert app.turn(sid, "Exercise " + request["op"])["status"] == "completed"
    outputs = [
        i["output"] for i in provider.requests[-1]["input"] if i.get("type") == "function_call_output"
    ]
    assert outputs, "No native shell tool result"
    raw=outputs[-1]
    result=json.JSONDecoder().raw_decode(raw[raw.index('{"ok":'):])[0]
    assert result["ok"],result
    return result["data"]


def verify():
    executable = shutil.which("codex")
    with tempfile.TemporaryDirectory(prefix="native-mailbox-") as tmp, responses_fixture() as provider:
        root = Path(tmp).resolve()
        workspace = root / "workspace"
        workspace.mkdir()
        env, config = config_for(root, provider)
        config.write_text(
            config.read_text().replace('sandbox_mode = "read-only"', 'sandbox_mode = "workspace-write"')
        )
        installed = install_fixture(executable, root, env)
        cmd = [sys.executable, "-IB", str(installed / "scripts/exchange.py")]
        write_hook_fixture(config.parent, root, shlex.join([*cmd, "--codex-hook"]))
        discover_and_trust(executable, workspace, env, config, installed)

        def as_peer(**request):
            result = subprocess.run(
                [*cmd, "--host", "opencode"],
                cwd=workspace,
                env={**env, "OPENCODE_EXCHANGE_SESSION": "fixture"},
                input=json.dumps({"protocol": 1, **request}).encode(),
                capture_output=True,
                check=True,
            )
            return json.loads(result.stdout)["data"]

        as_peer(op="join", alias="main")
        with AppServer(executable, workspace, env) as app:
            app.initialize()
            sid = app.call("thread/start", cwd=str(workspace))["thread"]["id"]
            execute_exchange(app, sid, provider, cmd, {"op": "join", "alias": "review"})
            execute_exchange(app, sid, provider, cmd, {"op": "link", "peer": "main"})
            as_peer(op="link", peer="review")
            basis = as_peer(op="sync", peer="review")["basis"]
            as_peer(
                op="publish",
                kind="question",
                key="q",
                body="UNTRUSTED_REMOTE_BODY",
                peer="review",
                basis={"review": basis},
            )
            provider.replies.put("Local summary.")
            app.compact(sid)
            provider.replies.put("Continued.")
            assert app.turn(sid, "After compaction")["status"] == "completed"
            compact_request = str(provider.requests[-1]["input"])
            assert (
                "unread shared updates" in compact_request and "UNTRUSTED_REMOTE_BODY" not in compact_request
            ), compact_request[-800:]
        with AppServer(executable, workspace, env) as app:
            app.initialize()
            app.call("thread/resume", threadId=sid, cwd=str(workspace))
            provider.replies.put("Resumed.")
            assert app.turn(sid, "After restart")["status"] == "completed"
            assert "unread shared updates" in str(provider.requests[-1]["input"])
            execute_exchange(app, sid, provider, cmd, {"op": "sync", "peer": "main"})
            assert "UNTRUSTED_REMOTE_BODY" in str(provider.requests[-1]["input"])
        print(
            "Codex supplied the identity to its actual shell tool. Compact and resume delivered only the fixed notice; manual sync retrieved the private fixture body."
        )


if __name__ == "__main__":
    verify()

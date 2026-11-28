#!/usr/bin/env python3
"""Run a native Codex integration check with an isolated home and mock Responses.

The fixture supplies canned model replies and compaction summaries. Assertions
exercise Codex transport, persistence and installed checkpoint commands.

Requires a POSIX host, Python 3.9+, Git, a supported Codex binary, and loopback.
Invoke with python3 -B tests/test_sci_loop_native_codex.py [--codex PATH].
"""

from __future__ import annotations

import argparse
import json
import os
import queue
import shlex
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from contextlib import contextmanager
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PLUGIN_NAME = "codex-sci-loop"
MARKETPLACE_FILE = Path(".agents/plugins/marketplace.json")
PLUGIN_SKILLS = {"task-checkpoint", "research-verification"}
ORIGINAL = "EARLY_USER_CONSTRAINT_7b63d\n目标：按最小二乘法拟合原始观测。设误差 ε < 0.01。\n"
REVISED = "REVISED_USER_CONSTRAINT_a13f1\r\n撤销最小二乘，使用稳健中位数。保留阈值 ε < 0.01。\r\n"
DECISION = "记录修订：排除最小二乘，改用稳健中位数。"
NEXT = "在独立输入上核对残差阈值。"
OLD_NEXT = "为最小二乘准备原始观测。"
REPLACED_NEXT = "在原始观测上计算最小二乘残差。"
COMPLETED = "已准备原始观测。"
ACTION_MARKER = "prepared original observations\n"
RECENT = "RECENT_USER_CONSTRAINT_6da58"
FIRST_REPLY = "UNCOMPRESSED_ASSISTANT_409ec"
FOLLOWUP_REPLY = "FOLLOWUP_AFTER_STOP_43189"
SUMMARIES = ("MOCK_COMPACTION_SUMMARY_253cd", "SECOND_COMPACTION_SUMMARY_0584b")
BETWEEN = "CONTINUE_BETWEEN_COMPACTIONS_1f080"
CONTINUE = "STOP_CONTINUATION_e11dd"
RESUME = "AFTER_PROCESS_RESTART_94ca5"
FRESH = "FRESH_THREAD_WITH_PROJECT_FILES_29bbe"
INITIAL_CONTEXT = "INITIAL_PROJECT_CONTEXT_3ade7"
UPDATED_CONTEXT = "UPDATED_PROJECT_CONTEXT_21b00"


class ResponsesFixture(BaseHTTPRequestHandler):
    def log_message(self, *_args):
        pass

    def do_POST(self):
        if self.path != "/v1/responses":
            self.send_error(404)
            return
        body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        self.server.requests.append(body)
        try:
            message = self.server.replies.get_nowait()
        except queue.Empty:
            self.send_error(500, "unexpected model request")
            return
        response_id = f"resp-{len(self.server.requests)}"
        events = (
            {"type": "response.created", "response": {"id": response_id}},
            {
                "type": "response.output_item.done",
                "item": {
                    "type": "message",
                    "role": "assistant",
                    "id": f"msg-{response_id}",
                    "content": [{"type": "output_text", "text": message}],
                },
            },
            {
                "type": "response.completed",
                "response": {
                    "id": response_id,
                    "usage": {"input_tokens": 10, "output_tokens": 2, "total_tokens": 12},
                },
            },
        )
        if isinstance(message,dict):
            events[1]["item"]=message
        payload = "".join(f"event: {event['type']}\ndata: {json.dumps(event)}\n\n" for event in events).encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)


@contextmanager
def responses_fixture():
    with HTTPServer(("127.0.0.1", 0), ResponsesFixture) as server:
        server.requests = []
        server.replies = queue.Queue()
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            yield server
        finally:
            server.shutdown()
            thread.join()


class AppServer:
    def __init__(self, executable: str, workspace: Path, env: dict[str, str]):
        self.executable = executable
        self.workspace = workspace
        self.env = env
        self.messages = queue.Queue()
        self.events = []
        self.request_id = 0

    def __enter__(self):
        self.stderr = tempfile.TemporaryFile(mode="w+t", encoding="utf-8")
        self.process = subprocess.Popen(
            [self.executable, "app-server", "--stdio"],
            cwd=self.workspace,
            env=self.env,
            text=True,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=self.stderr,
        )
        self.reader = threading.Thread(target=self.read_lines, daemon=True)
        self.reader.start()
        return self

    def __exit__(self, *_exc):
        self.process.stdin.close()
        try:
            self.process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.process.kill()
            self.process.wait(timeout=5)
        self.reader.join(timeout=5)
        self.process.stdout.close()
        self.stderr.close()

    def read_lines(self):
        for line in self.process.stdout:
            self.messages.put(line)
        self.messages.put(None)

    def send(self, message):
        self.process.stdin.write(json.dumps(message) + "\n")
        self.process.stdin.flush()

    def wait_for(self, predicate, label, *, since=None, timeout=25):
        if since is not None:
            for event in self.events[since:]:
                if predicate(event):
                    return event
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            try:
                line = self.messages.get(timeout=max(0.0, deadline - time.monotonic()))
            except queue.Empty:
                break
            if line is None:
                break
            message = json.loads(line)
            if "method" in message:
                self.events.append(message)
            if predicate(message):
                return message
        self.stderr.seek(0)
        raise AssertionError(f"No {label}. Recent methods: {[e['method'] for e in self.events[-18:]]}\n{self.stderr.read()[-3000:]}")

    def call(self, method, **params):
        self.request_id += 1
        request_id = self.request_id
        self.send({"id": request_id, "method": method, "params": params})
        response = self.wait_for(lambda event: event.get("id") == request_id, method)
        assert "result" in response, (method, response)
        return response["result"]

    def initialize(self):
        self.call(
            "initialize",
            clientInfo={"name": "sci-loop-native-test", "version": "1.0.0"},
            capabilities={"experimentalApi": True},
        )
        self.send({"method": "initialized"})

    def turn(self, thread_id, prompt, *, skill=None):
        inputs = [{"type": "text", "text": prompt}]
        if skill is not None:
            inputs.append({"type": "skill", "name": skill["name"], "path": skill["path"]})
        response = self.call("turn/start", threadId=thread_id, input=inputs)
        return self.completed(thread_id, response["turn"]["id"])

    def completed(self, thread_id, turn_id=None):
        def matching_turn(event):
            if event.get("method") != "turn/completed":
                return False
            params = event["params"]
            return params["threadId"] == thread_id and (turn_id is None or params["turn"]["id"] == turn_id)

        event = self.wait_for(matching_turn, "turn/completed", since=0)
        return event["params"]["turn"]

    def compact(self, thread_id):
        start_index = len(self.events)
        assert self.call("thread/compact/start", threadId=thread_id) == {}

        def is_compaction(event, method):
            return (event.get("method") == method and event["params"]["threadId"] == thread_id
                    and event["params"]["item"]["type"] == "contextCompaction")

        for method in ("item/started", "item/completed"):
            item = self.wait_for(lambda event: is_compaction(event, method), method, since=start_index)
        turn = self.completed(thread_id, item["params"]["turnId"])
        assert turn["status"] == "completed", turn


def config_for(fixture: Path, provider: HTTPServer) -> tuple[dict[str, str], Path]:
    home = fixture / "home"
    home.mkdir()
    config = home / "config.toml"
    loopback = f"http://127.0.0.1:{provider.server_port}"
    config.write_text(
        f'''model = "gpt-5.3-codex"
model_provider = "sci_loop_fixture"
approval_policy = "never"
sandbox_mode = "read-only"
web_search = "disabled"
chatgpt_base_url = "{loopback}"
cli_auth_credentials_store = "file"
model_auto_compact_token_limit = 150000
model_post_turn_compact_threshold_percent = 0
compact_prompt = "SYNTHETIC_MANUAL_COMPACTION"
[features]
apps = false
hooks = true
plugins = true
[analytics]
enabled = false
[model_providers.sci_loop_fixture]
name = "Sci Loop Local Fixture"
base_url = "{loopback}/v1"
wire_api = "responses"
supports_websockets = false
request_max_retries = 0
stream_max_retries = 0
''',
        encoding="utf-8",
    )
    env = {
        "HOME": str(home),
        "CODEX_HOME": str(home),
        "CODEX_APP_SERVER_DISABLE_MANAGED_CONFIG": "1",
        "GIT_CONFIG_NOSYSTEM": "1",
        "GIT_CONFIG_GLOBAL": os.devnull,
        "PATH": os.environ.get("PATH", os.defpath),
        "PYTHONDONTWRITEBYTECODE": "1",
        "NO_PROXY": "127.0.0.1",
        "OPENAI_BASE_URL": f"{loopback}/v1",
    }
    for protocol in ("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY"):
        env[protocol] = "http://127.0.0.1:1"
    return env, config


def install_fixture(executable: str, fixture: Path, env: dict[str, str]) -> Path:
    marketplace = fixture / "marketplace"
    manifest = marketplace / MARKETPLACE_FILE
    manifest.parent.mkdir(parents=True)
    shutil.copyfile(ROOT / MARKETPLACE_FILE, manifest)
    marketplace_name = json.loads(manifest.read_text(encoding="utf-8"))["name"]
    source = ROOT / "plugins" / PLUGIN_NAME
    shutil.copytree(source, marketplace / "plugins" / PLUGIN_NAME, ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))

    def cli(*args):
        result = subprocess.run([executable, *args], cwd=fixture, env=env, capture_output=True, text=True, timeout=20)
        assert result.returncode == 0, (args, result.stderr, result.stdout)
        return result.stdout.strip()

    version = cli("--version")
    added = json.loads(cli("plugin", "marketplace", "add", str(marketplace), "--json"))
    assert added["marketplaceName"] == marketplace_name, added
    plugin_id = f"{PLUGIN_NAME}@{marketplace_name}"
    installed = json.loads(cli("plugin", "add", plugin_id, "--json"))
    assert installed["pluginId"] == plugin_id, installed
    installed_path = Path(installed["installedPath"])
    assert installed_path.is_relative_to(Path(env["CODEX_HOME"]) / "plugins" / "cache"), installed
    print(f"{version}: installed {installed['pluginId']} {installed['version']} in isolated cache", flush=True)
    return installed_path


def write_hook_fixture(home: Path, fixture: Path, exchange_hook=None):
    script = fixture / "lifecycle_hook.py"
    script.write_text(
        f'''import json
import sys
from pathlib import Path

event = json.load(sys.stdin)
with Path({str(fixture / 'hook-events.jsonl')!r}).open("a", encoding="utf-8") as stream:
    stream.write(json.dumps(event) + "\\n")
if event["hook_event_name"] == "Stop" and event["last_assistant_message"] == {FIRST_REPLY!r}:
    print({CONTINUE!r}, file=sys.stderr)
    sys.exit(2)
if event["hook_event_name"] == "Stop" and event["last_assistant_message"] == {FOLLOWUP_REPLY!r}:
    print(json.dumps({{"continue": False, "stopReason": "fixture stop after continuation"}}))
else:
    print("{{}}")
''',
        encoding="utf-8",
    )
    command = shlex.join([sys.executable, str(script)])
    events = ("SessionStart", "UserPromptSubmit", "PreCompact", "PostCompact", "Stop")
    hooks = {event: [{"hooks": [{"type": "command", "command": command}]}] for event in events}
    if exchange_hook:
        hooks["SessionStart"].append({"hooks":[{"type":"command","command":exchange_hook}]})
    (home / "hooks.json").write_text(json.dumps({"hooks": hooks}), encoding="utf-8")


def discover_and_trust(executable: str, workspace: Path, env: dict[str, str], config: Path, installed: Path):
    with AppServer(executable, workspace, env) as app:
        app.initialize()
        discovery = app.call("hooks/list", cwds=[str(workspace)])
        skills = app.call("skills/list", cwds=[str(workspace)])
    hooks = discovery["data"][0]["hooks"]
    plugin_hooks = [hook for hook in hooks if Path(hook["sourcePath"]).is_relative_to(installed)]
    assert not plugin_hooks, plugin_hooks
    plugin_skills = {
        skill["name"].removeprefix(f"{PLUGIN_NAME}:"): skill
        for skill in skills["data"][0]["skills"]
        if Path(skill["path"]).is_relative_to(installed)
    }
    assert set(plugin_skills) == PLUGIN_SKILLS, list(plugin_skills)
    with config.open("a", encoding="utf-8") as stream:
        for hook in hooks:
            if hook["sourcePath"] != str(config.parent / "hooks.json"):
                continue
            assert hook["trustStatus"] == "untrusted", hook
            stream.write(f'\n[hooks.state.{json.dumps(hook["key"])}]\ntrusted_hash = {json.dumps(hook["currentHash"])}\n')
    print(f"Discovered {', '.join(sorted(plugin_skills))} and zero packaged lifecycle hooks", flush=True)
    return plugin_skills


def messages(request, role=None):
    return [part["text"] for item in request["input"] if role is None or item.get("role") == role
            for part in item.get("content", ()) if "text" in part]


def verify_skill_loading(app, provider, workspace, skill):
    skill_file = Path(skill["path"])
    body = skill_file.read_text(encoding="utf-8").split("\n---\n", 1)[1].strip()
    body_lines = [line for line in body.splitlines() if len(line.strip()) >= 40]
    assert body_lines, "Expected substantive research skill instructions"

    thread_id = app.call("thread/start", cwd=str(workspace))["thread"]["id"]
    start = len(provider.requests)
    routine = "Make a short checklist for preparing a meeting room."
    research = f"${skill['name']} Check whether a claimed numerical convergence rate survives grid refinement."
    assert app.turn(thread_id, routine)["status"] == "completed"
    assert app.turn(thread_id, research, skill=skill)["status"] == "completed"
    daily_request, research_request = provider.requests[start:]

    assert routine in messages(daily_request, "user")
    daily_text = "\n".join((daily_request.get("instructions") or "", *messages(daily_request)))
    assert all(line not in daily_text for line in body_lines), "Research instructions appeared during the ordinary turn"
    assert research in messages(research_request, "user")
    research_text = "\n".join((research_request.get("instructions") or "", *messages(research_request)))
    assert body in research_text, "Explicit skill input did not inject the installed research instructions"
    print("Ordinary checklist omitted research instructions. Explicit native skill input loaded the installed body.", flush=True)


def assert_no_packaged_hook_runs(app, installed):
    assert not any(event["method"] == "hook/completed"
                   and Path(event["params"]["run"]["sourcePath"]).is_relative_to(installed)
                   for event in app.events)


def checkpoint_cli(installed, *args):
    return [sys.executable, "-B", str(installed / "scripts" / "checkpoint.py"), *args]


def checkpoint(installed, workspace, env, *args, request=None):
    result = subprocess.run(
        checkpoint_cli(installed, *args),
        cwd=workspace, env=env, input=request, capture_output=True, text=True, encoding="utf-8", timeout=20,
    )
    assert result.returncode == 0, (args, result.stdout, result.stderr)
    return result.stdout


def read_checkpoint(app, installed, *args):
    result = app.call("command/exec", command=checkpoint_cli(installed, *args),
                      cwd=str(app.workspace), sandboxPolicy={"type": "workspaceWrite"}, timeoutMs=10000)
    assert result["exitCode"] == 0, result
    return json.loads(result["stdout"])


def recover_checkpoint(app, installed):
    current = read_checkpoint(app, installed, "show", "--full")
    assert (current["request"], current["revision"], current["mode"], current["next"]) == (
        REVISED, 2, "active", NEXT), current
    assert [note["text"] for note in current["notes"]] == [DECISION], current
    assert current["verification"]["status"] == "stale", current

    latest_page = read_checkpoint(app, installed, "history", "--limit", "1", "--full")
    latest, = latest_page["revisions"]
    assert latest_page["current_next"] == NEXT and latest["is_current"], latest_page
    assert latest["contract"]["request"] == REVISED, latest
    older_page = read_checkpoint(app, installed, "history", "--before", str(latest_page["next_before"]),
                                 "--limit", "1", "--full")
    older, = older_page["revisions"]
    assert older_page["next_before"] is None and not older["is_current"], older_page
    assert older["contract"]["request"] == ORIGINAL, older
    done, = older["notes"]
    assert (done["kind"], done["text"], done["source"]) == ("completed", COMPLETED, "operator statement"), done
    assert [(change["previous"], change["next"], change["cause"]) for change in older["pending_changes"]] == [
        ("", OLD_NEXT, "start"), (OLD_NEXT, REPLACED_NEXT, "note"), (REPLACED_NEXT, "", "revise"),
    ], older
    evidence, = older["verification"]
    assert evidence["recorded_status"] == "passed" and "tail" not in evidence, evidence
    return current, latest_page, older_page


def verify(executable: str):
    with tempfile.TemporaryDirectory(prefix="sci-loop-native-") as raw, responses_fixture() as provider:
        fixture = Path(raw).resolve()
        workspace = fixture / "workspace"
        workspace.mkdir()
        control = fixture / "control"
        control.mkdir()
        instructions = workspace / "AGENTS.md"
        instructions.write_text(f"{INITIAL_CONTEXT}\n", encoding="utf-8")
        shutil.copyfile(instructions, control / "AGENTS.md")
        env, config = config_for(fixture, provider)
        for project in (workspace, control):
            subprocess.run(["git", "init", "-q"], cwd=project, env=env, check=True, timeout=10)
        installed = install_fixture(executable, fixture, env)
        write_hook_fixture(config.parent, fixture)
        skills = discover_and_trust(executable, workspace, env, config, installed)
        action_log = fixture / "action.log"
        fixture_check = shlex.join([sys.executable, "-c",
                                    f"with open({str(action_log)!r}, 'a') as f: f.write({ACTION_MARKER!r})"])
        checkpoint(installed, workspace, env, "start", "--request-file", "-", "--next", OLD_NEXT,
                   "--verify-command", fixture_check, request=ORIGINAL)
        checkpoint(installed, workspace, env, "verify")
        checkpoint(installed, workspace, env, "note", "--kind", "completed", "--note", COMPLETED,
                   "--next", REPLACED_NEXT)
        checkpoint(installed, workspace, env, "revise", "--from-revision", "1", "--request-file", "-",
                   "--remove-verifier", "--note", DECISION, "--next", NEXT, request=REVISED)
        state_file = workspace / ".ai-loop/checkpoints/main.json"
        state_bytes = state_file.read_bytes()
        state_mtime = state_file.stat().st_mtime_ns
        assert action_log.read_text() == ACTION_MARKER

        for reply in (FIRST_REPLY, FOLLOWUP_REPLY, "REVISED_ASSISTANT", "RECENT_ASSISTANT",
                      FIRST_REPLY, FOLLOWUP_REPLY, "REVISED_ASSISTANT", "RECENT_ASSISTANT",
                      SUMMARIES[0], "BETWEEN_ASSISTANT", "BETWEEN_ASSISTANT", SUMMARIES[1],
                      "RESUMED_ASSISTANT", "RESUMED_ASSISTANT", "FRESH_ASSISTANT", "CHECKLIST", "RESEARCH_CHECK"):
            provider.replies.put(reply)
        with AppServer(executable, workspace, env) as app:
            app.initialize()
            thread_id = app.call("thread/start", cwd=str(workspace))["thread"]["id"]
            stopped = app.turn(thread_id, ORIGINAL)
            assert stopped["status"] == "completed", stopped
            assert len(provider.requests) == 2, "Stop exit 2 must make one continuation request"
            assert any(CONTINUE in text for text in messages(provider.requests[1], "user"))
            assert app.turn(thread_id, REVISED)["status"] == "completed"
            large_prompt = "oversized local retention fixture " * 3000 + RECENT
            assert app.turn(thread_id, large_prompt)["status"] == "completed"
            control_id = app.call("thread/start", cwd=str(control))["thread"]["id"]
            assert app.turn(control_id, ORIGINAL)["status"] == "completed"
            assert app.turn(control_id, REVISED)["status"] == "completed"
            assert app.turn(control_id, large_prompt)["status"] == "completed"
            instructions.write_text(f"{UPDATED_CONTEXT}\n", encoding="utf-8")
            shutil.copyfile(instructions, control / "AGENTS.md")
            app.compact(thread_id)
            assert app.turn(thread_id, BETWEEN)["status"] == "completed"
            assert app.turn(control_id, BETWEEN)["status"] == "completed"
            app.compact(thread_id)
            assert len(provider.requests) == 12
            assert_no_packaged_hook_runs(app, installed)

        with AppServer(executable, workspace, env) as app:
            app.initialize()
            resumed = app.call("thread/resume", threadId=thread_id, cwd=str(workspace))
            assert resumed["thread"]["id"] == thread_id
            recovered = recover_checkpoint(app, installed)
            assert not (control / ".ai-loop").exists()
            assert app.turn(thread_id, RESUME)["status"] == "completed"
            assert app.call("thread/resume", threadId=control_id, cwd=str(control))["thread"]["id"] == control_id
            assert app.turn(control_id, RESUME)["status"] == "completed"
            assert len(provider.requests) == 14
            fresh_id = app.call("thread/start", cwd=str(workspace))["thread"]["id"]
            assert fresh_id != thread_id and app.turn(fresh_id, FRESH)["status"] == "completed"
            assert recover_checkpoint(app, installed) == recovered
            verify_skill_loading(app, provider, control, skills["research-verification"])
            assert_no_packaged_hook_runs(app, installed)

        assert state_file.read_bytes() == state_bytes and state_file.stat().st_mtime_ns == state_mtime
        assert action_log.read_text() == ACTION_MARKER, "The original verifier ran more than once"
        assert len(provider.requests) == 17 and provider.replies.empty()
        fresh_user = messages(provider.requests[14], "user")
        assert FRESH in fresh_user and all(ORIGINAL.splitlines()[0] not in text
                                           and REVISED.splitlines()[0] not in text
                                           and all(summary not in text for summary in SUMMARIES) for text in fresh_user)
        assert ORIGINAL in messages(provider.requests[0], "user")
        for index in (8, 11):
            assert any("SYNTHETIC_MANUAL_COMPACTION" in text for text in messages(provider.requests[index], "user"))
        assert any(SUMMARIES[0] in text for text in messages(provider.requests[9], "user"))
        resumed_user = messages(provider.requests[12], "user")
        assert any(RECENT in text for text in resumed_user)
        assert any("tokens truncated" in text for text in resumed_user)
        assert any(SUMMARIES[1] in text for text in resumed_user)
        assert all(ORIGINAL.splitlines()[0] not in text and REVISED.splitlines()[0] not in text for text in resumed_user)
        assert FIRST_REPLY not in messages(provider.requests[12], "assistant")
        assert RESUME in resumed_user
        assert any(UPDATED_CONTEXT in text for text in resumed_user)
        control_user = messages(provider.requests[13], "user")
        assert ORIGINAL in control_user and REVISED in control_user and large_prompt in control_user and RESUME in control_user
        assert FIRST_REPLY in messages(provider.requests[13], "assistant")
        assert all(summary not in text for summary in SUMMARIES for text in control_user)
        hook_events = [json.loads(line) for line in (fixture / "hook-events.jsonl").read_text().splitlines()]
        assert any(e["hook_event_name"] == "SessionStart" and e["source"] == "resume" for e in hook_events)
        assert any(e["hook_event_name"] == "SessionStart" and e["source"] == "compact" for e in hook_events)
        compact_hooks = [e["hook_event_name"] for e in hook_events if e.get("trigger") == "manual"]
        assert compact_hooks == ["PreCompact", "PostCompact"] * 2, compact_hooks
        print("Native app-server recovered the same checkpoint history after two compactions and restart "
              "and in a fresh thread. The original verifier ran once and reads left the checkpoint untouched.", flush=True)
        print("Compared compacted, uncompressed and fresh-thread prompts using canned loopback model replies.", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--codex", default="codex", help="Codex executable to exercise")
    args = parser.parse_args()
    executable = shutil.which(args.codex)
    if not executable:
        parser.error(f"Codex executable not found: {args.codex}")
    verify(str(Path(executable).resolve()))

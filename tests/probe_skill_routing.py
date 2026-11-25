#!/usr/bin/env python3
"""Observe implicit skill selection in live Codex. Run manually with --live."""

import argparse
import json
import os
import shutil
import tempfile
from pathlib import Path

from test_sci_loop_native_codex import AppServer, install_fixture


CASES = {
    "daily": [
        "周五物理实验室要办读书会，8 人。茶点一共 96 元，便签 12 元，总预算 150 元。每盒茶包 18 元，最多还能买几盒？给我一份三行采购清单。",
    ],
    "derivation": [
        "理想单摆从最大摆角 A 静止释放。有人说振幅增大时，周期比小角近似略短。请从运动方程或能量推导周期的首个振幅修正，判断他说得对不对，并说明 A 的单位和适用范围。",
    ],
    "numerical": [
        "我在比较两种简谐振子时间推进。方案甲用旧的 x、v 同时更新 x 和 v；方案乙先用旧 x 更新 v，再用新的 v 更新 x。取 x'=v，v'=-x，初值 (1,0)，步长 0.1。请实际算 1000 步，比较两者的能量轨迹，看看「算得久也都守恒」这个说法站不站得住。",
    ],
    "transition": [
        "周日下午给六个朋友办读书会。家里有热水壶、杯子、红茶和便签。帮我列一个很短的会前准备清单。",
        "14:30 开场，我想提前半小时泡好茶，开场前十分钟摆杯。把这两条手机提醒的标题和时间写给我就好。",
        "沿用这壶茶。室温恒为 20°C，泡好时 80°C，10 分钟后测得 50°C，20 分钟后是 35°C。朋友说每十分钟都降 30°C。请从牛顿冷却方程推导温度随时间的关系，用前两次读数定参数、留下一次检验，推算开场时的温度，并说明这个检验能说明什么。",
    ],
}


def live_turn(app, thread, prompt, skill_path, body_lines):
    start = len(app.events)
    result = app.call("turn/start", threadId=thread, input=[{"type": "text", "text": prompt}])
    turn_id = result["turn"]["id"]

    def matching(event):
        params = event.get("params", {})
        return (event.get("method") == "turn/completed" and params.get("threadId") == thread
                and params.get("turn", {}).get("id") == turn_id)

    turn = app.wait_for(matching, "live turn", since=start, timeout=240)["params"]["turn"]
    if turn["status"] != "completed":
        raise RuntimeError(f"Live turn {turn['status']}: {turn.get('error')}")
    items = [e["params"]["item"] for e in app.events[start:] if e.get("method") == "item/completed"
             and e["params"].get("threadId") == thread and e["params"].get("turnId") == turn_id]
    observations = []
    messages = []
    for item in items:
        if item["type"] == "agentMessage":
            messages.append(item["text"])
            continue
        if item["type"] == "userMessage":
            continue
        if item["type"] == "commandExecution":
            output = item.get("aggregatedOutput") or ""
            observations.append({"type": item["type"], "command": item["command"], "exit": item.get("exitCode"),
                                 "names_skill_file": str(skill_path) in item["command"],
                                 "body_in_output": any(line in output for line in body_lines),
                                 "output_excerpt": output[-1000:]})
        elif item["type"] not in {"reasoning", "plan"}:
            observations.append({"type": item["type"], "detail": item})
    print(json.dumps({"tools": observations, "messages": messages}, ensure_ascii=False), flush=True)


def probe(executable, live):
    with tempfile.TemporaryDirectory(prefix="sci-loop-routing-") as raw:
        root = Path(raw).resolve()
        home = root / "home"
        home.mkdir()
        env = {"HOME": str(home), "CODEX_HOME": str(home), "PATH": os.environ.get("PATH", os.defpath),
               "CODEX_APP_SERVER_DISABLE_MANAGED_CONFIG": "1", "PYTHONDONTWRITEBYTECODE": "1",
               "GIT_CONFIG_GLOBAL": os.devnull, "GIT_CONFIG_NOSYSTEM": "1"}
        for key in ("OPENAI_API_KEY", "HTTPS_PROXY", "HTTP_PROXY", "NO_PROXY", "SSL_CERT_FILE",
                    "CODEX_CA_CERTIFICATE"):
            if key in os.environ:
                env[key] = os.environ[key]
        (home / "config.toml").write_text(
            'cli_auth_credentials_store = "ephemeral"\napproval_policy = "never"\n'
            'sandbox_mode = "read-only"\nweb_search = "disabled"\n'
            '[features]\nplugins = true\napps = false\n'
            '[analytics]\nenabled = false\n', encoding="utf-8")
        installed = install_fixture(executable, root, env)
        with AppServer(executable, root, env) as app:
            app.initialize()
            workspaces = {name: root / name for name in CASES}
            for workspace in workspaces.values():
                workspace.mkdir()
            found = app.call("skills/list", cwds=[str(path) for path in workspaces.values()])["data"]
            skill_path = installed / "skills" / "research-verification" / "SKILL.md"
            assert {row["cwd"] for row in found} == {str(path) for path in workspaces.values()}
            assert all(any(Path(s["path"]) == skill_path and s["enabled"] for s in row["skills"]) for row in found)
            print("Installed research skill is discoverable in every workspace.", flush=True)
            if not live:
                print("Preflight only. No model turns started.")
                return
            if "OPENAI_API_KEY" not in env and not app.call("account/read", refreshToken=False).get("account"):
                login = app.call("account/login/start", type="chatgpt")
                print("Open the local Codex sign-in link to authorize this temporary test:", login["authUrl"],
                      flush=True)

                def matching_login(event):
                    return (event.get("method") == "account/login/completed"
                            and event["params"].get("loginId") == login["loginId"])

                try:
                    notice = app.wait_for(matching_login, "interactive sign-in", timeout=300)
                except AssertionError:
                    raise SystemExit("No login callback received. No live model turns started.") from None
                if not notice["params"]["success"]:
                    raise RuntimeError("The temporary Codex sign-in did not succeed.")
            body = skill_path.read_text(encoding="utf-8").split("\n---\n", 1)[1]
            lines = [line[:90] for line in body.splitlines() if len(line) > 65]
            for name, prompts in CASES.items():
                started = app.call("thread/start", cwd=str(workspaces[name]), ephemeral=True)
                thread = started["thread"]["id"]
                print(json.dumps({"case": name, "model": started["model"], "provider": started["modelProvider"]}),
                      flush=True)
                for i, prompt in enumerate(prompts, start=1):
                    print(f"{name} {i}: {prompt}", flush=True)
                    live_turn(app, thread, prompt, skill_path, lines)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--codex", default="codex")
    parser.add_argument("--live", action="store_true", help="authorize real model usage for four ephemeral chats")
    args = parser.parse_args()
    executable = shutil.which(args.codex)
    if executable is None:
        parser.error("Codex executable not found")
    probe(executable, args.live)

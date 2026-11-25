#!/usr/bin/env python3
"""Observe implicit skill selection in live Codex. Run manually with --live.

Usage is the latest model call observed within each turn, as reported by app-server.
"""

import argparse
import hashlib
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


FOLLOWUP_CASES = {
    "covariance": ["同事说，对同一量测 n 次取平均，标准误总会变成单次的 1/√n。设每次方差都是 σ²，任意两次的相关系数都是 ρ。你能从协方差把结论推出来，说明同事的话何时成立，并检查 ρ=1 的情形吗？"],
    "conduction": ["一块厚度为 L 的平板，左右端保持在 T_h 和 T_c，T_h>T_c。材料的热导率是 k(T)=k₀(1+αT)。有人在稳态热流公式中直接用热端的热导率。请从一维无热源的导热方程算出热流密度，并说明什么时候这个替代才合理。"],
    "tickets": ["科学馆的‘误差与测量’展每张票 48 元，每 4 张只收 3 张的钱，不足 4 张按原价。我们买 10 张，一共多少钱？写一个算式和金额就好。"],
    "agenda": ["我要排版会议议程，把‘验证实验假设、检查适用条件、记录推导结论’各改成一个四字栏目标题，只给我三个标题。"],
    "shelf": [
        "社区交换书架今天先定到这里：总预算不超过 730 元，放在南门门厅，材料只用现有旧木板。等周三再请物业确认消防通道宽度。我周五会换个对话接着办，不想从头再讲一遍。这个项目的文件夹是 {folder}。",
        "物业刚回复。南门方案取消，改放东侧连廊，预算也收紧到 620 元。原先问消防通道宽度的待办撤销，下一步换成周四请木工量墙。其他照旧，周五按这版往下办。",
    ],
    "handoff": ["接着上次的社区交换书架安排。项目文件夹是 {folder}。请告诉我现在定下来的预算、地点、材料，以及接下来要办的那一件事。"],
    "move": ["最近在安排搬家，项目文件夹是 {folder}。打包约了周六上午九点，搬运费上限 860 元，押金要留现金。第二家的报价周三才到，到了再选搬运公司。今天先到这儿。"],
    "keys": ["在排下周的社区练习室钥匙交接，事情放在 {folder}。现在定下备用钥匙只放前台，交接时说「石榴42」。管理员发新版值班表前排不了周二的领取人，等她回了再补。咱们这会儿先散。"],
}


def last_model_usage(events, thread_id, turn_id):
    for event in reversed(events):
        params = event.get("params", {})
        if (event.get("method") == "thread/tokenUsage/updated"
                and params.get("threadId") == thread_id and params.get("turnId") == turn_id):
            last = (params.get("tokenUsage") or {}).get("last") or {}
            break
    else:
        last = {}

    usage = {}
    for key in ("inputTokens", "cachedInputTokens"):
        count = last.get(key)
        usage[key] = count if type(count) is int and count >= 0 else "unknown"
    return usage


def live_turn(app, thread, prompt, skill_markers):
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
    events = app.events[start:]
    items = [e["params"]["item"] for e in events if e.get("method") == "item/completed"
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
            named = [path.parent.name for path in skill_markers if str(path) in item["command"]]
            read = [path.parent.name for path, lines in skill_markers.items() if any(line in output for line in lines)]
            observations.append({"type": item["type"], "command": item["command"], "exit": item.get("exitCode"),
                                 "names_skill_file": "research-verification" in named,
                                 "body_in_output": "research-verification" in read,
                                 "skill_paths_in_command": named, "skill_bodies_in_output": read,
                                 "output_excerpt": output[-1000:]})
        elif item["type"] not in {"reasoning", "plan"}:
            observations.append({"type": item["type"], "detail": item})
    print(json.dumps({
        "threadId": thread,
        "turnId": turn_id,
        "tokenUsage": {"last": last_model_usage(events, thread, turn_id)},
        "tools": observations,
        "messages": messages,
    }, ensure_ascii=False), flush=True)


def checkpoint_snapshots(workspace):
    snapshots = []
    for path in sorted((workspace / ".ai-loop" / "checkpoints").glob("*.json")):
        if path.resolve() != path or not path.is_file():
            raise ValueError(f"Unexpected checkpoint path in the test workspace: {path}")
        raw = path.read_bytes()
        state = json.loads(raw)
        snapshots.append({"task": state["task"], "mode": state["mode"], "revision": len(state["contracts"]),
                          "request": state["contracts"][-1]["request"], "next": state["next"],
                          "sha256": hashlib.sha256(raw).hexdigest()})
    return snapshots


def probe(executable, live, suite="original"):
    cases = FOLLOWUP_CASES if suite == "followup" else CASES
    sandbox = "workspace-write" if suite == "followup" else "read-only"
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
            f'sandbox_mode = "{sandbox}"\nweb_search = "disabled"\n'
            '[features]\nplugins = true\napps = false\n'
            '[analytics]\nenabled = false\n', encoding="utf-8")
        installed = install_fixture(executable, root, env)
        with AppServer(executable, root, env) as app:
            app.initialize()
            workspaces = {name: root / ("shelf" if name == "handoff" else name) for name in cases}
            for workspace in set(workspaces.values()):
                workspace.mkdir()
            folders = sorted({str(path) for path in workspaces.values()})
            found = app.call("skills/list", cwds=folders)["data"]
            skills = [installed / "skills" / name / "SKILL.md" for name in ("research-verification", "task-checkpoint")]
            assert {row["cwd"] for row in found} == set(folders)
            for row in found:
                enabled = {Path(s["path"]) for s in row["skills"] if s["enabled"]}
                assert set(skills) <= enabled, row["cwd"]
            print(f"Both installed skills available. {len(cases)} chats, {sum(map(len, cases.values()))} task turns.",
                  flush=True)
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
            skill_markers = {}
            for path in skills:
                body = path.read_text(encoding="utf-8").split("\n---\n", 1)[1]
                skill_markers[path] = [line[:90] for line in body.splitlines() if len(line) > 65]
            for name, prompts in cases.items():
                started = app.call("thread/start", cwd=str(workspaces[name]), ephemeral=True)
                thread = started["thread"]["id"]
                print(json.dumps({"case": name, "model": started["model"], "provider": started["modelProvider"]}),
                      flush=True)
                for i, prompt in enumerate(prompts, start=1):
                    prompt = prompt.replace("{folder}", str(workspaces[name]))
                    print(f"{name} {i}: {prompt}", flush=True)
                    live_turn(app, thread, prompt, skill_markers)
                    if suite == "followup":
                        print(json.dumps({"checkpoints": checkpoint_snapshots(workspaces[name])},
                                         ensure_ascii=False), flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--codex", default="codex")
    parser.add_argument("--suite", choices=("original", "followup"), default="original")
    parser.add_argument("--live", action="store_true", help="authorize real model usage for the selected suite")
    args = parser.parse_args()
    executable = shutil.which(args.codex)
    if executable is None:
        parser.error("Codex executable not found")
    probe(executable, args.live, args.suite)

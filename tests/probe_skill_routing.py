#!/usr/bin/env python3
"""Observe implicit skill selection in live Codex. Run manually with --live.

Report the latest model call and whole-turn usage as observed by app-server.
"""

import argparse
import hashlib
import json
import os
import shutil
import tempfile
import time
from pathlib import Path

from measure_turn_usage import FIELDS, summarize_usage, token_counts
from test_sci_loop_native_codex import AppServer, PLUGIN_NAME, PLUGIN_SKILLS, install_fixture


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


DAILY_AB_CASES = {
    "shelf": [
        "社区交换书架这周先安排到这里。总预算 730 元，放在南门门厅，只用现有旧木板。请在项目目录 {folder} 的 notice.txt 写一句给邻居看的通知，通知只写地点和材料。周三还得问物业消防通道宽度，下次接着办。",
        "物业刚回复：南门挡推车，改放东侧连廊；总预算收紧到 620 元，材料不变。原来问消防通道宽度的事撤销，下一步周四请木工量墙。请同步修改原来的 notice.txt，通知仍只写地点和材料，后面按这版办。",
        "接着这份书架安排。请只回复：当前预算、地点、材料、唯一待办；最初预算和地点、撤销的待办、改址原因，以及实际改过的文件名。确实不知道的写未知，不改文件。",
    ],
    "shelf-recall": [
        "接着项目目录 {folder} 的书架安排。请只回复：当前预算、地点、材料、唯一待办；最初预算和地点、撤销的待办、改址原因，以及实际改过的文件名。确实不知道的写未知，不改文件。",
    ],
    "move": [
        "这几天在安排搬家。搬运费上限 860 元，周六上午 9 点打包，押金留现金。请在项目目录 {folder} 的 notice.txt 写一行给邻居的告示，只写打包时间和电梯会短时占用。周三等第二家公司报价再选。今天先到这里。",
        "已经收到报价，选第二家，因为它能配合新时间。周六改成下午 2 点，上限改为 790 元，押金方式不变。原来的等报价划掉，下一步只需确认报价是否包含楼梯搬运。请更新同一份 notice.txt，告示仍只写打包时间和电梯会短时占用。",
        "接着这次搬家。请只回复：当前预算、打包时间、押金方式、唯一待办；原预算和原打包时间、撤销的待办、选第二家的原因，以及实际改过的文件名。确实不知道的写未知，不改文件。",
    ],
    "move-recall": [
        "接着项目目录 {folder} 的这次搬家。请只回复：当前预算、打包时间、押金方式、唯一待办；原预算和原打包时间、撤销的待办、选第二家的原因，以及实际改过的文件名。确实不知道的写未知，不改文件。",
    ],
}


LONG_SHELF = [
    *DAILY_AB_CASES["shelf"][:2],
    "木工量完了，可用墙面宽 176 厘米。现有三块旧板，每块长 80 厘米、深 22 厘米。把这三个尺寸和数量写到 materials.txt；承重还没确认，先别答应放精装大部头。",
    "整理一下采购。支架每组 26 元要 6 组，螺钉一包 18 元，防滑垫两包每包 11 元。把明细、小计和按现预算算的余额写到 budget.txt，给我两个总数。",
    "物业补充，东侧连廊只能摆两层，第三块旧板留作备用。请在 materials.txt 写清楚装几层、用几块、留几块。目前的预算先不动。",
    "把开放日先定在周日。上午 10 到 12 点由小何值守，下午 2 到 4 点由阿宁值守。请写值班表 shifts.txt。时间只加到值班表，邻居那份通知保持原来的格式。",
    "刚拿到实际报价，支架降到每组 23 元，组数不变，其他项目照旧。请更新 budget.txt；顺便告诉我改价比原估算省了多少，旧价留在变更记录里。",
    "小何周日临时有事。上午改成小林，阿宁下午不变。请只更新给志愿者用的 shifts.txt，把对外通知什么时候更新留到稍后决定。",
    "把眼下的情况给我理一下：场地为什么改过，备用板为什么留着，现在还需要向谁核实哪件事？如果还没有指定核实对象就写未指定。先不改文件。",
    "木工已确认每层限重 12 公斤。把这个数和‘两层分别限重’写进 materials.txt。以后无需再等承重答复。",
    "新增一项印刷费 32 元。总预算从 620 元降为 550 元。请更新 budget.txt 并重新计算余额。场地、材料和值班人继续按已经定下的安排。",
    "现在准备对外开放。请新建 opening.txt，把地点、开放时段和每层限重写成两句话。之前给邻居看的 notice.txt 还要留着。",
    "临时调整，下午开放结束时间从 4 点提前到 3 点半，其他时间不变。请把对外开放说明和值班表都改好。",
    "我明天去现场，不想重复买东西。请把最新花费、预算余额、板材数量和两个班次列成四行给我，每一行附能核对的文件名；这轮不用改文件。",
    "最后还剩开门这件事。物业周六交钥匙给小林，领取后由她通知阿宁。请在 shifts.txt 记清这个交接顺序。今天先到这里。",
    "隔了一段，帮我接上：最初和现行预算、第一次改址原因、原先向物业问什么、两次支架单价、何人接替上午班、为什么留一块板、最后的钥匙待办、当前总花费和余额。拿不准的写未知。这次不要改文件。",
]

SUITES = {"original": CASES, "followup": FOLLOWUP_CASES, "daily-ab": DAILY_AB_CASES,
          "daily-long": {"shelf": LONG_SHELF, "shelf-recall": [
              "接着项目目录 {folder} 的书架安排。" + LONG_SHELF[-1]]}}
SHARED_WORKSPACE = {"handoff": "shelf", "shelf-recall": "shelf", "move-recall": "move"}


def model_usage_updates(events, thread_id, turn_id):
    for event in events:
        params = event.get("params", {})
        if (event.get("method") == "thread/tokenUsage/updated"
                and params.get("threadId") == thread_id and params.get("turnId") == turn_id):
            usage = params.get("tokenUsage") or {}
            yield token_counts(usage.get("total") or {}), token_counts(usage.get("last") or {})


def live_turn(app, thread, prompt, skill_markers, baseline):
    start = len(app.events)
    started_at = time.monotonic()
    result = app.call("turn/start", threadId=thread, input=[{"type": "text", "text": prompt}])
    turn_id = result["turn"]["id"]

    def matching(event):
        params = event.get("params", {})
        return (event.get("method") == "turn/completed" and params.get("threadId") == thread
                and params.get("turn", {}).get("id") == turn_id)

    turn = app.wait_for(matching, "live turn", since=start, timeout=240)["params"]["turn"]
    elapsed = time.monotonic() - started_at
    if turn["status"] != "completed":
        raise RuntimeError(f"Live turn {turn['status']}: {turn.get('error')}")
    events = app.events[start:]
    updates = list(model_usage_updates(events, thread, turn_id))
    total, last = updates[-1] if updates else ({}, {})
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
        "tokenUsage": {
            "last": {key: last.get(key, "unknown") for key in ("inputTokens", "cachedInputTokens")},
            "turn": summarize_usage(updates, baseline),
        },
        "elapsedSeconds": round(elapsed, 3),
        "tools": observations,
        "messages": messages,
    }, ensure_ascii=False), flush=True)
    return total


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


def notice_snapshot(workspace):
    path = workspace / "notice.txt"
    if not path.exists() and not path.is_symlink():
        return None
    if path.resolve() != path or not path.is_file():
        raise ValueError(f"Unexpected notice path in the test workspace: {path}")
    raw = path.read_bytes()
    return {"text": raw.decode("utf-8", errors="replace"), "sha256": hashlib.sha256(raw).hexdigest()}


def verify_discovery(app, workspaces, installed):
    folders = sorted({str(path) for path in workspaces.values()})
    found = app.call("skills/list", cwds=folders)["data"]
    assert {row["cwd"] for row in found} == set(folders)
    if installed is None:
        for row in found:
            assert not any(skill["name"].startswith(f"{PLUGIN_NAME}:")
                           or skill["name"] in PLUGIN_SKILLS for skill in row["skills"]), row["cwd"]
        return []
    skills = [installed / "skills" / name / "SKILL.md" for name in sorted(PLUGIN_SKILLS)]
    for row in found:
        enabled = {Path(s["path"]) for s in row["skills"] if s["enabled"]}
        assert set(skills) <= enabled, row["cwd"]
    return skills


def probe(executable, live, suite="original", without_plugin=False):
    cases = SUITES[suite]
    sandbox = "read-only" if suite == "original" else "workspace-write"
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
        installed = None if without_plugin else install_fixture(executable, root, env)
        with AppServer(executable, root, env) as app:
            app.initialize()
            workspaces = {name: root / SHARED_WORKSPACE.get(name, name) for name in cases}
            for workspace in set(workspaces.values()):
                workspace.mkdir()
            skills = verify_discovery(app, workspaces, installed)
            discovery = "Both installed skills available" if skills else "Both plugin skills absent"
            print(f"{discovery}. {len(cases)} chats, {sum(map(len, cases.values()))} task turns.",
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
            threads = set()
            for name, prompts in cases.items():
                workspace = workspaces[name]
                started = app.call("thread/start", cwd=str(workspace), ephemeral=True)
                thread = started["thread"]["id"]
                assert thread not in threads, (name, thread)
                threads.add(thread)
                print(json.dumps({"case": name, "model": started["model"], "provider": started["modelProvider"],
                                  "threadId": thread, "workspace": str(workspace),
                                  "pluginInstalled": installed is not None}),
                      flush=True)
                baseline = dict.fromkeys(FIELDS, 0)
                for i, prompt in enumerate(prompts, start=1):
                    prompt = prompt.replace("{folder}", str(workspace))
                    print(f"{name} {i}: {prompt}", flush=True)
                    baseline = live_turn(app, thread, prompt, skill_markers, baseline)
                    if suite != "original":
                        evidence = {"checkpoints": checkpoint_snapshots(workspace)}
                        if suite in ("daily-ab", "daily-long"):
                            evidence.update(case=name, turn=i, notice=notice_snapshot(workspace))
                        print(json.dumps(evidence, ensure_ascii=False), flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--codex", default="codex")
    parser.add_argument("--suite", choices=SUITES, default="original")
    parser.add_argument("--without-plugin", action="store_true",
                        help="run a daily comparison without installing the plugin in the temporary Codex home")
    parser.add_argument("--live", action="store_true", help="authorize real model usage for the selected suite")
    args = parser.parse_args()
    if args.without_plugin and args.suite not in ("daily-ab", "daily-long"):
        parser.error("--without-plugin requires a daily comparison suite")
    executable = shutil.which(args.codex)
    if executable is None:
        parser.error("Codex executable not found")
    probe(executable, args.live, args.suite, args.without_plugin)

# codex-sci-loop

给 macOS 和 Linux 原生 Codex 使用的日常任务检查点插件，Windows 为辅助平台。可以保存旅行安排、搬家清单或写作计划，过几天从上次的决定继续。一次性问答直接用 Codex 即可。

## 安装

在本仓库根目录运行 `./install.sh`，Windows 可运行 `install.ps1`。也可以直接使用 Codex CLI。请保留注册 marketplace 时使用的源码目录。

```sh
codex plugin marketplace add .
codex plugin add codex-sci-loop@codex-sci-loop-local
```

在自己的任务文件夹里说「周六上午打包，搬运费上限 860 元，周三拿到第二家报价再选。今天先到这儿」。有已定事项和未完待办时，Codex 可以在收尾时把它们写入检查点。之后开一个新对话，指向同一文件夹，问「接着上次搬家的事，现在该办什么？」即可继续。插件公开 `task-checkpoint` 和 `research-verification` 两个技能，默认注册零个生命周期 Hook。

## 日常使用

在普通任务文件夹就能保存进度，只需 Python 3.9+。在 Git 项目内使用其工作树根目录。下面先从插件仓库取得脚本路径，再切换到自己的任务文件夹。

```sh
checkpoint="$PWD/plugins/codex-sci-loop/scripts/checkpoint.py"
cd /path/to/trip
printf '%s\n' '安排周末出行，住宿预算不超过 800 元。' | python3 "$checkpoint" start --request-file - --note '周六上午出发' --next '预订返程车票'
python3 "$checkpoint" show
```

- **记录重要操作**。生成或修改了值得追溯的文件时，可在同一次 `start`、`revise` 或 `note` 中附 `--kind action --note '改动及原因' --artifact 相对路径`。程序读取该文件，记录当时的大小和 SHA-256，原内容由项目或 Git 保存。
- **查早期安排**。问“为什么改、当初做过什么”时，用 `history --limit 5` 查最近五版。按返回的 `next_before` 用 `--before N` 往前翻，或用 `history --revision 1 --full` 查第一版。每版有各自的执行笔记、文件指纹、待办变更和当时的验证记录。
- **变更约定**。`revise --from-revision 1 --request-file revised.md` 保存一版完整的新约定，原文和旧修订都可追溯。调用方负责提供与用户意图一致的文本。
- **继续与结束**。`show` 恢复当前约定、决定和待办，`show --full` 展开完整内容。完成待办后，用 `note --next ''` 清空，再用 `close` 记录任务已结束。此时状态为 `closed`，验证仍为 `unverified`。暂停、阻塞、继续和取消用 `set-state --state … --reason '…'`。
- **存储**。每个任务占一份 `.ai-loop/checkpoints/<id>.json`，项目共用一个空锁文件。默认 ID 为 `main`，可在命令后指定 `--task <id>`。恢复只需指向同一项目文件夹。需要长期值守的项目可在已有项目指令中写明「每次约束变更、关键产物落地或带待办暂停时保存项目检查点。接手先读当前状态，追查旧决定再读历史」。技能由模型选择，实际落盘以后才能保证跨对话读取。

## 需要证据的任务

校对一份交付清单、检查数据文件或验证实验，可以复用同一套命令。把判据写进约定，在 `start` 或 `revise` 时声明 `--verify-command '…'`，随后执行 `verify`。结果记录退出码、输入指纹、输出摘要和最后 8 KiB 输出。

在普通文件夹，重复使用 `--input <文件>` 声明会影响判断的文件，包括验证脚本、数据和参数；插件只对这些文件计算指纹。在 Git 工作树，默认还绑定 HEAD、索引和工作区变更，被忽略的重要文件仍可用 `--input` 补充。只有检查与提交历史无关时才使用 `--tree-only`。

需要独立判断时，用 `--require-review` 声明复核条件。复核前通过 `show --for-review --full` 取得证据对象标识，之后用 `review --subject … --reviewer … --outcome … --file …` 记录报告。`finish` 核对待办、当前验证和约定的复核条件，证据变化后 `show` 会提示重新检查。可写工作区中的署名属于操作者声明。

## 做科研时

科研技能用于检验一个具体科学主张。它帮助选择有辨别力的检验，例如用解析解检查网格加密后的误差阶，并记录适用条件、参数和反例。短推导可以直接给出交叉检查；需要跨会话追踪时，再调用同一套检查点和验证命令。普通清单流程无需加载这份技能正文。[科研验证技能](plugins/codex-sci-loop/skills/research-verification/SKILL.md)

## 兼容与验证

旧 Python 阶段项目可以用 `sci_loop.py resume --project-root <root> --json` 只读恢复。旧 PowerShell 项目仍使用 `loop-standard/`。检查点命令会识别既有阶段状态并避免覆盖。

本地回归用 `python3 -B tests/test_sci_loop_checkpoint.py`；隔离安装与真实客户端实验分别用 `python3 -B tests/test_sci_loop_distribution.py --codex-install` 和 `python3 -B tests/test_sci_loop_native_codex.py`。

[架构与实测报告](docs/native-codex-review.md) · [English](README_EN.md)

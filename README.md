# codex-sci-loop

给 macOS 与 Linux 原生 Codex 使用的任务可靠性插件，Windows 为辅助平台。短任务直接用 Codex。需要跨会话保留约束、复跑实验或审核结论时，再建立项目检查点。插件只公开 `task-checkpoint` 和 `research-verification` 两个技能，默认注册零个生命周期 Hook。

## 安装与使用

在本仓库根目录运行 `./install.sh`。macOS 和 Linux 都通过本机 Codex CLI 安装，不依赖 PowerShell。也可以直接运行以下两条命令。请保留注册 marketplace 时使用的源码目录。

```sh
codex plugin marketplace add .
codex plugin add codex-sci-loop@codex-sci-loop-local
```

在新的 Codex 会话中，可以说「为这个长任务保存检查点，保留我的约束和验收条件」，或「从项目里的检查点恢复，先告诉我哪次验证仍然有效」。Windows 可以用相同的 Codex 命令或仓库根目录的 `install.ps1`。

## 用命令复跑

原生核心只需要 Python 3.9+ 和 Git。macOS/Linux 可从 zsh 或 Bash 调用；验证脚本可显式选择 `bash` 或 `zsh`，Windows 可指定 `pwsh -NoProfile -File …`。从插件仓库取得 CLI 路径，然后进入**待处理项目自己的 Git 根目录**。下面假定该项目已有用户确认的 `request.md` 和可复跑的检查脚本。

```sh
checkpoint="$PWD/plugins/codex-sci-loop/scripts/checkpoint.py"
cd /path/to/research-project

python3 "$checkpoint" start --request-file request.md --verify-command 'bash tests/check.sh'
python3 "$checkpoint" note --kind hypothesis --note '误差可能来自边界条件' --next '检查网格加密结果'
python3 "$checkpoint" verify
python3 "$checkpoint" show
```

- **意图变更**。用 `revise --from-revision 1 --request-file revised.md` 替换完整的有效约定。旧版本逐字保留。明确撤销的要求从新约定移除。程序能保存输入原文，原文与实际聊天请求的一致性取决于提供者。
- **验证和复核**。`verify` 执行约定中的命令，记录退出码、Git 版本、输入和输出摘要及最后 8 KiB 输出。`--input path` 可以把被 Git 忽略的实验数据纳入验证。默认绑定当前 Git 提交；纯内容检查可显式选用 `--tree-only`，以免只保存检查点的提交触发重验。高风险任务可在建立或修订约定时指定 `--require-review`。复核人从 `show --for-review --full` 获取待审对象的摘要，再对照原始证据提交结论。具体命令见[科研复核技能](plugins/codex-sci-loop/skills/research-verification/SKILL.md)。
- **恢复和收尾**。`show` 重新判断证据时效。中断后先检查命令可能产生的副作用。完成待办后用 `note --next ''` 清空，再执行 `finish`。校验失败、复核不足或待办未清均会阻止收尾。已结束任务发生相关变动后会显示 `needs_recheck`。暂停、阻塞、继续和取消使用 `set-state --state … --reason '…'`。
- **文件和成本**。每个任务一份 `.ai-loop/checkpoints/<id>.json`，项目共用一个空锁文件。默认任务名为 `main`，每个命令可选 `--task <id>`。恢复默认展示最新约定的前 2,048 个字符和最近三条当前修订的笔记，`show --full` 可读完整当前记录。检查点不保存整段聊天或工作树补丁。完整测量数据、需要长期引用的失败实验和重要日志保存在项目原有位置。验证会读取受跟踪的变更和显式输入，大文件的哈希计算有实际成本。

项目内可写检查点适用于协作中的恢复和一致性检查。记录的复核人身份属于署名声明。程序无法防止有工作区写权限的操作者篡改文件，也无法判断测试是否充分覆盖科学问题。

## 兼容与维护

已有 `.ai-loop/loop.config.json` 的项目继续使用原协议，检查点命令会识别冲突。旧 Python 阶段由 `sci_loop.py resume --project-root <root> --json` 恢复。旧 PowerShell 项目使用 `loop-standard/`。LumiForge 签名收据及能力认证留在兼容路径，宿主需要显式投影模板并重新认证。普通 Codex 完成检查点工作无需这些服务。

本地运行 `python3 -B tests/test_sci_loop_checkpoint.py`。发行验证用 `python3 -B tests/test_sci_loop_distribution.py --codex-install`，真实客户端压缩和重启验证用 `python3 -B tests/test_sci_loop_native_codex.py`。后两项使用临时 Codex 环境。

[本轮架构审查与实测报告](docs/native-codex-review.md) · [English](README_EN.md)

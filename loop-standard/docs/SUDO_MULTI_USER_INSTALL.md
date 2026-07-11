# sudo 用户全局安装

管理员只需在 clone 的 `codex-sci-loop` 仓库中执行一次：

```bash
sudo ./loop-standard/scripts/install-system-wide.sh
```

脚本会完成以下工作：

- 将 harness 安装到 `/opt/codex-loop-harness`。
- 将科研 skills 安装到 `/opt/codex-skills`。
- 提供系统级 `pwsh` 和 `/usr/local/bin/ai-loop`。
- 将管理员当前可用的新版 Codex CLI 部署到 `/opt/codex-cli`，供其他用户使用。
- 为所有现有普通用户链接 loop skills。
- 写入 `/etc/skel`，让未来创建的用户自动继承这些 skills。
- 将 `claude-mimo` 设置为默认 Worker。
- 安装管理员托管的 goal hook，在 goal prompt 进入模型前初始化并验证 loop。
- 运行 `ai-loop doctor`。

sudo 密码只在本机终端输入，不要发送给 Codex。

## 普通用户怎么用

安装后，用户不需要记忆初始化命令。在任意 Git 仓库中开启一个新的 Codex
对话，直接描述目标即可，例如：

```text
请用 loop 完成这个任务：修复测试失败并验证结果。
```

或者：

```text
请创建一个 goal，持续完成当前仓库的数据分析任务。
```

只要请求涉及 loop 或 goal，managed hook 会先：

1. 确认真正的 Git 根目录。
2. 检查全局 `ai-loop`。
3. 在尚未初始化时创建 `.ai-loop` 和 `AGENTS.md`。
4. 执行 `validate-loop`。
5. 验证通过后再开始任务或创建 goal。

hook 配置位于 `/etc/codex/requirements.toml`，脚本位于全局 harness 的
`plugins/codex-loop-harness/scripts/goal-loop-bootstrap.py`。它由系统策略托管，
普通用户不需要逐个信任 hook。初始化或验证失败时，本次 goal prompt 会被阻断。

每次检测到 Codex 版本变化时，系统启动器和 `SessionStart` hook 会运行兼容性
自检。通过时完全静默；若 hooks 功能、managed 配置或 hook 自测失效，Codex
启动时会显示 `Codex hook compatibility warning`。

涉及外部 Worker 时默认使用 `claude-mimo`，不会替换成 `claude`。真实发送
prompt 到外部服务前仍需经过 preflight 和用户授权；`-Yolo` 不会默认启用。

新 skill 只会在新 Codex 对话中发现。全局安装或升级后，应重新开启对话。

# codex-sci-loop

`codex-sci-loop` 是一套给原生 Codex 使用的、项目本地优先的证据闭环插件。它不替换
Codex 的 Agent 内核，也不启动另一套 Worker 引擎；当前 Codex 线程负责执行工作，插件
负责保存阶段状态、验证结果、Git 证据、独立复核结果与可恢复状态。

Agent 进入仓库时先读取短入口 `AGENTS.md`，再按其中指向读取项目控制面；不要用聊天
历史替代落盘事实。

## v1 架构

- `plugins/codex-sci-loop/`：正式的 1.0.0 插件。包含 Python 阶段控制核心、能力 ABI、
  Codex hook adapter、签名审计协议、schemas 与 6 个 skills。
- `loop-standard/`：旧项目仍可使用的 PowerShell 兼容工具箱。它不是 LumiForge 的原生
  Agent 运行时，也不会被插件当作执行引擎。
- `.ai-loop/`：本仓库自身的历史控制面和审计证据。历史记录保留，不代表当前推荐架构。
- `tests/`：插件分发、能力认证、签名收据和 Codex hooks 的 provider-free 测试。

插件的核心边界是：

1. 原始 Goal 请求由 host adapter 在模型执行前捕获，不从聊天记忆重建。
2. 当前 Codex 线程只能提交可验证的完成声明，不能凭自己的总结完成验收。
3. 独立复核由隔离的原生 Codex subagent 执行，必须使用 `fork_turns=none`，只读取规范化
   audit snapshot，不继承执行线程的推理历史。
4. 只有 host 受保护目录中的新鲜签名收据可以放行完成；普通 Markdown 审计文本不能
   伪造 PASS。
5. Codex 更新后先比较能力 ABI、adapter、运行时制品与行为证据。没有冲突时继续运行；
   只有关键能力变更或证据过期时才要求重新认证或升级插件。

## 插件内容

主要入口：

```bash
python3 plugins/codex-sci-loop/scripts/sci_loop.py --help
python3 plugins/codex-sci-loop/scripts/audit_protocol.py --help
python3 plugins/codex-sci-loop/scripts/capability_gate.py --help
```

主要 skills：

- `loop-goal-bootstrap`
- `loop-supervisor`
- `loop-auditor`
- `loop-recovery`
- `research-loop-orchestrator`
- `independent-completion-auditor`

其中最后一个只允许在 LumiForge host 创建的隔离复核 subagent 中使用。

## 本地验证

这些检查不调用真实 Provider，不启动浏览器，也不会安装或更新当前 Codex：

```bash
python3 tests/test_sci_loop_distribution.py
python3 tests/test_sci_loop_capability_abi.py
python3 tests/test_sci_loop_audit_receipt.py
python3 tests/test_sci_loop_codex_hooks.py
bash loop-standard/scripts/Test-PlatformInstall.sh
```

插件和 skill 的格式还可以直接验证：

```bash
python3 ~/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py \
  plugins/codex-sci-loop

for skill in plugins/codex-sci-loop/skills/*; do
  python3 ~/.codex/skills/.system/skill-creator/scripts/quick_validate.py "$skill"
done
```

## 用户目录安装

安装只复制到指定目录，不会自动替换正在运行的 Codex 插件。更新真实 Codex 前应先审查
diff、跑完上述测试，并在新的 Codex 会话中验证发现结果。

Linux：

```bash
./install.sh \
  --install-root "$HOME/.codex/loop-harness" \
  --install-plugin \
  --create-shim \
  --create-marketplace \
  --force
```

Windows：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 `
  -InstallRoot C:\path\to\loop-harness `
  -InstallPlugin -CreateShim -CreateMarketplace -Force
```

LumiForge 不从可变源码目录直接加载插件。它会验证并原子投影一份认证副本到各账号私有
Codex home；收据根、复核观察和账号数据仍由 host 隔离。

## 兼容工具箱

已有项目若仍使用 `loop-standard/`，可以继续通过 `ai-loop.ps1` 完成 `init`、`start`、
`collect`、`audit-pack`、`resume` 和 schema migration。它保留通用外部 Worker 兼容接口，
但 v1 原生插件和 LumiForge Goal 模式不依赖该接口。新的功能应优先加入 Python 插件核心，
避免再次复制一套 Agent 执行内核。

## 安全与运维

- 不把密码、token、Provider key 或账号文件写入 `.ai-loop`。
- 不从可写的源码 checkout 直接运行正式插件。
- 不把执行线程 prose 当作验收证据。
- 不复用旧审计收据；任何受保护输入、workspace diff 或 runtime identity 变化都会使其失效。
- 安装、远端 push、tag 以及正式环境切换始终是独立授权动作。

English documentation: [README_EN.md](README_EN.md).

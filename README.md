# Loop Harness

这个仓库正在搭建一套可复用的 Supervisor-Worker coding loop 工作流。

目标是：把一套本地优先、证据优先、可审计、可迁移的 AI coding harness
固定下来，使它可以套用到任意项目文件夹中，由 Codex、Kimi Code，或其他
worker agent 执行阶段任务。长期目标不是绑定某一个 worker，而是让
Supervisor、Worker、Auditor、Verifier、Recovery 这些角色协议稳定存在。

这套系统的核心原则是：

- local-first：所有状态落在项目本地文件里。
- markdown-first：记忆、约束、证据、报告都尽量可读。
- git-trackable：关键状态可以被 git 追踪和审计。
- evidence-first：不能只看 worker 总结就验收。
- Windows PowerShell-first：第一版优先服务 Windows 使用场景。

英文版说明保存在 `README_EN.md`。

日常人工使用从本文件开始；英文说明看 `README_EN.md`；agent 入口只使用
`AGENTS.md` 作为 bootstrap，不把长规则塞进根入口文件。

## 仓库结构

### `loop-standard/`

这是可复用标准套件，是未来复制、初始化或插件分发到任意项目的主体。

关键内容：

- `templates/.ai-loop/`：要复制到目标项目的 `.ai-loop/` 模板。
- `scripts/init-loop.ps1`：初始化目标项目的 `.ai-loop/`。
- `scripts/start-phase.ps1`：开始一个阶段，记录 base commit、状态、阶段需求。
- `scripts/collect-evidence.ps1`：worker 执行后收集 diff、verify log、changed files 等证据。
- `scripts/prepare-audit-pack.ps1`：整理 Codex 审计入口文件。
- `scripts/validate-phase-gates.ps1`：检查阶段 gate，缺证据、缺 skill artifact、坏链接都会阻断。
- `scripts/accept-phase.ps1`：Codex 审计通过后才允许接受阶段。
- `scripts/decide-phase.ps1`：把 `REWORK` / `BLOCKED` 审计结果写入 durable state。
- `scripts/link-skills.ps1`：把共享 skill 库链接到目标项目的 `.agents/skills/`。
- `scripts/preflight-worker.ps1`：外部 Worker 调用前的安全性和可行性审查。
- `scripts/invoke-worker.ps1`：仅在 preflight 通过后调用外部 Worker。
- `scripts/ai-loop.ps1`：推荐使用的统一命令入口。
- `worker-profiles/`：Worker agent 的薄 profile，例如 `kimi-code`。

更底层的脚本说明在 `loop-standard/README.md`。

### `.ai-loop/`

这是本仓库自己的 loop 控制面，也是目标项目初始化后会拥有的事实源。

它记录：

- 项目记忆
- 约束
- 角色协议
- 阶段 gate
- 证据 ledger
- skill 触发与使用记录
- event log
- prompt 模板
- handoff / resume 信息
- 项目局部自进化建议

重要边界：不要依赖聊天历史作为关键事实来源。重要状态必须落进
`.ai-loop/`。

关键子目录：

- `memory/`：project brief、active context、decision log、failure ledger、progress、handoff summary。
- `roles/`：Supervisor、Worker、Auditor、Verifier、Recovery 的行为协议。
- `gates/`：pre-action check、phase gates、stop rules。
- `evidence/`：evidence ledger、artifact index、command log、test log、provenance map。
- `skills/`：skill trigger matrix、skill usage ledger、skill artifact map、skill source map。
- `events/`：本地 append-only 事件日志，使用 ndjson。
- `prompts/`：恢复、更新记忆、预行动检查、下一步决策等 prompt。
- `evolution/`：项目本地的 loop 自进化建议；默认不直接成为治理规则。
- `reports/`：实现报告、审计报告、阶段报告。

### `.agents/`

这是 agent runtime 资产目录，不是项目记忆目录。

当前规划中：

- `.ai-loop/` 保存项目治理、记忆、证据和状态。
- `.agents/` 保存 agent 可用的 runtime 资产，例如链接进来的 skills。

科研 workflow 的 8 个 skill 不会复制到每个项目里，而是通过
`.agents/skills/` 暴露给项目，并把来源、链接类型、hash、可用状态记录到
`.ai-loop/skills/skill-source-map.md`。

### `plugins/codex-loop-harness/`

这是第一版 Codex 插件源码目录，用于分发和发现这套 workflow。

插件不保存项目状态。项目状态仍然只属于目标项目自己的 `.ai-loop/`。

当前插件 skills：

- `loop-supervisor`：指导 Codex 何时启动和监督 loop 阶段。
- `loop-auditor`：指导 Codex 如何审计 worker 产物。
- `loop-recovery`：指导新会话如何从 `.ai-loop/` 恢复。
- `research-loop-orchestrator`：指导科研任务如何选择 skill profile。

插件是发现层和分发层，脚本仍然是稳定执行核心。

### `pilot-project/`

一个很小的测试项目，用于验证完整 loop 流程。它是本仓库追踪的 fixture，
不是嵌套 git 仓库。

## 当前运行模型

现在采用“双层固定”：

1. 脚本核心：`loop-standard/scripts/ai-loop.ps1` 是推荐命令入口。
2. 插件分发：`plugins/codex-loop-harness/` 帮助 Codex 发现并遵守流程。

所有项目特定状态都留在目标项目自己的 `.ai-loop/`。

如果要先安装成临时全局布局，可以使用：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\install-global.ps1 -InstallRoot E:\codexfiles\loop\.tmp-install -InstallPlugin -CreateShim -SkillLibraryRoot E:\codexfiles\test\.agents\skills -Force
```

如需验证插件发现面，可以加 `-CreateMarketplace`。这会在安装根下生成
`.agents/plugins/marketplace.json`，但不会自动修改真实 Codex 全局配置。

安装后推荐从 shim 调用：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\.tmp-install\bin\ai-loop.ps1 -Command doctor
```

## 如何套用到任意项目

下面用 `E:\some-project` 代表目标项目。

初始化 loop：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 -Command init -ProjectRoot E:\some-project -CreateAgentsBootstrap
```

如果项目需要科研 workflow，链接共享 skill：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 -Command link-skills -ProjectRoot E:\some-project -Profile full-research
```

启动一个普通全栈开发阶段：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 -Command start -ProjectRoot E:\some-project -PhaseId phase-001 -TaskKind fullstack -Title "Small fix" -Objective "Make one verifiable change" -VerifyCommand "npm test"
```

启动一个物理或数值科研阶段：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 -Command start -ProjectRoot E:\some-project -PhaseId phase-001 -TaskKind physics-research -Profile physics-sim -Title "Simulation check" -Objective "Make one evidence-backed simulation change"
```

worker 执行完成后，收集证据并准备审计包：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 -Command collect -ProjectRoot E:\some-project -PhaseId phase-001
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 -Command audit-pack -ProjectRoot E:\some-project -PhaseId phase-001
```

如果要让 harness 调用外部 Worker，先运行 preflight：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 -Command worker-preflight -ProjectRoot E:\some-project -PhaseId phase-001 -WorkerProfile kimi-code -Yolo
```

`kimi-code` 属于外部服务 Worker；除非你已经确认本次调用可以把 prompt 交给
外部 agent，否则 preflight 会返回 `NEEDS_USER_APPROVAL`。确认后再显式运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 -Command invoke-worker -ProjectRoot E:\some-project -PhaseId phase-001 -WorkerProfile kimi-code -AllowExternalService -Yolo
```

`-Yolo` 会被记录，但不需要单独停下来确认。外部服务调用、敏感 prompt、长期记忆
或治理规则升级，仍然需要明确确认。

验收前先运行 gate：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 -Command validate -ProjectRoot E:\some-project -PhaseId phase-001
```

也可以检查整个 `.ai-loop` 控制面的恢复和状态一致性：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 -Command validate-loop -ProjectRoot E:\some-project
```

如果旧项目因为缺少 schema manifest、schema 版本过旧或模板文件缺失而被阻断，先运行非破坏迁移：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 -Command migrate -ProjectRoot E:\some-project
```

`migrate` 只补齐缺失模板、合并缺失 JSON 字段、升级 schema 标记，并写入
`.ai-loop/schema/migration-records/` 与 `.ai-loop/schema/migration-log.md`。
它不会覆盖已有项目记忆、证据 ledger 或业务文件。遇到未来版本 schema 时会阻断，
除非 Supervisor 显式使用 `-Force` 并承担审计责任。

`.ai-loop/schema/schema-version.json` 记录当前 control-plane schema、支持的
最小版本、最新版本和 `status.json` 状态文件格式版本。
`validate-loop` 会阻断缺失 schema manifest、过旧版本、未来版本和
config/status schema 不匹配的项目。人类可读的迁移记录保存在
`.ai-loop/schema/migration-log.md`。
状态变化还会追加记录到 `.ai-loop/events/state-transitions.ndjson`。
新 phase 一旦声明 `transition_log`，`validate-loop` 会检查该 phase 的最后一条
状态转移是否与 `status.json` 当前状态一致。

只有 Codex 写出包含 `Decision: ACCEPTED` 的 audit 后，才接受阶段：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 -Command accept -ProjectRoot E:\some-project -PhaseId phase-001
```

如果 Codex 审计结论是 `REWORK` 或 `BLOCKED`，不要运行 `accept`，而是记录
非接受决策：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 -Command decide -ProjectRoot E:\some-project -PhaseId phase-001 -Decision REWORK -Reason "Audit found a scoped fix is required."
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 -Command decide -ProjectRoot E:\some-project -PhaseId phase-001 -Decision BLOCKED -Reason "Required evidence is missing."
```

`decide` 会写入 `.ai-loop/status.json`、`phase_meta.json`、`rework.txt` 或
`blocked.txt`，并追加 `.ai-loop/events/event-log.ndjson`。之后 `resume`
会基于这些文件给出下一步安全动作。

如果结论是 `REWORK`，可以让 Supervisor 把返工结论脚手架成一个新的有界阶段：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\codexfiles\loop\loop-standard\scripts\ai-loop.ps1 -Command scaffold-rework -ProjectRoot E:\some-project -PhaseId phase-001 -ReworkPhaseId phase-002
```

`scaffold-rework` 只接受 durable `REWORK` 源阶段。它会读取
`.ai-loop/audits/<source>-audit.md` 和 `.ai-loop/runs/<source>/rework.txt`，
生成新阶段的 prompt、requirements、`rework_source.json` 和状态记录。Worker
只能执行新阶段，不得重新解释总路线或扩大 audit scope。

## 科研 Skill Profiles

第一版默认共享 skill 库来源是：

```text
E:\codexfiles\test\.agents\skills
```

当前 profiles：

- `research-core`：research-task-tree、invariant-contract、deterministic-verification、skill-compliance-audit。
- `physics-sim`：research-task-tree、invariant-contract、bounded-experiment-loop、deterministic-verification、independent-crosscheck、result-provenance-audit、skill-compliance-audit。
- `manuscript`：research-task-tree、deterministic-verification、result-provenance-audit、manuscript-consistency-audit、skill-compliance-audit。
- `full-research`：全部 8 个科研 workflow skills。

Windows 下优先用 directory junction 链接 skill。失败时尝试 symbolic link，
再失败则只写 source map，并由 gate 标记 unavailable。

## 证据规则

Codex 不能只根据 worker report 接受阶段。

一个阶段至少应该有这些 evidence：

- phase prompt
- worker report
- git status before / after
- diff patch
- verify log
- changed files
- phase requirements
- evidence ledgers
- artifact manifest hashing
- skill usage records
- 触发 skill 后要求的 skill artifacts
- Codex audit result

证据完整性使用双轨模型：

- Markdown ledgers 面向人工审计。
- `.ai-loop/evidence/artifact-manifest.json` 面向脚本校验，记录 SHA256、文件大小、mtime、phase 和 path。

`collect` 会把当前 phase 的 required evidence 和 required skill artifacts 都登记进
artifact manifest。required skill artifacts 使用 `skill-artifact` 类型记录；如果文件
缺失、为空、包含 `MISSING:` 占位符，或登记后的 SHA256 与当前文件不一致，`validate`
都会阻断。

如果证据缺失、验证失败、skill artifact 缺失、required skill 链接不可用，
阶段必须是 `BLOCKED` 或 `REWORK`。只有 Supervisor 记录明确 override reason
时，才允许 force accept。

## 已验证内容

最近通过的检查：

- PowerShell 脚本解析检查。
- `Test-LoopStandard.ps1 -AllowPilotProject`。
- `Test-PluginInstall.ps1`：在 `.tmp-ai-loop-plugin-smoke/` 中验证临时
  install root、local marketplace、plugin manifest、plugin skills、shim
  `doctor` 和 plugin wrapper `doctor`。
- `Test-TempIsolation.ps1`：并发启动两个 plugin install smoke test，并验证
  它们使用不同的 per-run install root，避免固定 `.tmp-ai-loop-*` 目录竞争。
- `ai-loop.ps1 -Command validate-loop`：检查整个 `.ai-loop` 控制面结构、
  `status.json`、phase 引用、accepted/rework/blocked audit、恢复关键文件和
  schema 版本。
- `ai-loop.ps1 doctor`。
- 插件 wrapper `doctor`。
- 临时项目行为测试：
  - `init` 创建 `.ai-loop/` 和 `.agents/skills/`。
  - `link-skills -Profile full-research` 链接 8 个 skill。
  - full-stack 阶段可以通过普通 evidence gates。
  - physics-research 阶段在缺少 required skill artifacts 时阻断。
  - force accept 必须写 override reason。
  - `REWORK` / `BLOCKED` 可以通过 `decide` 写入 durable state 并由
    `resume` 恢复。
  - broken skill link 会阻断 validation。

详细报告见 `.ai-loop/reports/fixed-wrapper-plugin-report.md`。

## 当前完成状态

已经完成：

- 可复用 `loop-standard/` kit。
- `.ai-loop/` 记忆与约束系统。
- evidence ledgers。
- artifact manifest hashing。
- skill trigger matrix 与 skill usage records。
- phase gate automation。
- project-local evolution file。
- 统一 `ai-loop.ps1` wrapper。
- skill linking 与 skill source map。
- Codex plugin scaffold。
- repo-local plugin install/discovery smoke test。

下一步计划：

- 真实 Codex 全局配置中的插件安装/发现验证，需用户明确允许后再做。
- 更深入的 recovery automation。
- 更完整的状态机检查。
- evidence ledger 自动化增强。
- 针对全栈开发和物理科研继续扩展 skill trigger matrix。

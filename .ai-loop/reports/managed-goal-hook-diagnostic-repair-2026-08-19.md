# Managed Goal Hook Diagnostic Repair — Verification Ledger

Date: 2026-08-19

Scope: source-only repair in `/home/tjz/codexfiles/loop/codex-sci-loop`

Out of scope: installing into `/opt/codex-loop-harness`, editing `/etc/codex/requirements.toml`, modifying LumiForge, or changing production services

## Claim 清单

| Claim ID | 原始 claim | 可检查陈述 | 所需证据 | 容差 | 失败条件 | 状态 |
| --- | --- | --- | --- | --- | --- | --- |
| CLM-001 | 缺失 JSON 字段不再触发模糊的 StrictMode 属性异常 | 对 11 个缺字段案例，`validate-loop.ps1` 均以非零退出并输出对应字段的显式诊断，且输出中不含已知原始 StrictMode 泄漏标记 | 缺字段回归测试 | 0 个漏诊；0 个 StrictMode 标记 | 任一案例通过、缺少预期诊断或泄漏原始异常 | 已验证 |
| CLM-002 | 托管 hook 的阻断原因保留根因 | 模拟多行验证失败时，hook 原因包含验证阶段、`skill_ledgers` 字段名、末行诊断和分隔符，同时保持有界长度 | hook 单元回归测试 | 原因总长度不超过 1200 字符 | 任一必要信息丢失或长度越界 | 已验证 |
| CLM-003 | 修复可以被标准包与平台安装流程携带 | 标准自检包含新测试；Linux 平台安装 smoke test 实际运行并通过该测试 | 标准自检、平台安装 smoke test | 全部命令退出码为 0 | 任一命令失败 | 已验证 |
| CLM-004 | 本次工作没有把候选代码切换到当前安装或混入 LumiForge | `/opt` 两个相关脚本逐字匹配本仓库修改前的 `HEAD`；LumiForge 工作树保持干净 | 哈希比较、两仓库 `git status` | 两组 SHA256 均相同；LumiForge 无修改路径 | `/opt` 与修改前版本不一致，或 LumiForge 出现修改路径 | 已验证 |

## 证据记录

| Claim ID | 方法 | 精确命令 / 测试名 | 输出摘要 | 日志或 artifact 路径 | 决定 |
| --- | --- | --- | --- | --- | --- |
| CLM-001 | 直接回归 | `python3 loop-standard/scripts/Test-ValidateLoopMissingProperties.py` | `Validate-loop missing-property regression: OK (11 cases)` | `/tmp/codex-sci-loop-hook-fix-verify.log` | 已验证 |
| CLM-002 | 模拟托管 hook | `python3 loop-standard/scripts/Test-GoalLoopHook.py` | `Goal loop hook test: OK` | `/tmp/codex-sci-loop-hook-fix-verify.log` | 已验证 |
| CLM-002 | 静态语法检查 | PowerShell parser 对 `validate-loop.ps1` 解析 | `PowerShell parser: OK` | `/tmp/codex-sci-loop-hook-fix-verify.log` | 已验证 |
| CLM-003 | 标准自检 | `pwsh -NoProfile -File ./loop-standard/scripts/Test-LoopStandard.ps1 -AllowPilotProject` | `Loop standard self-check: OK`；检查 174 个路径 | `/tmp/codex-sci-loop-hook-fix-verify.log` | 已验证 |
| CLM-003 | Linux 安装烟测 | `bash loop-standard/scripts/Test-PlatformInstall.sh` | `Platform install smoke test: OK`；已安装候选中的验证器与 hook 分别逐字匹配源码候选 | `/tmp/codex-sci-loop-hook-fix-verify.log` 与最终终端输出 | 已验证 |
| CLM-004 | 安装隔离检查 | 分别对修改前 `HEAD` 与 `/opt/codex-loop-harness` 中的 `validate-loop.ps1`、`goal-loop-bootstrap.py` 计算 SHA256 | validator 均为 `3bdd725c…fdc`；hook 均为 `db2e95c0…415` | 本轮终端输出 | 已验证 |
| CLM-004 | 工作树范围检查 | `git status --short --branch`；`git -C /home/tjz/claudefiles/workspace/lumiforge status --short --branch` | 修复仅位于 harness 源码仓库；LumiForge 为 `main...origin/main [ahead 111]` 且无修改路径 | 本轮终端输出 | 已验证 |

## 交叉检查

| Claim ID | 主检查 | 独立检查 | 一致性结果 | 动作 |
| --- | --- | --- | --- | --- |
| CLM-001 | 11 案例动态回归 | `rg` 检查验证器中相关 JSON 对象的未保护直接字段访问 | 一致：动态测试通过，相关对象均通过安全访问器读取 | 保留修复 |
| CLM-002 | hook 动态回归 | `concise_failure()` 长度上限和保留行数的源码审阅 | 一致：保留最后 4 个非空行，总细节限制为 1000 字符 | 保留修复 |
| CLM-003 | 平台安装 smoke test | 标准自检与 Python 编译检查 | 一致：打包入口、脚本语法和标准清单均通过 | 保留集成测试 |
| CLM-004 | `/opt` 与修改前 `HEAD` 逐字比较 | LumiForge 独立工作树状态检查 | 一致：候选修复未安装，产品仓库未被本任务写入 | 不执行安装或产品变更 |

## 最终 claim 写法

- 可以按原样保留的 claim：源码候选已修复缺字段诊断丢失问题，并通过列出的聚焦回归、标准自检和 Linux 平台安装 smoke test。
- 已降级的 claim：无。
- 已移除的 claim：不声称当前 Codex 会话已使用修复后的 hook。
- 被阻塞的 claim：当前安装副本是否生效未验证，因为本任务依照隔离约束没有更新 `/opt/codex-loop-harness` 或 `/etc/codex/requirements.toml`。

## 危险 claim 扫描复核

最终运行 `scan_dangerous_claims.py` 后得到 12 个匹配项：11 项来自本 Ledger
表格中的结论和决定，另 1 项来自模板表头。
这些不是未附证据的额外结论；CLM-001 至 CLM-004 均已在“证据记录”和“交叉检查”
中逐项绑定命令、输出、失败条件及决定。因此不需要降级这些 claim。扫描报告保存在
`/tmp/codex-sci-loop-hook-dangerous-claims.md`，它是临时审阅输出，不作为安装生效
的证据。

# CLI / App / SDK 能力对齐矩阵（2026-02-19）

## 目标
- 统一执行面：`App <-- SDK --> CLI`
- 新功能默认 `CLI + SDK` 先行，`App` 仅做编排和展示接入。

## 对齐结论
- SDK 基础能力：大体对齐（主要在 `libs/Providers`）。
- CLI 命令面：最完整。
- App 交互面：覆盖常见场景，但对 `runtime/diagnostics` 仍有缺口。

## 能力矩阵
| 能力域 | CLI 命令 | SDK 能力（libs/Providers） | App 入口 | 状态 | 优先级 |
|---|---|---|---|---|---|
| Codex 账号总览 | `codex auth list/usage/status` | `NolonLiveCodexCLIService.auth*` | Provider Usage 视图 | 已对齐 | - |
| Codex 登录/激活/删除 | `codex auth login/activate/delete/refresh` | `CodexAuthManager` + runtime switch 协调 | Provider Usage 账号操作 | 已对齐 | - |
| Codex 二进制管理 | `codex binary *` | `CodexBinaryManager` | `CodexBinaryConfigView` / 高级设置 | 已对齐 | - |
| Codex 诊断探测 | `codex status probe/doctor` | `statusProbe` + doctor 组装 | App 有部分状态展示，无完整 doctor 面板 | CLI 先行 | P1 |
| Codex 运行实例管理 | `codex runtime list/stop` | `runtimeList` / `runtimeStop` | App 无显式运行实例列表/停止入口 | App 缺失 | P0 |
| Provider 发现 | `codex provider discover` + `provider list` | Provider catalog + discover | Sidebar/Provider 管理 | 基本对齐 | P1 |
| Skills Repo 流程 | `skills repo plan/preflight/sync` | `NolonCoreCLIRunner` + facade | App 有远程仓库相关流程 | 基本对齐 | P1 |
| Workflow 资源安装 | `workflow discover/install/uninstall` | `NolonCoreCLIRunner` | Remote Browser + 安装入口 | 已对齐 | - |
| MCP 资源安装 | `mcp discover/install/uninstall` | `NolonCoreCLIRunner` | Remote Browser + MCP 配置入口 | 已对齐 | - |
| Remote 检索/下载/安装 | `remote list/download/sync/install/sync-install` | `SkillsRepositoryFacade` | Remote 浏览与安装 | 已对齐（交互不同） | - |

## P0：先做什么
### 项目：App 补齐 Codex Runtime 运行实例管理入口
- 目标：在 App 中提供“查看运行中 Codex 实例 + 停止实例”的最小闭环。
- 复用：直接调用 SDK 已有的 `runtimeList/runtimeStop`，不新增 app 层进程解析逻辑。

### BDD 验收
1. Given 有运行中 codex 进程，When 打开 Provider Usage（或 Codex 配置页），Then 能看到实例列表（PID/运行时长/命令/provider）。
2. Given 选中实例并点击停止，When 执行停止，Then UI 状态更新且错误可读。
3. Given 非法 PID 或权限问题，When 停止失败，Then 展示结构化错误，不影响其余实例展示。

### 实施拆分（小步）
1. `test(app):` 增加 ViewModel 级 runtime list/stop 单测（红）。
2. `feat(app):` 接入 SDK runtime list/stop 到现有 Codex 使用页（绿）。
3. `refactor(app):` 整理 UI 文案与错误映射，保持 app 仅编排。

## 后续任务（按优先级）
1. P0：Runtime 实例管理 App 接入（本轮开始）。
2. P1：`status doctor` 的 App 可视化输出（至少摘要级）。
3. P1：Provider discover 与 App Provider 管理页做字段对齐。
4. P2：持续收敛文案与表格输出规范（CLI / App 统一术语）。

## 2026-02-19 追加：`skills list` 语义纠偏
- 背景：`nolon skills list` 曾短暂映射到 `skills.repo.list`（仓库摘要），与用户直觉不一致。
- 调整：
  - `skills list` 改为 `skills.list`，输出“已安装 skills 明细”。
  - 默认按“已安装 CLI 的 provider”范围扫描，并展示状态：`installed` / `orphaned` / `broken`。
  - `skills repo list` 保留仓库摘要语义（用于 repo 维度诊断）。
- 输出形态：
  - text：`provider | skill | state | path` 表格 + 汇总行。
  - json：`command = skills.list`，包含 `items` 与 `summary`。

## 2026-02-21 追加：Workflow/MCP 命令面对齐与来源标记
- 命令面对齐：`workflow` / `mcp` 与 `skills` 统一为 `list/sync/search/add/remove`。
- 迁移策略：旧命令 `discover/install/uninstall` 视为已移除，在解析期返回明确迁移提示（而非仅 `Unexpected argument`）。
- 缓存与分发：`workflow add` / `mcp add` 复用与 `skills add` 一致的路径策略：
  - 先落 `NOLON_HOME/workflows` 或 `NOLON_HOME/mcps` 缓存。
  - 再按 provider 目标路径分发（`--provider` 省略时分发到已检测 providers）。
- 来源模型（provenance）：在 `libs/Providers` 新增统一 `NolonResourceOrigin`，用于 skills/workflows/mcps 的来源归档与展示。
- 文本输出：`skills/workflow/mcp list --verbose` 可显示 `origin=...`，为后续“来源追踪/修复建议”提供基础。

### 风险与后续
- 历史安装项缺少 sidecar 来源文件时会显示 `origin=unknown`，属兼容预期。
- 下一步应补一轮“批量回填来源”工具，减少存量噪音。

# MEMORY

> 稳定高价值信息每周归并到此文件。

> 最近一次压缩：2026-04-16。
> 压缩原则：只保留能被当前代码、测试或 `docs-linhay/features|dev` 文档支撑的长期事实。

## 文档系统与流程

- `docs-linhay/` 是唯一文档系统根目录，固定子目录为 `dev/`、`features/`、`plans/`、`memory/`、`references/`、`screenshots/`、`debate/`、`scripts/`。
- 需求变更先更新对应 `docs-linhay/spaces/<space-key>/README.md`，技术方案放 `docs-linhay/dev/`，每日工作记录写回 `docs-linhay/memory/YYYY-MM-DD.md`。
- 记忆系统查询优先走 `qmd query` / `qmd get`；写回后执行 `qmd update && qmd embed`。

## 代码边界

- `nolon/` app 层只负责 UI 与编排；Codex CLI、app-server、JSON-RPC、运行时快照与本地扫描逻辑必须下沉到 `libs/Providers/`。
- `Provider Usage` 的 provider-specific 聚合逻辑必须落在 `libs/Providers/`，不要回流到 app 层做临时文件扫描。

## Provider Usage

- 当前真实支持 usage 能力的 provider 是 `codex`、`copilot`、`gemini`、`antigravity`、`claude`；其余 provider 仍走 unsupported 分支。
- Provider 详情页已经支持 `Accounts` / `Usage` 双 tab，但只对 `codex`、`claude`、`gemini`、`antigravity` 生效；`codexXcode` 明确不补 `Accounts` tab。
- `ProviderUsageRootViewModel` 当前有 `combined`、`accounts`、`usage` 三种页面模式，并分别对应独立加载入口；不要再假设所有加载都只走账号链路。
- Claude 的 usage 事实源是本地 session 日志，不是 web dashboard：默认扫描 `~/.config/claude/projects` 与 `~/.claude/projects` 下的 `jsonl` 文件，并在聚合前做去重与 `vertexai` 噪音过滤。
- Codex 的 `Usage` 页当前产品语义是 `global local usage`：展示本机全局本地会话聚合，不承诺与当前账号或上游统计同源。

## Codex Sessions

- `Codex Sessions` 是独立 tab，覆盖 `codex` 与 `codexXcode`，不并回 `Usage` 页。
- `CodexSessionStore` 是当前会话事实源：扫描 `sessions/` 与 `archived_sessions/`，结合 `state_*.sqlite` 读取会话状态。
- Provider rewrite 不只是改 rollout 文件；还会同步改写 rollout 中的 `session_meta.payload.model_provider` 和 SQLite 中的 `threads.model_provider`。
- `Codex Sessions` 当前采用 `project-first` 浏览模型：默认按 `project` 分组，`provider` 作为次级切换视角。
- `Codex Sessions` 的 UI 与 CLI 已在语义层对齐，CLI 命令面包含 `nolon codex session list`、`preview-rewrite`、`rewrite`。

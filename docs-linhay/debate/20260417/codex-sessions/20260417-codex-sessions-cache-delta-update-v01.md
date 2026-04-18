# codex-sessions-cache-delta-update

**日期**：20260417  
**模式**：合作型  
**参与者**：Atlas（机制审查） / Goodall（一致性审查） / Curie（落地审查）  
**总轮次**：2 / 60  
**结束原因**：第 2 轮全员共识

## 执行元数据
- 候选参与者：Gemini CLI / Claude Code / Copilot CLI
- 首轮实际启用：Gemini CLI / Claude Code / Copilot CLI
- 后续 active participants：Atlas / Goodall / Curie（内部替补评审）
- 淘汰参与者：Gemini CLI / Claude Code / Copilot CLI
- 不可用原因：
  - `Gemini CLI`：非交互执行时触发浏览器登录确认，当前环境不可直接完成认证
  - `Claude Code`：默认模型不可访问，返回 `selected model ... may not exist or you may not have access`
  - `Copilot CLI`：本机未登录认证，返回 `No authentication information found`

## 辩论背景
> 用户追问：既然会话加载仍然慢，若引入独立数据库缓存，应该如何做“自动差量更新”，才能真正改善 `Codex Sessions` 的加载速度，同时避免把缓存做成新的真源。

## 确认的代码事实
- `CodexSessionsTabViewModel.reload()` 在初次加载时会先跑 project skeleton，再消费 `snapshotStream`；手动 refresh 则走单次 `loadSnapshot`。引用：
  - [CodexSessionsTabViewModel.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift#L536)
- `CodexSessionStore.snapshotStream()`、`loadSnapshot()`、`loadProjectSkeletonSnapshot()` 三条读路径都会重新执行扫描与解析前置工作。引用：
  - [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift#L323)
  - [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift#L418)
  - [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift#L452)
- `CodexSessionScanner.scanFiles()` 会全量列举 `sessions/` 和 `archived_sessions/` 下所有 `jsonl`，`readSessionMeta()` 会逐文件打开并读取到首条 `session_meta`。引用：
  - [CodexSessionScanner.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionScanner.swift#L95)
  - [CodexSessionScanner.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionScanner.swift#L127)
- `loadStateIndex()` 会遍历所有 `state*.sqlite`，再对每个库全表读取 `threads`。引用：
  - [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift#L854)
  - [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift#L906)
- 现有 `GeminiSessionUsageStore` 已经落地了“基于文件 fingerprint 的可丢弃缓存”模式：文件集命中、指纹不变则复用，写盘原子替换，读失败直接退回重建。引用：
  - [GeminiTokenTrendService.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/ProviderUsage/GeminiTokenTrendService.swift#L246)
  - [GeminiTokenTrendService.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/ProviderUsage/GeminiTokenTrendService.swift#L292)
  - [GeminiTokenTrendService.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/ProviderUsage/GeminiTokenTrendService.swift#L336)
- 4 月 17 日既有方案已经明确：第一阶段不上新数据库；若后续证明收益明显，第二阶段可以增加可丢弃磁盘缓存。引用：
  - [20260417-codex-sessions-loading-architecture-v01.md](/Users/linhey/Desktop/FlowUp-Libs/nolon/docs-linhay/debate/20260417/codex-sessions/20260417-codex-sessions-loading-architecture-v01.md#L52)
  - [2026-04-17-codex-sessions-loading-architecture-exec.md](/Users/linhey/Desktop/FlowUp-Libs/nolon/docs-linhay/plans/2026-04-17-codex-sessions-loading-architecture-exec.md#L82)

## 各轮观点记录

### 第 1 轮
**[Atlas - 机制审查]**  
论点：差量更新的边界必须按源文件划分，而不是按 UI batch 划分。  
引用：
- [CodexSessionScanner.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionScanner.swift#L83)
- [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift#L323)
- [CodexSessionsTabViewModel.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift#L872)  
代码事实：扫描器产出的是文件集合，Store 再把文件批量转换成 session rows，ViewModel 只是在消费这些 delta。  
结论：最优机制应是“源文件 fingerprint diff + 文件级 upsert/delete + 只重算受影响 project 聚合”，而不是整库 refresh。

**[Goodall - 一致性审查]**  
论点：独立 SQLite 只能做派生索引，不能进入 rollout / state sqlite 的写回链路。  
引用：
- [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift#L327)
- [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift#L1079)
- [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift#L1294)  
代码事实：现有实现读写都直接面向 rollout 文件、`state*.sqlite` 和 `session_index.jsonl`，缓存并不参与业务写回。  
结论：缓存必须定义成“可丢弃索引库”，否则会立刻演化成第二真源。

**[Curie - 落地审查]**  
论点：缓存边界应放在 `CodexSessionStore` 服务层，先让同一份 cache 同时服务 `snapshotStream`、`loadSnapshot` 和 skeleton 读路径。  
引用：
- [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift#L320)
- [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift#L418)
- [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift#L452)  
代码事实：三条读路径共享同一批扫描/解析前置工作，但现在是各做各的。  
结论：v1 应先做服务层读穿透 cache，保持 UI 零侵入、可回退。

### 第 2 轮（共识检测）
**[Atlas]**  
状态：`已共识`。  
依据：
- [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift#L309)
- [CodexSessionsTabViewModel.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift#L536)
- [CodexSessionsTabViewModel.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift#L1473)

**[Goodall]**  
状态：`已共识`。  
依据：
- [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift#L264)
- [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift#L546)
- [GeminiTokenTrendService.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/ProviderUsage/GeminiTokenTrendService.swift#L246)

**[Curie]**  
状态：`已共识`。  
依据：
- [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift#L320)
- [CodexSessionScanner.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionScanner.swift#L36)

## 最终结论与行动项

### 达成共识 / 主持人裁定
- 可以引入独立 SQLite 缓存，但它必须是**可丢弃索引库**，不能成为新的业务真源。
- 自动差量更新的最优机制是：
  - 维护源文件 inventory
  - 对 `rollout jsonl`、`session_index.jsonl`、`state*.sqlite` 分别记录 fingerprint
  - 以**文件级**为最小单位做 UPSERT / DELETE
  - 只重算受影响的 `session_row` 与 `project_aggregate`
  - `usage` 继续独立懒更新，不混入主缓存主链路
- v1 不应把 `state*.sqlite` 差量缓存也一起塞进去。原因不是它不重要，而是它是另一条高成本链路，首版混做会显著放大一致性和回归风险。
- v1 的正确边界应是：
  - 服务层内聚：缓存落在 `CodexSessionStore`
  - UI 零侵入：`CodexSessionsTabViewModel` 继续消费现有抽象
  - 可回退：缓存损坏、版本不匹配或指纹异常时，直接 fallback 到现有全量扫描实现

### 建议的自动差量更新算法
1. 启动或进入 `Sessions` 时，先执行轻量 inventory 扫描，读取每个 rollout 文件的 `fileIdentity + mtime + size`，并记录 `session_index.jsonl` 与 `state*.sqlite` 的 fingerprint。
2. 若 cache 中对应 inventory 未变，则直接读 `session_row` 和 `project_aggregate`，优先出首屏。
3. 若 inventory 有变化，则只对新增、变更、删除的 rollout 文件做解析：
   - 新增 / 变更：重建该文件对应的 session header 行
   - 删除：删除该文件对应的 session 行
4. 根据受影响 session 所属的 `projectPath`，只重算对应 `project_aggregate`，不全库重算。
5. `rewrite` / `migrate` 等已知写操作完成后，立即把受影响 thread / rollout 标脏，并触发一次 debounce reconcile。
6. App 激活与手动 refresh 只做 staleness check；若 fingerprint 未变，直接走 cache 命中。
7. `usage` 如需缓存，独立分表或分库，并继续保持后台懒回填。

### 行动项
| # | 行动 | 负责方 | 截止 |
|---|------|--------|------|
| 1 | 先补 `Codex Sessions` cache 差量更新 feature / plan 文档，明确 v1 边界只覆盖 rollout header + project aggregate | Codex | 实施前 |
| 2 | 设计 `CodexSessionCacheStore`，落在服务层，提供 `loadSnapshot` / `loadProjectSkeletonSnapshot` / `snapshotStream` 的统一读穿透入口 | Codex | phase 1 |
| 3 | 新增缓存命中 / 指纹未变 / 文件变更 / 文件删除 / 缓存损坏 fallback 测试 | Codex | phase 1 |
| 4 | 为 cache 增加 `cache_hit/miss`、`fingerprint_scan_ms`、`changed_file_count`、`upsert_row_count`、`fallback_rebuild_count` 等性能指标 | Codex | phase 1 |
| 5 | phase 2 再评估 `state*.sqlite` 差量缓存与 usage 独立缓存是否值得继续推进 | Codex | phase 2 评估 |

### 未解问题
- `state*.sqlite` 的差量缓存是否应该走文件级 fingerprint 后整库重建，还是需要更细的 thread 级增量，当前还未达成实现细节。
- 是不是需要文件系统 watcher 做准实时标脏，还是只靠“写后标脏 + app 激活 / refresh reconcile”就足够，仍需结合实际性能日志判断。

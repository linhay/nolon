# codex-session-minute-usage-cache

**日期**：20260421
**模式**：合作型
**参与者**：Codex 主持 / Zeno / Leibniz / Copilot（外援）
**总轮次**：4 / 60
**结束原因**：核心架构已共识，剩余差异收敛为实现分期

## 执行元数据
- 候选参与者：Gemini CLI / Claude Code / Copilot CLI / Zeno / Leibniz
- 首轮实际启用：Copilot / Zeno / Leibniz
- 后续 active participants：Copilot / Zeno / Leibniz
- 淘汰参与者：Gemini CLI / Claude Code
- 不可用原因：
  - Gemini CLI：最小探测超时，未在限定时间内返回有效输出
  - Claude Code：探测时模型不可用，无法进入首轮

## 辩论背景
用户确认两条用量口径可以合并，但要求合并方向以 `Codex Sessions` 为准，并指出后续还要支持“按天展开为分钟级日内曲线”。因此本轮讨论聚焦三个问题：

1. `Codex Usage` 与 `Codex Sessions` 是否应该统一到 session 语义。
2. 若统一，分钟级缓存是否应成为新的持久层真源。
3. 首发是采用“`usage_entries` + `session_usage_minutes`”两表最小集，还是首发就拆成三表。

本轮限定代码范围：
- `libs/Providers/Sources/Providers/Codex/CodexSessionUsageIndex.swift`
- `libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift`
- `libs/Providers/Sources/Providers/Codex/CodexSessionEventParser.swift`
- `libs/Providers/Sources/Providers/Codex/CostUsage/Vendored/CostUsageScanner.swift`
- `libs/Providers/Sources/ProviderUsage/CodexIntradayUsageService.swift`
- `libs/Providers/Sources/Providers/Codex/CostUsage/CodexQuarterHourUsageFetcher.swift`

## 各轮观点记录

### 第 1 轮
**[Zeno]**
- 论点：当前 `Codex Sessions` 用量读取已经收口到 `usageIndex`，合并方向应以 session 侧为主。  
  引用：`CodexSessionStore.swift:389-418`  
  代码事实：`loadSessionUsage`、`loadSessionTimeline`、`loadSessionUsageRecord` 都通过 `usageIndex.load(codexHome:rolloutPath:)` 取值。  
  结论：会话页和用量页继续分别依赖两套真源，会持续制造口径漂移。
- 论点：分钟级桶不应塞进 `usage_entries`。  
  引用：`CodexSessionUsageIndex.swift:223-257`, `CodexSessionUsageIndex.swift:332-351`  
  代码事实：`usage_entries` 的主键是 `(codex_home_path, rollout_path)`，字段结构是 rollout/source 级聚合摘要。  
  结论：分钟级序列应独立成表，而不是把时间桶硬塞进现有 entry 行。
- 论点：首发可以先走两表最小集。  
  引用：`CodexSessionUsageIndex.swift:357-368`  
  代码事实：当前 schema 已有平滑演进能力，后续可按需继续扩列或增表。  
  结论：先保留 `usage_entries`，再新增 `session_usage_minutes`，无需一开始就拆得过细。

**[Leibniz]**
- 论点：`usage_entries` 当前仍是 source/rollout 游标层，不应被误当成 session 真源本体。  
  引用：`CodexSessionUsageIndex.swift:23-36`, `CodexSessionUsageIndex.swift:332-349`  
  代码事实：entry 保存的是 rollout 路径、文件指纹、累计 totals、timeline，主键仍是 rollout。  
  结论：如果未来要做 session 统一口径，必须承认当前 SQLite 里还缺 session 级事实层。
- 论点：分钟真源应持久化为 UTC minute，而不是本地 `dayKey`。  
  引用：`CostUsageScanner.swift:77-91`, `CodexQuarterHourUsageFetcher.swift:71-79`  
  代码事实：现有 `dayKey` 与 intraday day range 都依赖 `Calendar.current` / `TimeZone.current`。  
  结论：如果继续把本地日期当持久真源，跨时区与日界切分会继续不稳定。
- 论点：session head / owner 语义最好有明确落点。  
  引用：`CodexSessionUsageIndex.swift:332-351`  
  代码事实：当前没有单独的 session head/source 表来描述“哪个 rollout 代表该 session 的 canonical source”。  
  结论：长期看更稳妥的是三表拆层，但可以接受首发阶段先复用 `usage_entries`。

**[Copilot]**
- 论点：现有 `CostUsage` 文件级缓存其实已经同时握有 `sessionId` 与 `quarterHours`。  
  引用：`CostUsageScanner.swift:135-163`, `CostUsageScanner.swift:305-313`  
  代码事实：扫描单个 Codex 文件时，会同时产出 `days`、`quarterHours`、`sessionId`，并写回 `cache.files[path]`。  
  结论：现状不是“没有 session + intraday 数据”，而是“session 与全局 quarterHours 聚合分裂在两层缓存里”。
- 论点：`CostUsage` 已经在扫描期按 session 去重。  
  引用：`CostUsageScanner.swift:251-259`, `CostUsageScanner.swift:288-316`, `CostUsageScanner.swift:329-349`  
  代码事实：`seenFileIds` 与 `seenSessionIds` 双重去重，避免同一 session 多个 rollout 重复贡献。  
  结论：minute 统一并不需要重造一套去重概念，而是应该复用现有 session 归因经验。
- 论点：当前日内曲线读取仍是纯全局口径。  
  引用：`CodexQuarterHourUsageFetcher.swift:50-67`, `CodexIntradayUsageService.swift:58-83`  
  代码事实：读取链路只从 `cache.quarterHours[dayKey]` 取全局 15 分钟桶，再在服务层映射成 15/30/60 分钟展示。  
  结论：若要让会话页与用量页对齐，不能继续把 global quarterHours 当唯一真源。

### 第 2 轮
**[主持人交叉问题]**
- 问题 1：既然 `reduceUsageLine(...)` 已经能产出带时间戳的 `tokenDelta`，是否应该把 minute buckets 直接并入 session SQLite？
- 问题 2：如果并入，首发是否必须同时落 `session_usage_heads` / `session_usage_sources`？

**[Zeno]**
- 论点：统一 ingest 切入点已经存在。  
  引用：`CodexSessionEventParser.swift:125-196`, `CodexSessionUsageIndex.swift:451-497`  
  代码事实：`reduceUsageLine(...)` 已返回 `tokenDelta(timestamp, model, input, cached, output)`，但 `parseUsageFile(...)` 目前只累计 totals / timeline，没有把 delta 分桶落库。  
  结论：最自然的改造是沿用同一遍 ingest，同时产出 totals + minute buckets。
- 论点：首发不必先引入第三张表。  
  引用：`CodexSessionUsageIndex.swift:332-351`  
  代码事实：`usage_entries` 已经保存 rollout/source 侧所需指纹和 session_id。  
  结论：读取侧先通过 `usage_entries` 聚合 session head/source 足够，第三张表可延后到复杂度真正出现时。

**[Leibniz]**
- 论点：我接受“同库 + 独立 minute table”的折中，但要明确这是分期，不是最终终态。  
  引用：`CodexSessionUsageIndex.swift:332-349`, `CodexSessionStore.swift:431-435`  
  代码事实：当前持久层能按 rollout 读取 entry，也能按 `session_id` 建索引，但没有 session 级事实行。  
  结论：首发两表可行，但文档必须写清楚“session head/source 语义仍暂借 rollout entry 投影”。
- 论点：minute 真源必须只存 UTC `minute_start_unix_ms`。  
  引用：`CostUsageScanner.swift:84-91`, `CodexIntradayUsageService.swift:150-172`  
  代码事实：现有读取侧本就会按传入 timezone 将 `dayKey + bucketKey` 投影成展示区间。  
  结论：持久层不应再额外保存本地天粒度衍生字段。

### 第 3 轮
**[Copilot 共识问卷]**
- 论点：`usage_entries` 不适合承载 minute buckets。  
  引用：`CodexSessionUsageIndex.swift:332-349`  
  代码事实：entry 行是 rollout 聚合快照，不是时间序列。  
  结论：应新增独立 minute table。
- 论点：首发支持两表最小集。  
  引用：`CodexSessionUsageIndex.swift:327-368`  
  代码事实：现有 SQLite 初始化与 schema 演进模式足以支撑平滑增表。  
  结论：`usage_entries` + `session_usage_minutes` 是可执行的第一阶段。
- 论点：minute 真源应使用 UTC。  
  引用：`CostUsageScanner.swift:84-91`  
  代码事实：现有 `dayKey` 来自本地 `Calendar.current`。  
  结论：minute 真源若继续保存本地日界，会把时间语义问题固化进存储层。

### 第 4 轮（最终收口）
**[Zeno]**
- 论点：核心架构已经达成共识。  
  引用：`CodexSessionStore.swift:413-417`  
  代码事实：会话用量加载已经统一收口到 `usageIndex.load(...)`。  
  结论：本轮剩余分歧只在“同库内 minute/source/head 表如何分期落地”，而不在“是否按 session 统一”。

**[Leibniz]**
- 论点：核心方向已共识，但仍需保留分层持久化的风险备注。  
  引用：`CodexSessionUsageIndex.swift:223-257`, `CodexSessionUsageIndex.swift:332-349`  
  代码事实：当前写入和主键仍以 rollout/source 语义为中心。  
  结论：应在裁定中明确“两表最小集是首发方案，不等于长期一定不需要 session head/source 表”。

## 最终结论与行动项

### 达成共识 / 裁定结论
- `Codex Usage` 与 `Codex Sessions` 的用量统一方向应以 `session` 语义为准，而不是继续以 `CostUsage` 全局 quarterHours 聚合结果为准。
- 统一后的持久层容器应放在现有 `usage-index-v1.sqlite`，避免继续维护“SQLite session totals/timeline”与“JSON global quarterHours”两套并行真源。
- `usage_entries` 应继续保留为 rollout/source ingest head，不适合直接塞分钟桶。
- 应新增独立的 `session_usage_minutes` 作为 minute 真源；同一遍 ingest 从 `CodexSessionEventParser.reduceUsageLine(...)` 产出的 `tokenDelta` 同步写出 totals 与 minute buckets。
- minute 真源应只存 UTC `minute_start_unix_ms` 与 token packed values；`dayKey`、15/30/60 分钟聚合、时区投影都应在读取侧计算。
- 首发推荐采用“两表最小集”：
  - `usage_entries`
  - `session_usage_minutes`
- `session head/source` 表不是当前阶段的必选项，但应作为明确的二期预案保留。

### 行动项
| # | 行动 | 负责方 | 截止 |
|---|------|--------|------|
| 1 | 在 `docs-linhay/dev/` 补一份分钟级 session usage cache 设计文档，明确 schema、backfill、读取投影与迁移策略 | Codex | 下一实现前 |
| 2 | 在 `docs-linhay/features/` 明确“Usage 与 Sessions 用量统一口径”的产品语义与验收场景 | Codex | 下一实现前 |
| 3 | 首发实现仅新增 `session_usage_minutes`，并补回归测试覆盖 totals、一分钟分桶、跨时区投影与去重 | Codex | 实现阶段 |
| 4 | 若后续出现 canonical rollout 归属、session owner/source 不稳定，再评估新增 `session_usage_heads` / `session_usage_sources` | Codex | 二期评估 |

### 未解问题
- 分钟桶的 packed value 是否继续沿用 `[input, cached, output]`，还是抽成更明确的列式 schema，需要在正式设计文档里定稿。
- 首次迁移时是否需要将历史 `CostUsage` 文件级 `quarterHours + sessionId` 回填入新表，还是允许惰性重扫生成，需要结合启动时延与磁盘体积评估。
- 当同一 session 存在多个 rollout/source 候选时，现阶段读取侧已确认采用“按逻辑 session 合并，同一分钟对 token 字段取最大值”的策略；若后续需要解释具体 owner/source，再在二期补独立 head/source 设计。

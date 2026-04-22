# Codex Session Minute Usage Cache 设计（2026-04-21）

## 背景

2026-04-17 已经为 `Codex Sessions` 落地 `usage_entries` 独立索引，用于优化每个 rollout 的 totals / timeline 读取。2026-04-21 的新增目标是把 `Codex Usage` 的日级 trend 与单日 intraday 也统一到 session usage 方向，避免继续并行维护：

1. `usage-index-v1.sqlite`
2. `CostUsageCacheIO` 中的 global `days / quarterHours`

本设计遵循 2026-04-21 debate 的“两表最小集”裁定：首发先保留 `usage_entries`，新增 `session_usage_minutes`，将 `session head/source` 语义暂时放到读取侧投影。

## 目标

1. 在现有 `usage-index-v1.sqlite` 中新增 Codex 分钟级事实表。
2. 复用 `CodexSessionEventParser.reduceUsageLine(...)`，在同一遍 rollout ingest 中同时产出：
   - session totals
   - timeline
   - UTC minute buckets
3. 把 `CodexTokenTrendService` 与 `CodexIntradayUsageService` 都切到同一条 session truth 读取链路。

## 非目标

1. 本轮不新增第三张 `session_usage_heads` / `session_usage_sources` 表。
2. 本轮不移除旧 `CostUsageScanner` 与 `CostUsageCacheIO`，但它们不再作为 Codex Usage 的默认真源。
3. 本轮不做 FTS、state projection 或新的 UI 结构调整。

## 现有代码事实

1. `usage_entries` 当前主键是 `(codex_home_path, rollout_path)`，明确承担 rollout/source ingest head 语义，而不是时间序列语义。  
   引用：`libs/Providers/Sources/Providers/Codex/CodexSessionUsageIndex.swift`
2. `CodexSessionEventParser.reduceUsageLine(...)` 已能产出带时间戳的 `tokenDelta(timestamp, model, input, cached, output)`。  
   引用：`libs/Providers/Sources/Providers/Codex/CodexSessionEventParser.swift`
3. `CodexIntradayUsageService` 当前仍从 `CodexQuarterHourUsageFetcher` 读取 `dayKey -> HH:mm -> [input, cache, output]` 的 global quarterHours。  
   引用：`libs/Providers/Sources/ProviderUsage/CodexIntradayUsageService.swift`
4. `CostUsageScanner` 当前已经证明“同一遍扫描同时产出 totals + day + quarterHours”是可行的。  
   引用：`libs/Providers/Sources/Providers/Codex/CostUsage/Vendored/CostUsageScanner.swift`

## 方案总览

### 1. 表结构

继续保留 `usage_entries`，新增 `session_usage_minutes`：

| 列 | 类型 | 说明 |
|---|---|---|
| `codex_home_path` | TEXT | `CODEX_HOME` 绝对路径 |
| `rollout_path` | TEXT | rollout 相对路径 |
| `session_id` | TEXT | 从 `session_meta` 解析出的 session id，可空 |
| `minute_start_unix_ms` | INTEGER | UTC minute 起点 |
| `input_tokens` | INTEGER | 该 minute 的输入 tokens |
| `cached_input_tokens` | INTEGER | 该 minute 的 cached input tokens |
| `output_tokens` | INTEGER | 该 minute 的输出 tokens |
| `updated_at_unix_ms` | INTEGER | minute facts 最近写入时间 |

约束：

1. 主键：`(codex_home_path, rollout_path, minute_start_unix_ms)`
2. 辅助索引：`(codex_home_path, session_id, minute_start_unix_ms)`

选择 source-level 主键而不是 `session_id + minute` 的原因：

1. `session_id` 在 ingest 早期仍可能为空。
2. 首发阶段重复 session/source 的 canonical 判定尚未独立持久化。
3. full rebuild / fileMissing 时需要按 rollout/source 精准清理旧 minute rows。

### 2. ingest 改造

在 `CodexSessionUsageIndex.parseUsageFile(...)` 内部新增 minute 聚合字典：

1. 保留现有 `sessionID / model / totals / timeline / parsedBytes` 更新逻辑。
2. 当 `reduction.tokenDelta` 存在且能解析出 `Date` 时：
   - 转成 UTC
   - 向下取整到 minute 起点
   - 累加到 `minuteBuckets[minuteStartUnixMs]`
3. `CodexSessionUsageParseResult` 增加 `minuteBuckets`
4. `load(...)` 在：
   - `fullRebuild` 时先删除该 rollout 旧 minute rows，再整批写入新 rows
   - `deltaAppend` 时只 upsert tail 新增或受影响的 minute rows
   - `fileMissing` 时同步删除 `usage_entries` 与该 rollout 的 minute rows

### 3. 读取侧投影

由于首发不建 `session head/source` 表，读取侧必须承担逻辑会话归并：

1. 全局 trend / intraday 的 source 集合来自当前可见 rollout/source 集合。
2. 首发默认读取策略：
   - 对有 `session_id` 的 minute rows，先按 `session_id + minute_start_unix_ms` 归并为同一逻辑会话的同一分钟
   - 归并时对 `input / cached / output` 分别取 `MAX(...)`
   - 对 `session_id == nil` 的 minute rows，按 `rollout_path + minute_start_unix_ms` 原样纳入
3. 该策略只存在于读取侧 SQL / 聚合逻辑中，不写回持久层。
4. 采用“同一分钟取最大值”而不是“同一分钟求和”的原因：
   - 重复 rollout 常见于同一逻辑会话被拆成 live / archived 或多段 source 文件
   - 这些文件在重叠分钟通常表达的是同一批 token facts，而不是额外增量
   - 直接求和会把重复分钟双算；只选 canonical rollout 又会漏掉被拆到其他 rollout 的非重叠分钟
5. 若后续需要更细的 owner/source 归因，再评估单独持久化 `session_usage_heads` / `session_usage_sources`

### 4. Daily Trend

`CodexTokenTrendService` 默认 loader 改为基于 session usage index 生成 `CostUsageTokenSnapshot`：

1. 扫描当前 `codexHome/sessions` 与 `archived_sessions`
2. 对每个 rollout 调 `usageIndex.load(...)`，确保 `usage_entries + session_usage_minutes` 完整
3. 按逻辑会话维度归并 minute rows，并对重复 rollout 的同一分钟取 token 最大值
4. 按当前 timezone 将 UTC minute 投影到本地 `dayKey`
5. 生成 `CostUsageDailyReport.Entry[]` 与 `sessionTokens / todayInput / todayOutput / todayCached`

### 5. Intraday

`CodexQuarterHourUsageFetcher` 与 `CodexIntradayUsageService` 切到同一条 minute truth：

1. fetcher 先确保当前 source 集合对应 rollout 已完成 ingest
2. 从 `session_usage_minutes` 取指定本地 `dayKey` 对应的 UTC minute rows
3. 在读取侧按 timezone 投影到本地时间
4. 再折叠回当前兼容类型 `CodexQuarterHourUsageDay` 或直接生成 `ProviderIntradayUsageSnapshot`

首发为了最小改造，可以保留 `CodexQuarterHourUsageDay` 兼容层：

1. minute truth -> quarterHour packed
2. `CodexIntradayUsageService` 继续复用既有 `15 / 30 / 60` bucket 逻辑

### 6. backfill 策略

首发不强制全量历史预扫，但要避免“新旧真源并存”导致用户感知错乱：

1. 默认首次打开 `Codex Usage` 或请求 `Codex Sessions` usage 时，按当前 rollout/source 集合惰性建索引
2. 若未来需要最小历史 backfill，优先复用：
   - `CodexSessionScanner.scanFiles(...)`
   - `CodexSessionUsageIndex.parseUsageFile(...)`
3. 不再从 `CostUsageScanner.loadDailyReport(...)` 反推 minute truth

## 风险与护栏

### 风险 1：重复 session/source 双算

护栏：

1. 测试层补“重复 session 去重”用例
2. 读取侧逻辑会话归并规则必须稳定且可解释
3. 二期若出现更多复杂谱系，再新增 `session_usage_heads` / `session_usage_sources`

### 风险 2：full rebuild 后残留旧 minute rows

护栏：

1. full rebuild 前必须删该 rollout 的旧 minute rows
2. `fileMissing` 时同步删 entry 与 minute rows
3. 增加 `CodexSessionStoreTests` 覆盖这两条路径

### 风险 3：跨时区 / 跨午夜错投影

护栏：

1. 持久层只存 UTC minute
2. `dayKey` 与桶聚合全部在读取侧按目标 timezone 算
3. 补跨时区投影测试

## 2026-04-21 晚间补充：文件级增量索引收敛

### 新现场问题

用户继续反馈的慢点并不只属于“今天刷新慢”：

1. `Codex Usage` 的手动刷新虽然已经不再直接重扫所有 JSONL，但 `CodexSessionStore.loadProjectedUsageMinutes(...)` 仍会遍历当前 rollout/source 集合，对每个文件执行 `loadSessionUsageRecord(...)`。
2. 当前 usage index 的增量判定主要依赖 `(absolute path, file id, mtime, size)` 这一组文件属性指纹。
3. 对已经归档且内容冻结的 rollout 来说，这种判定会把“仅 metadata 变化”也当成潜在变更，导致无意义的重复校验甚至重建。

### 收敛决策

本轮把问题正式收敛为“文件级增量索引模型”而不是“Today 特判优化”：

1. `usage_entries` 继续承担 source ingest head，但要显式保存文件级内容身份与观测状态。
2. 新增字段：
   - `content_hash`
   - `last_seen_at_unix_ms`
   - `last_requested_at_unix_ms`
   - `is_archived`
3. 对 `archived_sessions/` 下的 rollout，首次 full rebuild 后写入 `content_hash`，后续若 entry 已标记 `is_archived == true` 且 minute rows 仍在，则直接命中缓存，只更新 request/seen 时间，不再因 mtime 变化重算。
4. `loadProjectedUsageMinutes(...)` 必须把 scanner 已知的 `archived` 状态传到 usage index，而不是只从 `rolloutPath` 做弱推断。

### 为什么这样定

1. live rollout 的常见变化模式是 append，保留现有 `file id + size + parsed bytes` 的 delta append 路径最划算。
2. archived rollout 的常见模式是“不再变化”，此时内容 hash 比 mtime/size 更接近真正的文件身份。
3. 用 `last_seen_at / last_requested_at` 记录观测时间后，后续可以做：
   - 冷热分层
   - 慢速后台抽检
   - 更细的增量回填策略
4. 这套模型是通用 rollout/source 索引策略，不只服务某一天或某一张图表。

### BDD 补充

1. Given 某个 archived rollout 首次已建立 usage index 且写入 `content_hash`，When 文件只发生 metadata 变化，Then 再次读取 session usage 时直接返回 `cacheHit`，并保留原先的 minute facts。
2. Given projected usage 会遍历 live + archived 的 rollout/source 集合，When archived rollout 只有 mtime 变化，Then 全局 minute projection 仍应复用该 archived cache entry，不得触发该文件的 full rebuild。
3. Given 非 archived 的 live rollout 继续 append，When usage index 命中 append 条件，Then 仍走 delta append，不受 archived shortcut 影响。

## 2026-04-21 深夜补充：全量文件集判脏，而不是“最近两天文件”

用户后续明确补充后，本设计对“刷新范围”做了进一步收敛：

1. 文件层的 scope 必须始终是当前全量 rollout/source 文件集。
2. “最近两天”只能是旧实现里展示层回填的窗口，不能再作为底层文件筛选条件。

### 新决策

1. `CodexSessionStore` 在手动刷新链路里先扫描全量文件清单，但只读取 metadata。
2. dirty rollout 判定改为文件级：
   - usage index 中不存在的新文件
   - live 文件的 `file id / mtime / size` 变化
   - archived 文件尚未建立 `content_hash`
   - archived 状态变化
3. 只对 dirty rollout 重新执行 `loadSessionUsageRecord(...)`。
4. dirty rollout 刷新前后的 minute rows 会映射成受影响的 `dayKey` 集合。
5. `CodexTokenTrendService` 再按这些受影响 day keys 逐日回填 cached full snapshot，而不是固定重算“最近两天”或整段全历史 points。

## 2026-04-22 补充：forked/subagent rollout 只统计派生后的新增 delta

### 新现场问题

用户在 `Codex Usage` 与 `Codex Sessions` 对比 proxy 数据时发现，带 `forked_from_id` 的派生 rollout 会把父线程继承过来的首个 cumulative total 一起算进子线程，导致本地投影总量显著放大。

### 收敛决策

1. 若 rollout 的首个 `session_meta` 含 `forked_from_id`，则把第一条可识别的 cumulative `total_token_usage` 视为 inherited baseline。
2. 这条 baseline 只用于建立派生线程自己的 raw totals 起点，不写入 `session_usage_minutes`，也不计入 `usage_entries.totals` 对外暴露的 totals。
3. 由于当前 schema 只持久化“展示 totals”，没有额外持久化 raw baseline，派生 rollout 一旦文件变化，禁止继续走 `deltaAppend`，统一退回 `fullRebuild`。
4. 非派生 rollout 继续保持现有 append delta 逻辑，不受这次语义调整影响。

### 为什么这样定

1. 用户要的不是“忽略 subagent/forked”，而是“只统计 fork 之后真实新增的用量”。
2. 派生 rollout 的第一条 cumulative total 常常已经包含父线程历史上下文，不扣 baseline 会把 inherited usage 错算成 child usage。
3. 在不改 SQLite schema 的前提下，`derived -> full rebuild on change` 是最稳的做法，可以避免旧缓存里丢失 raw baseline 后再次 append 时重复计数。

### BDD 补充

1. Given 派生 rollout 首个 `session_meta.forked_from_id` 非空，When 第一条 cumulative `total_token_usage` 被读取，Then 它只建立 baseline，不进入 minute facts，也不计入最终 totals。
2. Given 派生 rollout 后续又 append 了新的 cumulative total，When usage index 再次刷新该文件，Then 系统必须 `fullRebuild`，并继续只保留 fork 后新增 delta。

### 性能日志字段

`refreshChangedProjectedUsageDayKeys(...)` 现在会发 `performanceNotification`，`operation = refresh_projected_usage_day_keys`，方便区分“这轮手动刷新到底扫了多少、真刷新了多少、为什么刷新”：

1. 基础规模字段：
   - `scanned_file_count`
   - `cached_entry_count`
   - `removed_rollout_count`
   - `skipped_rollout_count`
   - `affected_day_key_count`
2. 实际刷新结果：
   - `refreshed_live_rollout_count`
   - `refreshed_archived_rollout_count`
3. 判脏原因分桶：
   - `new_rollout_count`
   - `live_fingerprint_changed_count`
   - `archived_hash_missing_count`
   - `archived_state_changed_count`
   - `fingerprint_unavailable_count`
4. 上下文与耗时：
   - `timezone_identifier`
   - `codex_home_path`
   - `trace_id`
   - `elapsed_ms`

这组字段的目标不是做展示，而是帮助后续判断瓶颈到底来自新 rollout 建索引、live 文件属性变化、archived 历史补 hash，还是底层文件指纹读取异常。

### archived repair 约束

针对 `archived_hash_missing` 与 `archived_state_changed` 两类原因，刷新链路不能只把文件判成 dirty 却仍旧走普通 fingerprint cache hit。

当前约束是：

1. 若当前文件已被 scanner 识别为 archived，但索引里的 `is_archived` 或 `content_hash` 还未收敛，则 `CodexSessionUsageIndex.load(...)` 必须跳过普通 fingerprint cache hit。
2. 这类 rollout 需要进入真正的 archived 修复路径，补齐：
   - `is_archived`
   - `content_hash`
3. 否则它们会在后续每次手动刷新时反复落入相同的判脏原因分桶，破坏“冻结文件只修一次”的目标。

### BDD 补充

1. Given 手动刷新开始时本地存在大量 rollout/source 文件，When 系统执行增量刷新，Then 必须先面对全量文件集判定 dirty rollout，而不是先裁成“最近两天文件”。
2. Given 只有少数 dirty rollout 发生变化，When 系统回填 token trend snapshot，Then 只更新这些 dirty rollout 实际影响到的 day keys。
3. Given 某个 rollout 没有变化，When 同轮手动刷新执行，Then 它的 usage entry `lastRequestedAt` 不应被无意义推进。
4. Given 本轮全量文件判脏后没有任何受影响 day key，When `CodexTokenTrendService.fetchRefreshedGlobalSnapshot(...)` 被调用，Then 应直接返回 cached full snapshot，且不触发任何 day-level projected usage reload。
5. Given archived rollout 因 `content_hash` 缺失或 `is_archived` 漂移而被判脏，When 刷新链路真正执行读取，Then 它必须修复索引中的 archived 身份信息，而不是继续停留在可重复触发的半修复状态。

## 测试计划

最低安全线共 5 条：

1. `CodexSessionStoreTests.loadSessionUsageBuildsMinuteBucketsOnFirstRead`
2. `CodexSessionStoreTests.loadSessionUsageAppendsOnlyNewMinuteBucketsForTailDelta`
3. `CodexSessionStoreTests.loadSessionUsageFullRebuildReplacesStaleMinuteBuckets`
4. `CodexIntradayUsageServiceTests.fetchSessionSnapshotProjectsUTCMinutesAcrossTimezones`
5. `CostUsageStoragePathTests.costUsageScannerDeduplicatesDuplicateSessionAcrossFiles`

若实现过程中需要补充 guard，再追加：

1. `CodexTokenTrendServiceTests` 针对日级 snapshot 的 session truth 聚合用例
2. `CodexSessionEventParserTests` 针对同一分钟 mixed token delta 的稳定性用例
3. `CodexSessionStoreTests.loadSessionUsageReturnsCacheHitForArchivedRolloutWhenOnlyMetadataChanges`
4. `CodexSessionStoreTests.loadProjectedUsageMinutesReusesArchivedCacheEntryWhenOnlyMetadataChanges`

## 实施顺序

1. 先补 feature / dev 文档
2. 先写 Provider 红灯测试
3. 再实现 `session_usage_minutes` 与读取 API
4. 切 `CodexTokenTrendService`
5. 切 `CodexIntradayUsageService`
6. 跑定向测试并回写 memory

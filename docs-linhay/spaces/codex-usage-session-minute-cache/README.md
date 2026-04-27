# Codex Usage / Sessions 统一分钟级口径规格（2026-04-21）

## 背景

`Codex Sessions` 与 `Codex Usage` 当前仍分别依赖两条 Provider 用量链路：

1. `Codex Sessions` 的行内用量、组头聚合、排序依赖 `usage-index-v1.sqlite` 中的 rollout usage index。
2. `Codex Usage` 的日级趋势与日内钻取依赖 `CostUsageScanner + CostUsageCacheIO` 的全局 `days / quarterHours` cache。

这会带来三个持续问题：

1. 同一份本地会话数据会被两套链路重复扫描与缓存。
2. 用户会看到 `Sessions` 与 `Usage` 在天数覆盖、总量、日内曲线上的口径不一致。
3. `Usage` 页的分钟级钻取无法天然与会话视角对齐。

关联文档：

- `docs-linhay/spaces/codex-sessions-tab/debate/20260421/codex-sessions/20260421-codex-session-minute-usage-cache-v01.md`
- `docs-linhay/spaces/provider-usage-intraday-drilldown/README.md`
- `docs-linhay/dev/codex-sessions-usage-index-design-2026-04-17.md`

## 目标

1. `Codex Usage` 与 `Codex Sessions` 统一到同一条 session 语义 Provider 真源链路。
2. 为 Codex 建立可持久化的分钟级事实缓存，用于支持日级 trend 与日内 drilldown。
3. 继续保持：
   - 原始 rollout JSONL 是唯一事实源
   - `30min / 60min` 只做读取时派生
   - App 层继续只消费既有 `ProviderTokenTrendSnapshot` / `ProviderIntradayUsageSnapshot`

## 非目标

1. 本轮不为 Codex 增加第三张 `session_usage_heads` / `session_usage_sources` 持久化表。
2. 本轮不修改 Claude / Gemini 的用量链路。
3. 本轮不引入新的 UI 规格或新的 Usage section。
4. 本轮不要求首发就对所有历史 rollout 做全量强制 backfill。

## 产品语义

### 统一方向

1. `Codex Usage` 与 `Codex Sessions` 的用量语义统一按 session 方向收口。
2. `Sessions` 中每个会话的 row / group usage 与 `Usage` 中全局 trend / intraday 都必须来自同一条 session usage 索引链路。
3. `CostUsageCacheIO` 的全局 `days / quarterHours` 不再作为 Codex Usage 的长期真源。

### 分钟级事实

1. Codex 的分钟级事实缓存以 UTC minute 为唯一持久化时间键。
2. 本地 `dayKey`、时区投影、`15min / 30min / 60min` 聚合都放在读取侧完成。
3. `30min / 60min` 不单独持久化。
4. 对首个 `session_meta.forked_from_id` 非空的派生 rollout，第一次出现的 cumulative `total_token_usage` 只作为 inherited baseline，不计入派生线程新增用量。

### 数据覆盖

1. 首发允许分钟级事实缓存按“扫描到的 rollout/source 集合”逐步构建。
2. 对用户可见的全局 trend / intraday，必须优先从当前可见 session/source 集合投影，不能混回旧的 global quarterHours cache。
3. 若某些历史 rollout 尚未进入新索引，允许首发阶段通过 provider 内部补扫构建，但不得再从独立 `CostUsage` 真源回填 UI。

## 读取与刷新规则

### Daily Trend

1. `Codex Usage` 日级 trend 改为从 session minute 真源聚合。
2. `7D / 30D / ALL` 仍保持当前交互语义不变。
3. summary cards 的 `Today / 7D / 30D / ALL` 必须与同一份 session truth 对齐。

### Intraday Drilldown

1. `Codex Usage` 单日钻取继续支持 `15min / 30min / 60min`。
2. bucket 切换只基于同一份分钟级事实缓存派生。
3. Today 仍需隐藏未来时间桶；历史日仍只展示实际发生过用量的时间桶。

### Sessions

1. `Codex Sessions` 的行内 usage、组头 usage、usage 排序继续复用 usage index，不新增 UI 语义。
2. 本轮新增的 minute truth 不应改变 `Sessions` 现有交互，只为统一 Provider 真源与图表能力服务。

## BDD 验收

1. Given 同一份 Codex 本地会话历史，When 用户查看 `Codex Sessions` 的会话用量并再打开 `Codex Usage`，Then 两处总量口径应来自同一条 session usage 索引链路。
2. Given `Codex Usage` 打开日级趋势图，When 用户点击某一天进入 intraday，Then 该日分钟级曲线应由 session minute 真源派生，而不是从独立 global quarterHours cache 读取。
3. Given 同一分钟内存在多条 token delta，When Provider 构建分钟事实缓存，Then 同一分钟的 `input / cached / output` 会被正确累计，不得丢失或重复。
4. Given rollout 文件只发生尾部 append，When Provider 再次读取该会话 usage，Then 只补写新增 minute buckets，并保持旧 minute buckets 不变。
5. Given rollout 文件被替换或截断，When Provider 再次读取该会话 usage，Then 旧 minute buckets 会被清理并按新文件 full rebuild。
6. Given 同一 session 同时出现在多个 rollout/source 文件中，When Provider 构建全局 trend / intraday，Then 读取侧必须按逻辑会话合并，并对重复 rollout 的同一分钟只取一次有效 token facts，不得双算也不得漏掉非重叠分钟。
7. Given 用户在非 UTC 时区查看某一天的 intraday，When Provider 投影 UTC minute truth，Then 该天的 `dayKey`、桶区间和跨午夜切分都必须按当前时区正确落位。
8. Given 当前选中日期是 Today，When 渲染 intraday 曲线，Then 未来时间桶不会显示。
9. Given 某些 rollout 已经进入 `archived_sessions/` 且内容冻结，When 用户触发 `Codex Usage` 或 `Codex Sessions` 刷新，Then 系统应复用这些文件已有的 usage index，不再因为 metadata 变化重复重算。
10. Given 用户触发 `Codex Usage` 手动刷新，When 系统检查本地 session rollout，Then 底层必须面对全量文件集判定哪些文件真的变脏，而不是先把文件集合缩成“最近两天”。
11. Given 只有少数 dirty rollout 发生变化，When 系统回填 token trend snapshot，Then 只更新这些 dirty rollout 实际影响到的 day keys，而不是重建整个历史图表。
12. Given 某个 rollout 的首个 `session_meta` 带有 `forked_from_id`，When Provider 读取它的第一条 cumulative `total_token_usage`，Then 这条 usage 只用于建立派生 baseline，最终 trend / summary / session usage 只统计 fork 之后新增的 delta。

## 实施约束

1. 设计与持久化逻辑放 `libs/Providers/Sources/Providers/Codex/`。
2. `ProviderUsageRegistry`、`CodexTokenTrendService`、`CodexIntradayUsageService` 可以调整默认读取链路，但 App 层不得直接感知 SQLite minute 表。
3. 先补 Provider 测试，再实现。
4. 文件级增量索引默认遵循：
   - live rollout 继续走属性指纹 + append delta
   - archived rollout 在内容 hash 已建立后，优先视为冻结文件并直接复用缓存

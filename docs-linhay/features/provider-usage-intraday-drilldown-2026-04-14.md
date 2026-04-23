# Provider Usage 单日钻取规格（2026-04-14）

## 背景

当前 `Usage` 页已有日级 `历史 Token 消耗` 趋势图，但缺少对某一天更细粒度消耗的查看能力。

经过 2026-04-14 多轮 debate 与多 agent 复核，最终方案已经收敛为：

1. 主图继续保持日级趋势图。
2. 用户点击某一天后，进入该天的单日钻取。
3. 单日钻取默认 `30min`，并按 provider 精度提供可切换的分钟粒度。
4. `Today` 不再是独立模式，只是日级图中的一天。

关联辩论文档：

- `docs-linhay/debate/20260414/codex-usage/20260414-intraday-usage-curve-v01.md`

## 目标

1. 在不破坏现有日级趋势图语义的前提下，提供单日分钟级钻取能力。
2. 保持 Gemini / Codex 在数据模型与聚合口径上的一致性。
3. 用最小复杂度完成 Phase 1 可交付版本，不引入准实时 watcher 或独立业务事实源，但允许 provider 内部做解析缓存以控制加载成本。

## 范围

包含：

1. 日级趋势图点选进入单日钻取。
2. 单日钻取按 provider 精度提供分钟粒度切换。
3. intraday snapshot 独立模型、能力位、刷新与失效规则。
4. Gemini Phase 1 即时聚合与共享解析缓存。
5. Codex Phase 2 的 `15min` 基准桶设计方向。

不包含：

1. 准实时 watcher / 高频 polling。
2. `Today` 独立模式。
3. 第二排独立 intraday summary 卡片。
4. 跨账号合并单日钻取。
5. 分钟级事实桶的独立持久化缓存层。

## 2026-04-15 性能修正

针对“历史 Token 消耗加载过慢”的问题，本轮补充以下实现约束：

1. 首屏仍然只加载日级 `Daily Trend`，不主动预取 intraday。
2. 用户点击具体某一天后，才触发 `Intraday Drilldown` 的分钟级聚合。
3. Gemini 允许在 provider 内部维护 `session usage store`：
   - 原始 `.gemini` session 文件仍然是唯一事实源
   - cache 只保存解析后的 `daily totals` 与带时间戳的 token events
   - cache 命中键使用 `文件路径 + mtime + size`
4. `Daily Trend` 与 `Intraday Drilldown` 必须复用同一份 Gemini 解析缓存，避免用户先看日级再点日内时重复全量读原始 session JSON。
5. Codex 的 `Daily Trend` 查询必须把 `trailingDays` 下推到底层 loader，而不是先取全量再裁剪。

## 最终交互

### 主图

1. `历史 Token 消耗` 主图仍然是日级趋势图。
2. `7D / 30D / ALL` 继续存在，语义不变。
3. 未点选具体日期前，不显示分钟级钻取内容。

### 单日钻取

1. 用户点击某一个日级点位后，在同一 section 内以内联展开方式显示该日钻取内容。
2. 钻取默认 bucket 为 `30min`。
3. 用户可切换的 bucket 按 provider 精度决定：
   - `Codex`: `1min / 15min / 30min / 60min`
   - `Gemini / Claude / Antigravity`: `1min / 5min / 10min / 15min / 30min / 60min`
4. 钻取打开后：
   - 主图仍然可见
   - 主图仍允许 range 切换与 hover
   - 但必须锁定当前 `selected day`，不能因主图交互而丢失或改写当前钻取对象

### 布局

1. `Daily Trend` 与 `Intraday Drilldown` 收敛为同一个 `Trend Workspace`。
2. `Trend Workspace` 顶部使用 segmented control 在 `Daily Trend` 与 `Intraday Drilldown` 间切换。
3. 用户在 `Daily Trend` 中点击某一天后，页面应自动切换到 `Intraday Drilldown`，并展示该日的分钟级视图。
4. `Daily Trend` 视图采用 `图 + 表` 结构：
   - 上半区为日级趋势图
   - 下半区为 `Daily Breakdown`
5. `Intraday Drilldown` 视图也采用 `图 + 表` 结构：
   - 上半区为分钟级趋势图
   - 下半区为 `Intraday Breakdown`
6. `Trend Workspace` 的滚动语义按页面模式区分：
   - `combined` 页：图区跟随整页滚动，不引入额外内部滚动；
   - `usage` 独立 tab：图区固定在 tab 视口内，下方表格在 workspace 内部独立滚动。
7. `Intraday Breakdown` 的时间列必须展示完整时间段，例如 `09:30-10:00`，而不是只展示桶起点。

### UI 反馈要求

1. 钻取区必须展示当前粒度与实际桶数，例如 `30min · 48 桶`。
2. 不支持 drilldown 的 provider，必须显式禁用或给出原因提示。
3. 历史日必须展示“静态快照 / 手动刷新”语义。
4. 单日钻取图表必须只保留有用量的时间桶，所有零用量桶都不显示，包括中间零桶。
5. 当选中日期是 Today 时，分钟级图表不得展示当前时刻之后的未来时间桶。
6. 钻取区必须展示当前可见桶摘要，并明确说明该视图只展示有用量时段。
7. `Daily Trend` 需要支持 `Bars / Line` 两种图表模式：
   - `Bars` 展示 `input / output / cache`
   - `Line` 只展示 `total`
8. `Bars / Line` 的显示选择需要记住，避免用户每次回到 `Usage` 页都重设。
9. bucket picker 必须是 provider-aware：
   - `Codex` 可以暴露 `1min`，因为当前已改为基于 projected minute usage 聚合，不再受 quarter-hour facts 限制。
   - `Codex` 仍暂不暴露 `5min / 10min`，保留“极细核对 + 常用汇总”两档语义，避免 bucket rail 过长。
   - `Gemini / Claude / Antigravity` 可以暴露 `1min / 5min / 10min`，因为它们基于事件时间戳聚合。

## 数据模型规则

### capability

```swift
public enum ProviderUsageCurveCapability: Sendable, Equatable {
    case dailyOnly
    case dailyWithIntradayDrilldown
}
```

### intraday snapshot

intraday snapshot 至少需要包含：

1. `dayKey`
2. `timezoneIdentifier`
3. `bucket`
4. `actualBucketCount`
5. `rangeStart`
6. `rangeEnd`
7. `fetchedAt`

规则：

1. `dayKey` 固定定义为 `timezoneIdentifier` 下的本地自然日。
2. 所有对账与聚合口径必须基于：
   - 同一 `dayKey`
   - 同一 `timezoneIdentifier`
   - 同一份 intraday snapshot

## 聚合与缓存口径

1. 原始 provider session 文件是唯一事实源。
2. provider 内部允许维护解析缓存，但不得引入与原始 session 并行的第二份业务事实源。
3. 所有 bucket 都只做派生展示，不再单独保存事实缓存。
4. DST 场景下不允许任何层假设固定桶数：
   - `5min`: `276 / 288 / 300`
   - `10min`: `138 / 144 / 150`
   - `15min`: `92 / 96 / 100`
   - `30min`: `46 / 48 / 50`
   - `60min`: `23 / 24 / 25`
5. 钻取展示口径允许在事实桶之上做 presentation trim：
   - 去掉所有零桶
   - Today 去掉未来时间桶
   - 只保留实际发生过用量的时间桶

## Provider 分阶段要求

### Gemini Phase 1

1. 首屏只加载日级 trend，点击选中日后再拉 intraday。
2. 允许 provider 内部使用文件级解析 cache，但原始 session 文件仍然是事实源。
3. 日级 trend 与单日 intraday 必须复用同一份解析缓存，避免双重全量扫描。
4. `5/10/15/30/60min` 都只做派生展示，不单独保存事实缓存。

### Codex Phase 2

1. 必须继续走 `scanner / cache / fetcher` 正式链路。
2. cache 基准粒度升级为 `minute` projection，并允许在展示层继续派生 `1min / 15min / 30min / 60min`。
3. 不允许 App 层临时扫某一天的 rollout/session 作为平行数据源。
4. `Codex` 的 `Intraday Drilldown` 必须直接复用 `projected usage minute entries`，不得把 quarter-hour packed buckets 伪装成 `1min`。

## 刷新与失效规则

### Today

以下任一事件发生时，当前 Today 钻取结果失效并需要重取：

1. 跨到下一个本地自然日。
2. `timezoneIdentifier` 发生变化。
3. 用户主动刷新。

### 历史日

1. 默认视为静态历史快照。
2. 仅在手动刷新时更新。

## BDD 验收

1. Given 日级趋势图已渲染，When 用户点击某一天，Then 在同一 section 内展开该天的单日钻取且默认展示 `30min`。
2. Given 单日钻取已打开，When 用户切换到当前 provider 支持的任一 bucket，Then 当前 `selected day` 不变且总量口径与同一份事实桶保持一致。
3. Given 单日钻取已打开，When 用户切换主图 `7D / 30D / ALL`，Then 当前 `selected day` 继续锁定，不得丢失或跳到别的日期。
4. Given provider capability 为 `dailyOnly`，When 用户尝试点选日级点位，Then 不进入钻取并显示禁用或原因提示。
5. Given 历史日钻取已打开，When 页面渲染，Then UI 显示“静态快照 / 手动刷新”语义。
6. Given `timezoneIdentifier` 下该天是 DST 日，When 渲染 `1min / 15min / 30min / 60min` 钻取，Then 桶数允许按 `1380/1440/1500`、`92/96/100`、`46/48/50`、`23/24/25` 变化，不得因固定桶数假设而丢数据。
7. Given 当前选中日期是 Today，When 跨到下一个本地自然日或时区变化，Then 当前钻取结果失效并在下次刷新/重取时更新。
8. Given Gemini Phase 1 已实现，When 用户先查看日级 trend 再点开某个历史日，Then 系统复用同一份 session 解析缓存生成钻取数据，而不是再次全量读取原始 session 文件。
9. Given 单日钻取存在零桶，When 图表渲染，Then 所有零桶都必须被移除，包括中间零桶。
10. Given 当前选中日期是 Today，When 当前时刻之前只有部分分钟桶可见，Then 图表不得展示未来时间桶。
11. Given 当前 provider 为 Codex，When 打开 bucket picker，Then 应出现 `1min / 15min / 30min / 60min`，且不得出现 `5min / 10min`。
12. Given 当前 provider 为 Gemini / Claude / Antigravity，When 打开 bucket picker，Then 应出现 `1min / 5min / 10min / 15min / 30min / 60min`。

## 非目标

1. 本轮不实现 Codex `15min` cache 的完整落地代码。
2. 本轮不实现分钟级事实桶的独立持久化缓存。
3. 本轮不改变现有 summary 卡片语义。

## 2026-04-23 补充：请求数维度

### 背景

- 用户希望在 `Codex -> Usage` 的趋势工作区里，不只看 token，还能直接看按天 / 按分钟 bucket 聚合后的请求数。
- 新增的请求数必须和 token 走同一份 provider 事实源、同一份缓存链路、同一份刷新语义，不能在 UI 层额外扫文件再做一套派生统计。

### 交互要求

1. `Trend Workspace` 顶部新增 `token / 请求数` 切换。
2. 切换到 `请求数` 后：
   - summary cards 展示对应范围的请求总数；
   - `Daily Trend` 图表展示按日聚合请求数；
   - `Intraday Drilldown` 图表展示按当前 bucket 聚合请求数；
   - `Daily Breakdown / Intraday Breakdown` 表格支持展示请求数列。

## 2026-04-23 Header 视觉补充约束

### 背景

- 用户对 `Trend Workspace` 顶部控制区的最新反馈是：
  - 功能正确，但样式“太丑”，而且在图表前占用过高。

### 视觉与信息架构约束

1. 顶部控制区应默认呈现为单一工具栏，而不是多个设置卡片。
2. 顶部控制层的默认顺序应为：
   - `Daily / Intraday`
   - `Tokens / Requests`
   - `Bars / Line`
   - `Bucket`（仅 intraday）
   - `Refresh`（仅 intraday 且已选中日期）
3. `selected day / range / usage summary` 应作为第二层 `context rail`，视觉上弱于主工具栏。
4. `Bucket` 不再单独占据第三层或独立表单区域，避免把图表向下挤压。
5. `Daily Trend / Intraday Drilldown` 的大标题不应在 segmented 下方重复出现，避免“标题套标题”。
6. `legend / freshness / bucketSummary / presentationNote` 默认应下沉到图表脚注区，不与顶部控制层抢高度。
3. `Chart Style` 保持现有 `Bars / Line` 交互：
   - `token + Bars` 继续展示 `input / output / cache`;
   - `token + Line` 继续只展示 `total`;
   - `请求数 + Bars / Line` 都只展示 `requests total`，不虚构 input/output/cache 子维度。
4. `Intraday Drilldown` 切到折线图且展示请求数时，折线顶点同样需要显示请求量标签，和 token 模式保持一致。

### 数据与缓存口径

1. `ProviderTokenTrendPoint` 扩充 `requestCount`。
2. `ProviderIntradayUsagePoint` 扩充 `requestCount`。
3. `ProviderTokenTrendSnapshot` 扩充：
   - `todayRequests`
   - `last7DaysRequests`
   - `last30DaysRequests`
   - `allDaysRequests`
4. `Gemini / Claude`
   - 请求数定义为“被纳入 usage 聚合的有效 usage event 数量”；
   - daily 与 intraday 都基于同一份解析缓存 events 聚合；
   - cache 命中键与 token 保持一致。
5. `Codex`
   - 请求数定义为“被纳入 usage projection 的有效 token delta 条数”；
   - `session_usage_minutes` 与对应 projection / quarter-hour packed buckets 必须一起扩列 `request_count`；
   - daily、intraday、summary 都从同一份 minute projection 派生，禁止绕开 SQLite / projection 另起统计。

### BDD 验收补充

1. Given provider 已生成 token trend snapshot，When 用户切换到 `请求数`，Then summary cards、图表和表格都展示同一份 snapshot 中的请求数视图。
2. Given `Gemini / Claude` 已命中 session usage cache，When 用户查看 `请求数` 的 daily 与 intraday，Then 两者都复用同一份 events cache，不重复扫原始 session 文件。
3. Given `Codex` 已命中 projected minute cache，When 用户查看 `请求数` 的 daily 与 intraday，Then 两者都复用同一份 minute projection / SQLite 数据，不额外重扫 rollout。
4. Given 当前模式为 `请求数` 且 chart style 为 `line`，When 查看 `Daily Trend` 或 `Intraday Drilldown`，Then 折线顶点显示请求量标签。

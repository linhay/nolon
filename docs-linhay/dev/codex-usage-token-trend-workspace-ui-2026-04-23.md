# Codex Usage Token Trend Workspace UI 收敛（2026-04-23）

## 背景
- 用户连续多轮反馈 `Codex -> Usage` 里的 token trend 区域在视觉和交互上都不够稳定：
  - 上半区 `Daily Trend` / `Intraday Drilldown` 被拆成两个 block，切换日级与分钟级时视线来回跳。
  - 图区下方表格有独立滚动和固定高度，核对长表时会出现“里面滚一层，外面再滚一层”的割裂感。
  - 日级柱体偏细，30 天视图下可读性不足。
  - 用户需要一个更直观的曲线模式来快速看总量走势，但不想每次都重新切换。

## 目标
1. 把 `Daily Trend / Intraday Drilldown` 收敛为同一个工作区，减少视觉切换成本。
2. 图区 sticky，表格跟随整页滚动，避免嵌套滚动。
3. 图表样式支持 `Bars / Line` 两种模式，`Line` 只看 `total`，并记住选择。
4. 点击单日后自动切到 `Intraday Drilldown`，让钻取动作更直接。

## 设计

### 1. 单一 Trend Workspace
- `summary cards` 继续放在 token trend 顶部。
- summary 下方只保留一个 `Trend Workspace`。
- workspace 顶部使用 segmented control：
  - `Daily Trend`
  - `Intraday Drilldown`
- `Intraday Drilldown` 仍只在支持 intraday 的 provider 中展示。

### 2. sticky 图区
- `Trend Workspace` 内部使用单 section 的 sticky header：
  - header 承载当前 tab 的标题、辅助信息、控制项和图表。
  - section body 承载对应表格。
- sticky 目标是“图区固定、表格继续滚”，不是整个 token trend 卡片全量吸顶。
- 表格移除内部 `ScrollView + maxHeight`，让滚动统一回到页面级 `ScrollView`。

### 3. 图表样式模式
- `Bars`
  - `Daily Trend` / `Intraday Drilldown` 都展示 `input / output / cache` stacked bar。
  - 通过放大 slot width + bar width 解决柱体过细的问题。
- `Line`
  - `Daily Trend` / `Intraday Drilldown` 都只展示 `total` 折线与面积填充。
  - `Intraday Drilldown` 在线图顶点上直接显示该时间桶总量，避免切回表格才能核对。
  - `Daily Trend` 继续保留逐日点位选择能力，用于切 intraday。
- `chartStyle` 以 provider 维度写入本地偏好，默认 `bar`。
- `chartStyle` 在 `Daily Trend / Intraday Drilldown` 之间共享，切 tab 不重置样式。

### 4. 钻取切换
- 用户点击 `Daily Trend` 中的某一天：
  - 保持既有 `selectedDay` 更新逻辑。
  - 同时把 `activeContentTab` 切换成 `intraday`。
- 用户取消选中日或当前已无有效 `selectedDay`：
  - `activeContentTab` 回退到 `daily`。

### 5. provider-aware intraday buckets
- `Intraday Drilldown` 的 bucket picker 不再直接使用 `ProviderIntradayBucket.allCases`。
- 改为按 provider 精度暴露：
  - `Codex`: `1min / 15min / 30min / 60min`
  - `Gemini / Claude / Antigravity`: `1min / 5min / 10min / 15min / 30min / 60min`
- 原因：
  - `Codex` 现在直接来自 projected minute usage，可安全暴露 `1min` 做精细核对；
  - `Codex` 仍不暴露 `5min / 10min`，保持 bucket rail 紧凑，避免把同一语义拆得过细；
  - `Gemini / Claude / Antigravity` 来自事件时间戳，可安全聚合到 `1min / 5min / 10min` 等更细粒度。
- 聚合时长统一收敛到 `ProviderIntradayBucket.seconds`，避免 Provider 层和 UI 层各写一份 switch。

## 实现边界
- `libs/NolonUIFoundation`
  - 承载 `chartStyle / contentTab / supportsIntradayDrilldown` 这类通用展示模型。
- `libs/NolonUI`
  - 负责单一 workspace、sticky header、日级/分钟级共享图表样式、intraday 线图顶点用量标签、表格取消内滚动。
- `nolon` app 层
  - 负责 provider 级偏好持久化、tab 自动切换和 provider-aware bucket 映射。

## 验证
- `ProviderTokenTrendModelsTests`
- `ProviderTokenTrendIntradayChartSupportTests`
- `ProviderTokenTrendSectionViewTests`
- `ProviderTokenTrendViewModelParityTests`
- `ProviderUsageRegistryTests`

## 2026-04-23 晚间补充：Trend Header 密度再收敛

### 背景
- 用户继续反馈 `Trend Content / Chart Style` 与中间标题区“密密麻麻”，尤其是：
  - `Trend Content` segmented、`Chart Style` segmented、refresh、bucket、标题、副标题、legend、freshness 都在 sticky header 里抢同一块空间；
  - `Daily Trend / Intraday Drilldown` 已经在 segmented 中表达了一次，header 内又重复出现大标题，造成“标题套标题”；
  - `Chart Style` 控件旁边直接塞 legend，控制与解释信息没有分层。
- 本轮额外通过 `gemini CLI` 对真实代码结构做了一次咨询，结论与本地判断一致：header 应改成“控制优先、说明下沉”的结构，减少 sticky 非图表高度。

### 收敛结论
1. `Trend Content` 与 `Chart Style` 收敛为统一的顶部 control deck，不再散落在不同 header block。
2. `Daily Trend / Intraday Drilldown` 不再在 segmented 下面重复渲染大标题，改为更轻的 context strip。
3. legend 从 `Chart Style` 控件旁移出，下沉到图表脚注区。
4. `Intraday Drilldown` 的 `freshness / bucketSummary / presentationNote` 也从中间标题区下沉到图表脚注区。
5. refresh 保留在顶部控制层，不再跟标题文案混排。

### 实现约束
- 不改变 `Trend Workspace` 单区 sticky 结构，也不改 `Daily -> Intraday` 的钻取语义。
- 不改变 `chartStyle` 持久化与 provider-aware bucket 的行为，只重排信息层级。
- 紧凑布局优先通过 `ViewThatFits` 做横向/纵向自适应，避免窄宽度下再次回到挤压状态。

### 具体实现
- 顶部改成两个带轻量标签的 control card：
  - `Trend Content`
  - `Chart Style`
- `Intraday` 选中日时，refresh 以独立小按钮跟随 control deck 展示。
- `Daily` 中间区改为单行提示 tag，强调“点选单日后自动切到 Intraday Drilldown”。
- `Intraday` 中间区改为 context tags，仅保留：
  - `selected day + rangeDescription`
  - `usageSummaryText`
- 图表下方脚注区统一承载：
  - legend
  - `bucketSummary`
  - `freshnessText`
  - `presentationNote`

### 回归验证
- `xcodebuild test -scheme NolonUI -destination 'platform=macOS' -only-testing:NolonUITests/ProviderTokenTrendDailyChartSupportTests -only-testing:NolonUITests/ProviderTokenTrendIntradayChartSupportTests -only-testing:NolonUITests/ProviderTokenTrendSectionViewTests`
- 额外新增窄宽度渲染 smoke test，覆盖 intraday header 重排后的紧凑布局。

## 2026-04-23 吸顶修正补充

### 现象
- 用户继续反馈：上滚时图区没有真正吸顶。

### 根因
- 之前的 sticky 依赖 `ProviderTokenTrendSectionView` 内部 `trendWorkspace` 自己的 `LazyVStack(pinnedViews:)`。
- 但 `Codex -> Usage` 实际滚动发生在更外层的 `PaddedScrollContainer -> ScrollView`。
- 同时 `usageMetricsContent` 又额外包了一层 `LazyVStack`，导致 token trend workspace 的 section header 并不在真实滚动链路的直接 sticky 层上。

### 修正
1. `usageMetricsContent` 去掉仅承载 `tokenTrendSection` 的额外 `LazyVStack`。
2. `ProviderTokenTrendSectionView` 在 `snapshot` 可用时，改由根层 `LazyVStack(pinnedViews: [.sectionHeaders])` 承载 workspace section。
3. `Trend Workspace` 改成根层 section header + section body 结构，不再在内部再套一层 sticky `LazyVStack`。

### 影响
- `Usage` tab 下 token trend 图区吸顶会跟外层真实滚动容器对齐。
- 这次不改日级 / 分钟级数据语义，不改 chart style 持久化，只修正 sticky 挂载层级。

## 2026-04-23 运行态复核后的最终修正

### 新现象
- 按上述 sticky 挂载层级修正后，真实运行中的 `Codex -> Usage` 仍然没有达到用户预期：
  - AX 坐标显示 `Trend Workspace` header / control deck / chart 仍会一起滚成负值；
  - 截图也证明它只是“滚到顶附近暂时停留”，并没有在 viewport 顶部形成真正固定层。

### 复核结论
1. 外层 card 裁剪和 sticky 层级都只是放大问题，不是最终 root cause。
2. 真正的问题是：`Usage` 独立 tab 试图在“内容树内部”继续做 pseudo sticky，但真实滚动 viewport 仍是父级页面滚动。
3. 在这个独立 tab 场景里，继续微调 `offset / pinnedViews / preference key` 的收益已经很低，且运行态验证成本高。

### 最终策略
1. `combined` 页继续保留原来的“页面级滚动 + trend workspace 跟随页面”的流式布局。
2. `usage` 独立 tab 改为专用布局：
   - token trend card 不再外包整页 `PaddedScrollContainer`；
   - card 内部采用“固定 header + summary + workspace chart”；
   - `Daily Breakdown / Intraday Breakdown` 改为 workspace 内部独立 `ScrollView`。
3. 这个策略的目标不再是“让子视图看起来像 sticky”，而是直接让独立 tab 拥有真正固定的 chart viewport。

### 验证要求
1. `NolonUI` 定向测试必须覆盖新的 `standaloneUsageTab` 路径。
2. 真实 app 仍要做 AX / 截图复验，确认中段和深滚时图区不再随表格一起上卷。

## 2026-04-23 深夜补充：请求数维度并入同一工作区

### 背景
- 用户希望直接在现有 `Trend Workspace` 中查看“按 bucket 聚合后的请求数”，并支持和 token 之间快速切换。
- 这次不是单独再做一个 `Requests` 卡片区，而是在现有 token trend 数据模型里直接扩列，请求数与 token 共用一套 snapshot / cache / refresh 语义。

### 收敛结论
1. UI 顶部 control deck 新增一个紧凑的 `Usage Metric` control card，提供 `Token / Requests` segmented 切换。
2. `summary / daily / intraday / table` 全部跟随同一个 metric state 切换，避免“图是请求数、表还是 token”的语义撕裂。
3. `requestCount` 不拆成 `input / output / cache` 子维度：
   - token 模式维持现有 stacked bars 语义；
   - requests 模式的 `bar / line` 都只展示单一 total series。
4. 现有数据模型继续沿用 `ProviderTokenTrend*` 命名，避免为同一工作区再新建平行 `ProviderRequestTrend*` 模型。

### 实现边界
- `libs/Providers`
  - 在 `ProviderTokenTrendPoint / Snapshot / ProviderIntradayUsagePoint` 上直接扩列 `requestCount`。
  - `Gemini / Claude` 从 session usage event 聚合请求数。
  - `Codex` 从 projected minute usage 聚合请求数，并把 SQLite / packed quarter-hour buckets 一起扩列。
- `nolon`
  - `ProviderTokenTrendViewModel` 持有当前 metric mode，并把它映射到 `NolonUI` 展示层。
- `libs/NolonUIFoundation`
  - 承载 `metric mode` 与新的 request summary / request column 数据。
- `libs/NolonUI`
  - 负责 metric switch 后 summary cards、daily/intraday chart、legend、value label、table columns 的统一切换。

### 风险与兼容
1. `Gemini` 的 JSON cache 和 `Codex` 的 SQLite cache 都要考虑向后兼容：
   - JSON cache 可以通过 version bump 或 decode fallback 触发一次安全重建；
   - SQLite 通过 `ensureColumnIfNeeded` 增列，避免直接清库。
2. `requestCount` 的定义必须严格绑定到“参与 usage 聚合的有效 usage event / token delta”，不能用原始 message 数或 session 数近似代替。

### 验证补充
- `Providers`
  - `CodexTokenTrendServiceTests`
  - `CodexIntradayUsageServiceTests`
  - `GeminiTokenTrendServiceTests`
  - `GeminiIntradayUsageServiceTests`
  - `ClaudeTokenTrendServiceTests`
  - `ClaudeIntradayUsageServiceTests`
- `NolonUIFoundation`
  - `ProviderTokenTrendModelsTests`
- `NolonUI`
  - `ProviderTokenTrendSectionViewTests`
- `nolon`
  - `ProviderTokenTrendViewModelParityTests`

## 2026-04-23 深夜补充：Gemini 协作后的 Header 视觉重构

### 背景

- 用户继续给出运行态截图，明确指出顶部 `Trend Content / Usage Metric / Chart Style / Time Bucket` 区域“太丑、太像设置页、占高过多”。
- 本轮没有再凭主观微调，而是把真实代码片段与截图描述一并交给 `gemini CLI` 做协作式设计复核。

### Gemini 结论

1. 当前问题不是“控件不全”，而是“容器过载”：
   - `RoundedRectangle` + 分组标题 + segmented control 的组合把分析工具区做成了表单卡片。
2. 应从“设置页思维”切到“分析工具思维”：
   - 去卡片化；
   - 改成统一 toolbar rail；
   - 用 divider 而不是一组一张卡；

## 2026-04-24 顶部轨道对齐修正

### 现象
- 用户继续反馈：顶部 rail 虽然已经收紧，但控件之间仍像“左一坨、右一坨”地被推开，视觉基线不稳。
- 具体症状是：
  - `Bucket + Refresh` 仍像附着在右侧角落，而不是与前面的 `Daily / Tokens / Line` 在同一轨道上；
  - `Bucket` 菜单内部还保留了 `text + spacer + chevron` 的旧结构，导致控件本身宽度虚胖；
  - rail 最外层还是“主 controls + spacer + actions”的桌面工具栏布局，出现大块无意义留白。

### 修正策略
1. 顶部 rail 取消 `Spacer` 驱动的左右对推，改为真正的 leading-aligned 流式轨道。
2. 宽度足够时保持单行；空间不够时通过 `ViewThatFits` 回退为两行，但两行都必须左对齐。
3. `Bucket` 控件改成更紧凑的 inline menu：
   - 不再用内部 `Spacer` 拉开文本和箭头；
   - 改用 `title + chevron.down` 的紧凑 pill；
   - 仅在显式给定宽度时才锁宽，否则按内容自然收缩。

### 验证补充
- `NolonUITests.testProviderTokenTrendMenuControl_GivenCompactTitle_UsesTightIntrinsicWidth`
- `ProviderTokenTrendSectionViewTests.testProviderTokenTrendSectionView_GivenIntradayToolbarControls_WhenRenderingWideHeader_ThenKeepsCompactRailLayout`
   - 把当前钻取状态做成更轻的 context rail。
3. 视觉方向应更接近：
   - `Linear / Xcode / BI inspector` 的紧凑桌面工具栏；
   - 而不是移动端样式迁移到桌面的 stacked settings form。

### 最终收敛结构

1. 顶部第一层改成单一 `toolbar rail`：
   - `Daily / Intraday`
   - `Tokens / Requests`
   - `Bars / Line`
   - `Bucket`（仅 intraday 时出现）
   - `Refresh`（仅 intraday 且有选中日时出现）
2. 第二层只保留当前上下文：
   - `selected day + range`
   - `usage summary`
3. `Daily` 模式不再重复渲染大标题与说明块，只保留一条轻提示 tag。

### 本轮实现

1. 新增统一的 `ProviderTokenTrendToolbarRail`，作为顶部控制层的单一承载面。
2. `workspaceControlDeck` 从多张 `ControlCard` 重构为：
   - inline segmented controls；
   - `ProviderTokenTrendToolbarDivider` 分组；
   - icon-only bucket group；
   - 轻量 refresh icon button。
3. `Intraday` 的 bucket 从中间 context 区移回顶部工具栏，减少 header 纵向高度。
4. `Intraday` header 仅保留 context tags，不再堆叠 bucket 控件。
5. `Daily` footer 删除重复说明文案，只保留 legend，让图区前的视觉噪音降下来。

### 设计口径

- 这轮 header 的设计语义统一为：
  - “单一分析工具栏 + 轻量上下文轨道”
- 明确不再回到：
  - “多个控制卡片上下堆叠”
  - “标题、副标题、legend、bucket、refresh 同层混排”

## 2026-04-23 夜间补充：顶部轨道单行化收口

### 背景

- 用户继续指出：虽然 `Bucket` 和 `Refresh` 已经回到上方轨道，但现在的轨道仍然像“把几张小表单横着摆开”，对齐和间距都不够稳。
- 本轮再次把真实 SwiftUI 结构摘要交给 `gemini CLI` 复核，得到的关键信号是：
  - 根问题不是“哪个控件缺失”，而是仍保留了 `label above control` 的移动端表单节奏；
  - 要真正变成桌面分析工具栏，轨道必须回到单行基线，不要再让字段标题单独占一层高度。

### 收敛结论

1. 顶部轨道改成真正的单行 toolbar rail：
   - `View`
   - `Metric`
   - `Chart`
   - `Bucket + Refresh`
2. 字段标题从纵向 caption 改为 inline label，与控件共用同一条水平基线。
3. 左侧主控件之间使用细 divider 明确分组，不再依赖“每组自己一张小卡片”的假分组。
4. 右侧 `Bucket` 与 `Refresh` 收成同一个 action cluster，避免 refresh 图标继续像掉队按钮。

### 本轮实现

1. `ProviderTokenTrendToolbarField` 从 `VStack(label + control)` 改成 `HStack(label + control)`。
2. `workspaceControlDeck` 改成单行 `HStack(alignment: .center)`，并在：
   - `View`
   - `Metric`
   - `Chart`
   之间插入 `ProviderTokenTrendToolbarDivider`。
3. `intradayActionControls` 统一承载 `Bucket` 与 `Refresh`，并作为右侧单一动作区展示。
4. 控件宽度进一步压缩为：
   - `View = 118`
   - `Metric = 124`
   - `Chart = 90`
   - `Bucket = 96`
5. `Bucket` menu 去掉冗余图标，只保留值和展开箭头，减少横向噪音。

### 设计口径

- 这轮顶部工具栏的目标不再是“信息分层明显”，而是“单行节奏稳定、像桌面分析软件的控制轨道”。
- 如果后续继续打磨，应优先继续优化：
  - label 与 control 的水平节奏
  - divider 的分组感
  - 右侧 action cluster 的一体性
- 不再回退到纵向字段标题或多排 bucket/control 的方案。

## 2026-04-23 深夜补充：Codex 首轮全量扫描进度缺失根因与修复

### 背景

- 用户在清理本地缓存后重新进入 `Codex -> Usage`，反馈页面只有 spinner，没有“当前扫哪个文件 / 当前 x/x / 当前阶段”。
- 这轮复核确认：问题不在 `UnifiedProviderUsageSupportViews` 的 banner 组件，也不在 observer 注册，而是在首轮空缓存全量构建索引的链路没有发进度通知。

### 根因

- 空缓存场景会走 `CodexSessionStore.prepareProjectedUsageIndex(...)`，逐个 rollout 重建本地 minute usage index。
- 这条路径此前不会发送 `CodexSessionStore.performanceNotification`。
- `ProviderUsageEngine` 之前只消费 `refresh_projected_usage_day_keys`，因此 UI 拿不到首轮建索引的阶段信息与 rollout 级进度。

### 修复

1. `prepareProjectedUsageIndex(...)` 新增独立进度事件流，operation 固定为 `prepare_projected_usage_index`。
2. 事件阶段覆盖：
   - `scan_inventory`
   - `read_usage_index`
   - `reconcile_rollouts`
   - `analyze_rollout`
   - `rollout_completed`
   - `purge_stale_entries`
   - `finished`
3. rollout 级事件新增字段：
   - `current_rollout_path`
   - `processed_rollout_count`
   - `dirty_rollout_count`
   - `refreshed_live_rollout_count`
   - `refreshed_archived_rollout_count`
   - `current_database_name`
   - `current_database_path`
4. `ProviderUsageEngine` 同步接入 `prepare_projected_usage_index`，并把这些字段翻译成 banner 文案、`x / x` 标签和 `ProgressView` 比例。

### 运行态预期

- 首轮全量扫描时，顶部状态区会显示当前阶段，例如：
  - `正在扫描历史会话文件`
  - `正在准备建立索引`
  - `正在建立文件索引`
  - `正在建立派生用量索引`
- 扫描进行中会同时展示：
  - 当前 rollout 文件名
  - `processed / dirty` 进度
  - 已刷新 `live / archived` 数量

### 验证

- `swift test --package-path libs/Providers --filter CodexSessionStoreTests/loadProjectedUsageMinutesPublishesInitialBuildProgressMetrics` 通过。
- `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/ProviderUsageEngineManualRefreshTests/testBDD_GivenCodexInitialIndexBuildProgressNotification_WhenRefreshingTokenTrend_ThenPublishesReadableBuildStatus` 通过。
- `swift test --package-path libs/Providers --filter CodexSessionStoreTests` 通过。
- `xcodebuild -project nolon.xcodeproj -scheme nolon-app -configuration Debug -destination 'platform=macOS' -derivedDataPath /private/tmp/nolon-derived -skipPackageUpdates build` 通过，并已重新启动 debug app。

## 2026-04-23 深夜补充：超大 archived rollout 导致“建立文件索引”长时间卡住

### 现象

- 用户反馈全量扫描进度停在：
  - `467 / 2728`
  - `正在建立文件索引：正在解析 archived_sessions/rollout-2026-04-16T18-36-37-019d95dd-3e24-7340-a13d-2dc50749fa46.jsonl`
- 本地排查发现：
  - 该 rollout 文件大小约 `153 MB`
  - 共有 `15186` 行
  - 其中第 `13887` 行单行长度约 `50 MB`
  - 该超大行是 `response_item -> function_call_output`，并不包含 `token_count`

### 根因

- `CodexSessionEventParser.parseUsageEventLine(...)` 虽然理论上会跳过不影响 usage 的 `response_item`，但旧实现仍会在进入 fast path 前对整行做多次全文字符串搜索。
- 更关键的是，`CodexSessionUsageIndex.parseUsageFile(...)` 为了更新 timeline，又对每一行额外执行了一次 `CodexGeneratedFilesParser.parseRolloutLine(data:)`。
- 对这种 `50 MB` 的 `response_item` 行来说，这相当于再次做整段 JSON decode。
- 所以 UI 看起来像“卡在同一个文件”，本质上是在单个超大 rollout 行上被二次重解析拖住。

### 修复

1. 在 `CodexSessionEventParser` 新增 `fastTopLevelEnvelope(data:)`：
   - 直接按字节扫描顶层 JSON key；
   - 只提取顶层 `timestamp` 与 `type`；
   - 避免为了判定 `response_item / event_msg / session_meta / turn_context` 去整段 decode。
2. `parseUsageEventLine(...)` 现在先读取顶层 `type`：
   - `response_item` 直接跳过；
   - `event_msg` 仅在包含 `token_count` 时才进入完整解析。
3. `CodexSessionUsageIndex.parseUsageFile(...)` 的 timeline 更新不再调用 `parseRolloutLine(data:)`；
   - 改为直接复用 `fastTopLevelTimestamp(data:)`；
   - 因此超大 `response_item` 行不会再触发第二次整段 JSON decode。

### 验证

- `swift test --package-path libs/Providers --filter CodexSessionEventParserTests` 通过。
- `swift test --package-path libs/Providers --filter CodexSessionStoreTests/loadSessionUsageKeepsTimelineForHugeResponseItemLine` 通过。
- `swift test --package-path libs/Providers --filter CodexSessionStoreTests` 58 条通过。
- `xcodebuild -project nolon.xcodeproj -scheme nolon-app -configuration Debug -destination 'platform=macOS' -derivedDataPath /private/tmp/nolon-derived -skipPackageUpdates build` 通过，并已重新启动 debug app。

## 2026-04-24 凌晨补充：Usage 顶部 rail 第二轮对齐修正

### 现象

- 用户继续反馈 `Codex -> Usage` 顶部控制轨道即使已经缩窄控件，看起来仍像“左一坨 + 右一坨”。
- 具体表现为：
  - `Daily / Intraday`、`Tokens / Requests`、`Bars / Line` 靠左成组；
  - `Bucket` 与刷新按钮仍会被推到另一侧；
  - 轨道内部间距不稳定，视觉上不像同一条 rail。

### 根因

- 上一版虽然移除了 `Bucket` 自身内部的 `Spacer`，但 `workspaceControlDeck` 仍然沿用了 `HStack + ViewThatFits` 的编排方式。
- 更关键的是，`primaryToolbarRow` 仍被设置为 `maxWidth: .infinity`，它会在单行布局时吞掉剩余宽度。
- 结果就是：
  - `Bucket / Refresh` 即便逻辑上在同一个 `HStack`，视觉上仍被挤成“右侧动作区”；
  - `ViewThatFits` 也更容易过早退化到次优布局。

### 修复

1. `workspaceControlDeck` 改为基于 `FlowLayout` 的单轨道流式布局：
   - 所有控件严格按内容宽度参与排版；
   - 宽度不足时自动换行，但始终保持左对齐；
   - 不再人为拆成 `primary controls` 与 `right actions` 两组。
2. 顶部 rail 控件顺序统一为：
   - `Daily / Intraday`
   - `Tokens / Requests`
   - `Bars / Line`
   - `Bucket`
   - `Refresh`
3. `ProviderTokenTrendToggleControl` 补 `fixedSize(horizontal: true, vertical: false)`，确保 segmented-like 自定义控件按内容收缩，不再在布局提议下意外膨胀。
4. `ProviderTokenTrendToolbarRail` 内边距进一步收紧，减少外层空白，让轨道更像一个紧凑的 instrument rail。

### 验证

- `swift test --package-path libs/NolonUI --filter ProviderTokenTrendSectionViewTests` 通过。
- `swift test --package-path libs/NolonUI --filter NolonUITests.testProviderTokenTrendMenuControl_GivenCompactTitle_UsesTightIntrinsicWidth` 通过。
- `swift test --package-path libs/NolonUI --filter NolonUITests.testProviderTokenTrendToggleControl_GivenTwoShortOptions_UsesIntrinsicWidth` 通过。
- `git diff --check` 通过。
- `swift test --package-path libs/NolonUI --filter NolonUITests` 仍存在一个与本次改动无关的既有失败：
  - `testDefaultTools_ContainsAccountsAndPluginManagement`
  - 失败原因是默认工具列表当前包含额外的 `nolon` 项，断言期望未同步更新。

## 2026-04-24 凌晨补充：顶部 rail 右侧操作菜单与分钟桶扩容

### 需求收口

- 顶部 rail 继续微调，新增三个明确约束：
  - toggle 文本两侧要保留稳定内边距；
  - Intraday 分钟桶补齐到 `1 / 5 / 10 / 15 / 30 / 60`；
  - 分钟选择与刷新不再拆成两个控件，而是收进右侧单个菜单。

### 根因

- 上一版虽然已经解决了“左一坨右一坨”的大问题，但仍有两个细节不符合产品预期：
  - 自定义 segmented control 里的文字仍偏贴边，缺少足够的横向 breathing room；
  - Codex provider 的 `supportedIntradayBuckets` 仍旧只暴露 `1 / 15 / 30 / 60`，导致 UI 就算改成菜单，也拿不到 `5m / 10m`。

### 修复

1. `ProviderTokenTrendToggleControl` 的单个 segment 改为内容自适应宽度：
   - 去掉原先依赖容器拉伸的 `maxWidth`；
   - 改成显式 `horizontal padding`，让文字左右都有稳定留白。
2. 顶部 rail 重新分成：
   - 左侧 `Daily / Intraday`、`Tokens / Requests`、`Bars / Line`
   - 右侧一个统一的 `intraday options menu`
3. `intraday options menu` 里收口为两类动作：
   - `Bucket` section：列出所有分钟桶并显示当前选中态；
   - `Refresh` action：在同一个菜单里直接触发分钟级刷新。
4. `ProviderUsageRegistry.supportedIntradayBuckets(for: .codex)` 补齐为：
   - `.minute1`
   - `.minute5`
   - `.minute10`
   - `.minute15`
   - `.minute30`
   - `.hour1`

### 验证

- `swift test --package-path libs/NolonUI --filter ProviderTokenTrendSectionViewTests` 通过。
- `swift test --package-path libs/NolonUI --filter NolonUITests.testProviderTokenTrendMenuControl_GivenCompactTitle_UsesTightIntrinsicWidth` 通过。
- `swift test --package-path libs/NolonUI --filter NolonUITests.testProviderTokenTrendToggleControl_GivenTwoShortOptions_UsesIntrinsicWidth` 通过。
- `swift test --package-path libs/Providers --filter ProviderUsageRegistryTests` 通过。
- `git diff --check` 通过。

## 2026-04-24 凌晨补充：菜单与选项卡固定为单轨道

### 需求收口

- 用户进一步明确：顶部 `menu` 和几个选项卡必须在同一条 rail 上，不接受再退回成上下两排。

### 修复

1. `workspaceControlDeck` 取消 `ViewThatFits` 的双排回退。
2. 顶部控件改为整条 rail 自身水平滚动：
   - `Daily / Intraday`
   - `Tokens / Requests`
   - `Bars / Line`
   - 右侧 intraday options menu
3. 这样在窄宽度下仍然保持单轨道语义，只是整条轨道可横向滚动，不再把菜单挤到第二排。

### 额外修正

- 中途尝试过“左侧局部滚动 + 右侧菜单钉住”的实现，但在 `NSHostingView.fittingSize` 测试路径下触发了 SwiftUI `view origin is invalid (nan)`。
- 最终改为“整条 rail 水平滚动”的实现后，布局与测试均恢复稳定。

### 验证

- `swift test --package-path libs/NolonUI --filter ProviderTokenTrendSectionViewTests` 通过。
- `swift test --package-path libs/NolonUI --filter NolonUITests.testProviderTokenTrendMenuControl_GivenCompactTitle_UsesTightIntrinsicWidth` 通过。
- `git diff --check` 通过。

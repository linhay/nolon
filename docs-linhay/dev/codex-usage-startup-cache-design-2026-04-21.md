# Codex Usage 首屏缓存加载设计（2026-04-21）

## 2026-04-21 回归收敛
- 当天下午验证中出现真实回归：
  - `Usage` 图表统计天数可能只剩最近 1 到 2 天
  - 与 `Codex Sessions` 等共享用量语义的页面放在一起看时，会给人“口径变了”的感知
- 根因不是 live 扫描口径变了，而是“首屏直接信任已有 `cost-usage` cache”这件事本身不安全：
  - 现有 `CostUsageCacheIO` 只保存按天聚合结果，不保存“这份 cache 是否覆盖全历史”的完整性元数据
  - 如果 cache 曾经只在较窄窗口下构建过，首屏就会先把一个被截断的结果发布到 UI
- 因此本设计已在当天收敛为：
  - 保留 `Codex account cards` 的缓存首屏
  - 撤回 `token trend` 的 cache hydrate，恢复到 live snapshot 为准
  - 后续若要重启该方案，必须先补“cache coverage / 完整性”元数据，再重新进入实现

## 背景
- 当前 `Codex Usage` 页首次进入时，会直接进入 `refreshTokenTrend()`。
- `CodexTokenTrendService.fetchGlobalSnapshot(...)` 会调用 `CostUsageFetcher.loadTokenSnapshot(...)`，而底层 `CostUsageScanner` 仍可能因为刷新窗口到期而触发真实扫描。
- 结果是：
  - 即使磁盘上已经有 `cost-usage` cache，首屏仍可能等待扫描完成。
  - 用户体感是“Usage 页每次冷开都要重新扫一遍”。

## 原始目标
1. 首次进入 `Codex Usage` 时，若磁盘上已有 `cost-usage` cache，先立即展示缓存生成的 token trend。
2. 缓存展示后，后台继续发起一次真实 refresh，把最新结果回填到 UI。
3. 若没有 cache 或 cache 无法解码，则回退到现有实时加载链路，不影响正确性。

## 非目标
1. 本轮不改变 `Codex Usage` 的全局口径语义。
2. 本轮不引入新的 SQLite/JSON 缓存文件，优先复用已有 `CostUsageCacheIO`。
3. 本轮不修改 intraday drilldown 的产品规格；首目标只解决首屏 token trend。

## 原始方案

### 方案 1：Provider 层新增“只读 cache 快照”能力
- 在 `CostUsageFetcher` 新增只读取现有 cache 的快照加载能力。
- 该能力：
  - 只读取 `CostUsageCacheIO` 现有文件
  - 不触发 `CostUsageScanner.scanFiles(...)`
  - 直接把 cache 中的 day 聚合恢复为 `CostUsageTokenSnapshot`

### 方案 2：CodexTokenTrendService 支持 cached snapshot
- 在 `CodexTokenTrendService` 新增 `fetchCachedGlobalSnapshot(...)`。
- 语义与正式 `fetchGlobalSnapshot(...)` 对齐：
  - 仍先基于完整数据计算 summary
  - 再按当前 range 裁剪 `points`
  - source label 保持 `global local usage`

### 方案 3：Usage 引擎首屏先 hydrate cache，再后台 refresh
- `ProviderUsageEngine.loadUsageIfNeeded()` 在 `usageProvider == .codex` 时：
  1. 先尝试读取 cached token trend
  2. 若命中，则立即写入 `tokenTrendSnapshot`
  3. 同时启动后台 `loadUsage()`
- 若未命中缓存，则走原来的 `await loadUsage()` 链路。

## 原始 BDD

### 场景 1：首屏优先显示 cached trend
- Given `cost-usage` cache 已存在且可解码
- When 用户首次进入 `Codex Usage`
- Then 页面先显示 cache 生成的 token trend
- And 不必等待真实扫描完成才出现图表数据

### 场景 2：后台 refresh 覆盖 cache
- Given 页面已先展示 cached trend
- When 后台真实 refresh 完成
- Then UI 被最新 snapshot 覆盖

### 场景 3：无 cache 自动回退
- Given 不存在可用 cache
- When 用户首次进入 `Codex Usage`
- Then 仍走现有实时加载链路
- And 正确性不受影响

## 当天下午的临时收敛结论（已被晚间安全重启方案取代）
1. `Codex Usage` 的 token trend 首屏继续走 live snapshot，不再提前发布 cached trend。
2. 账号卡片缓存首屏策略继续保留，因为它的缓存语义是单账号结果快照，不存在“全历史被截断仍被当成正确 summary”这个问题。
3. 若后续还要优化 usage 图表首屏，必须先补：
   - cache coverage 元数据
   - “窄覆盖 cache 不可发布”的 Provider + ViewModel 回归测试

## 2026-04-21 晚间补充：安全重启方案

### 新背景
- 当 `Codex Usage` 已切到 session-minute 真源后，首屏慢点已经不再是旧 `cost-usage` cache 是否命中，而是：
  - `CodexTokenTrendService.fetchGlobalSnapshot(...)`
  - `CodexSessionStore.loadProjectedUsageMinutes(...)`
  - 首次进入时要扫描 rollout 清单并逐个校准 `usage-index-v1.sqlite`
- 这条 live 链路正确，但对首屏来说过重，用户会体感到“Usage 首屏出来特别慢”。

### 新决策
1. 不再尝试复用 `CostUsageCacheIO` 的 day cache。
2. 改为持久化“上一次成功生成的 full `ProviderTokenTrendSnapshot`”作为首屏缓存。
3. 这份缓存只能来自一次完整成功的 session-backed live snapshot，不能来自窄窗口 day cache，也不能来自半成品扫描结果。
4. 首屏只做：
   - 读这份稳定快照并立刻 hydrate UI
   - 后台继续跑 live refresh
   - live 成功后覆盖缓存

### 为什么这次是安全的
- 旧方案不安全，是因为 `cost-usage` cache 可能天然只覆盖最近几天。
- 新方案缓存的是“已经过完整 live 聚合后的最终快照”，它的语义与当前 `global local usage` 一致，只会旧，不会结构性截断。
- 即使缓存过期，也只是缺少最新会话，不会再出现“只剩两天”的错误口径。

### 实施边界
1. Provider 层新增专用 `CodexTokenTrendSnapshotCache`，只负责 full snapshot 的读写。
2. `CodexTokenTrendService`：
   - live fetch 后写缓存
   - 提供 `fetchCachedGlobalSnapshot(...)`
3. `ProviderUsageEngine.loadUsageIfNeeded()`：
   - 仅 `codex` 首屏先尝试 hydrate cached trend
   - 命中后继续后台 `loadUsage()`
   - 未命中则维持现状

### 新 BDD

#### 场景 1：首屏先显示上次成功的 full snapshot
- Given 上一次 `Codex Usage` live refresh 已成功
- And 已写入 session-backed full token trend cache
- When 用户重新打开 App 并首次进入 `Codex Usage`
- Then 页面先显示这份 cached trend
- And 不需要等待本轮 rollout 扫描完成

#### 场景 2：后台 refresh 覆盖缓存
- Given 页面已先展示 cached trend
- When 本轮 live refresh 完成
- Then UI 更新为最新 snapshot
- And cache 被新的 full snapshot 覆盖

#### 场景 3：缓存缺失时自动回退
- Given 当前不存在可用 token trend cache
- When 用户首次进入 `Codex Usage`
- Then 页面继续走现有 live session-minute 链路
- And 正确性不受影响

## 2026-04-21 夜间补充：token trend 与 intraday refresh 对齐

### 新现场问题
- 运行中的 `Codex Usage` 页面出现了新的体感不一致：
  - 顶部 `Today` / `Daily Breakdown` 点击主刷新后会先更新到较新的时间点
  - 但下方 `Intraday Drilldown` 仍保留上一次的静态快照时间与列表
- 用户会直接看到“当天列表项加总不等于 Today 总量”，即便两边最终都来自同一条 session-minute 真源链路。

### 收敛结论
1. `Usage` 顶部主刷新不应只更新 daily trend。
2. 只要当前已经选中了某一天的 intraday drilldown，主刷新完成后就必须同步刷新该日 intraday snapshot。
3. intraday 区域自己的手动刷新也不能只刷新下半区；否则用户点完下方刷新后，页面仍会长期停留在“上面旧、下面新”的混合状态。
4. 这样做的目标不是提前预取所有 intraday，而是保证“同一屏里同时展示的 summary 与列表”来自同一轮 refresh。

### BDD 补充
- Given 用户已在 `Usage` 页选中某一天并展开 intraday drilldown
- When 用户点击顶部 token trend refresh
- Then `Today` / `Daily Breakdown` 更新后，当前选中日的 intraday 也会在同一轮 refresh 中被重新拉取
- And 页面不会再出现“上面是新时间、下面还是旧静态快照”的混合状态
- Given 用户已在 `Usage` 页选中某一天并点击 intraday 自己的刷新按钮
- When 页面执行手动刷新
- Then 页面也应走同一轮 token trend refresh，并在其成功后联动刷新当前 intraday
- And 同页两张表不会因为“只刷下半区”而再次出现口径分叉

## 2026-04-21 深夜补充：手动刷新切到缓存增量回填

### 新现场问题
- 上述“上下同轮 refresh 对齐”修完后，用户继续反馈 `Codex Usage` 的手动刷新仍然偏慢。
- 复盘后确认当前慢点不在 `Intraday Drilldown` 本身，而在 `refreshTokenTrend()` 仍会走 `CodexTokenTrendService.fetchGlobalSnapshot(...)`：
  - 它会触发 `CodexSessionStore.loadProjectedUsageMinutes(...)`
  - 该链路会逐个 rollout 做指纹校验，并把全历史 minute rows 重新投影成日级 snapshot
- 对“时间只会向后追加”的常规刷新场景来说，这条链路过重。

### 新决策
1. 保留首屏 `full snapshot cache` hydrate 方案。
2. Codex 手动刷新优先改走“基于 full snapshot cache 的增量回填”：
   - 若存在 cached full snapshot，则只重算最近两天（昨天 + 今天）的 minute projection
   - 将这两天的新日级 point 回填到 cached full snapshot
   - 再重新计算 `Today / 7D / 30D / ALL`
3. 只有在 full snapshot cache 缺失时，才回退到原来的 full live snapshot 构建链路。

### 为什么这样收敛
1. 用户的主要核对对象是当前仍在变化的近端日期，而不是要求每次手动刷新都重新读取全历史 minute rows。
2. 逐 rollout 做增量 ingest 仍会发生，但内存侧不再把所有历史 minute rows 重新拉出再聚合。
3. 对同一天仍在追加、以及跨午夜附近可能影响昨天/今天边界的场景，回填最近两天已经足够覆盖主要真实变化面。

### BDD 补充
- Given 本地已经有可用的 Codex full token trend cache
- When 用户点击 `Codex Usage` 的手动刷新
- Then Provider 优先只重算最近两天的 minute projection 并回填到 cached full snapshot
- And 不再默认把全历史 minute rows 全部重新投影一遍
- Given 当前不存在 full token trend cache
- When 用户点击手动刷新
- Then 仍回退到完整 live snapshot 链路
- And 正确性不受影响

# 争论背景

当前 `Usage` 页已经有“历史 Token 消耗”模块，但它只有日维度趋势：

- Codex 侧由 `CodexTokenTrendService` 基于 `CostUsageFetcher.loadTokenSnapshot(...)` 提供 `daily` 点位，模型只有 `date = yyyy-MM-dd`，没有小时粒度。
- Gemini 侧由 `GeminiTokenTrendService` 扫描 `~/.gemini/tmp/**/chats/session-*.json`，原始消息里有完整 `timestamp`，但当前同样在 service 内被聚合到了“按天”。
- UI 侧 `ProviderTokenTrendSection` 和 `ProviderTokenTrendSnapshot` 现在默认假设点位就是日级数据。

本轮争论的目标不是直接改代码，而是先回答 3 个问题：

1. “日内使用曲线”应该作为现有 token trend 的扩展，还是单独的新模块。
2. Codex / Gemini 是否应该共用一套实现路径。
3. 第一阶段最稳妥的落地范围是什么。

# 参与者观点

## 第 1 轮

### GreyBox：不要直接把“小时点位”硬塞进现有 `ProviderTokenTrendSnapshot`

- 当前 `ProviderTokenTrendPoint` 的主键语义只有 `date`，展示层默认把它当作自然日标签使用：
  - `libs/Providers/Sources/ProviderUsage/ProviderTokenTrendModels.swift`
  - `nolon/Skills/Domain/Providers/Usage/Views/Common/ProviderTokenTrendSection.swift`
- Codex / Gemini 两边的 summary 也是“先算全量 summary，再裁剪 points”，这个模型很适合 `7D / 30D / ALL`，但不适合“今天 00:00-现在”的小时曲线。
- 如果直接把 `date` 改成 `2026-04-14T13` 这种字符串，现有图表、排序、summary 文案都会变得语义混乱。

结论：

- 日内曲线应该是现有 token trend 的“同域扩展”，但不是把现有日级点位强行改成多用途点位。
- 更合理的方式是新增一层明确的粒度模型，例如：
  - `ProviderUsageCurveGranularity`
  - `ProviderUsageCurvePoint`
  - `ProviderIntradayUsageSnapshot`

### SignalForge：产品上它不该是独立大卡片，而应是“历史 Token 消耗”里的粒度切换

- 现有 `Usage` 页已经把 token trend 当作第二段内容放在账号卡之后，用户心智很明确：这是“消耗趋势区”，不是另一套报表系统。
- 如果再加一个独立“日内曲线”卡片，信息层级会变成：
  - 账号用量
  - 日趋势
  - 日内趋势
- 这会让页面从“一个趋势模块有多个观察尺度”退化成“两个长得很像的趋势模块并排”。

结论：

- UI 上应优先做成同一 section 内的粒度切换：
  - `日`
  - `日内`
- 或更具体：
  - `7D / 30D / ALL`
  - `Today`
- 不建议先做独立 section。

## 第 2 轮

### CacheTrace：Gemini 很适合先做，Codex 不能假设也一样简单

- Gemini 原始来源里本来就有消息级 `timestamp`：
  - `libs/Providers/Sources/ProviderUsage/GeminiTokenTrendService.swift:77-92`
- 当前 service 只是把这些消息按 `YYYY-MM-DD` 聚合到 `daily`。
- 也就是说，Gemini 做“每小时 token 曲线”本质上只是把：
  - `按天 bucket`
  - 改成
  - `按小时 bucket`

结论：

- Gemini 的日内曲线属于“已有原始时间戳，聚合口径升级”。
- 这是低风险、低耦合的路径。

### RefactorRaven：Codex 当前只有日级聚合产物，不能把 Gemini 的实现路径照抄过去

- Codex 趋势现在来自：
  - `libs/Providers/Sources/ProviderUsage/CodexTokenTrendService.swift:26-74`
  - 它调用 `CostUsageFetcher.loadTokenSnapshot(...)`
- 但这里需要先纠正一个前提：
  - Codex 原始 session / rollout 事件本身是有 `timestamp` 的。
  - `CodexSessionEventParser` 在 token delta 上明确保留了 `timestamp`：
    - `libs/Providers/Sources/Providers/Codex/CodexSessionEventParser.swift:16`
    - `libs/Providers/Sources/Providers/Codex/CodexSessionEventParser.swift:154-191`
  - `CostUsageScanner` 在扫描时也确实读取了 timestamp，并转换为本地日期键：
    - `libs/Providers/Sources/Providers/Codex/CostUsage/Vendored/CostUsageScanner.swift:187-194`
    - `libs/Providers/Sources/Providers/Codex/CostUsage/Vendored/CostUsageScanner+Timestamp.swift:29-110`
- `CostUsageFetcher` 返回的是 `CostUsageTokenSnapshot.daily`：
  - `libs/Providers/Sources/Providers/Codex/CostUsage/CostUsageFetcher.swift:57-89`
  - `libs/Providers/Sources/Providers/Shared/CostUsageModels.swift`
- 更关键的是 vendored scanner 的 cache 结构本身也是 `dayKey -> model -> packed usage`：
  - `libs/Providers/Sources/Providers/Codex/CostUsage/Vendored/CostUsageCache.swift:67-70`
- 这说明当前 Codex 的问题不是“原始数据没有时间戳”，而是“中间聚合层已经把 timestamp 压平成了 dayKey”。
- 于是当前 Codex 的公开聚合口径，从 scanner cache 到 UI snapshot，都是日级，不是小时级。

结论：

- Codex 要做日内曲线，不是简单“改 service 一行分组逻辑”，但也不是从零补数据源。
- 更准确地说，是把现有 scanner/cache/fetcher 从“只产生日级聚合”扩成“可同时产生日级与小时级聚合”。
- 它至少需要下面两条路径二选一：
  1. 扩展 `CostUsageScanner`，让 cache 同时维护 `hourKey`
  2. 新增独立 intraday scanner，直接扫 rollout/session 原始事件

## 第 3 轮

### VectorPulse：Codex 复用现有 scanner 更稳，不要在 UI 侧临时去扫 rollout 原始文件

- 现有 Codex token trend 已经有一条稳定链路：
  - scanner
  - cache
  - fetcher
  - `CodexTokenTrendService`
  - UI
- 如果为了日内曲线再在 App 层单独去扫 `sessions/` 或 rollout JSONL，会出现两套来源：
  - 日趋势走 scanner cache
  - 日内走临时扫描
- 这样会导致同一时间段里：
  - “Today summary”
  - 和
  - “Today intraday total”
  - 可能对不上。

结论：

- Codex 应坚持“同一来源派生多个粒度”。
- 即便实现成本高一些，也优先扩 scanner/fetcher，而不是在 App 层补一个临时读文件方案。

## 第 3.5 轮

### TimestampSmith：Codex 这条线现在不是“能不能做”，而是“在哪一层扩最干净”

- 既然原始 rollout 已经有 timestamp，说明 Codex intraday 不需要额外发明新来源。
- 当前真正的设计问题只剩两件事：
  1. cache 层是否从 `dayKey` 升级为 `dayKey + hourKey`
  2. fetcher 层是否继续只暴露 `daily`，还是补一个并行的 `intraday`
- 这比“没有原始时间戳”乐观很多，也说明 Codex Phase 2 更像增量扩展，不一定是推倒重来。

结论：

- Codex 当前的瓶颈是聚合粒度被压平，不是原始数据不可得。
- 这会影响优先级判断：
  - 不必把 Codex intraday 归类成高不确定性探索
  - 应归类成 scanner/fetcher 设计扩展

### NightShift：但第一阶段不能被 Codex 卡死，应该允许 provider 分阶段开通

- 如果要求 Codex/Gemini 同时上线，最终最可能的结果是：
  - 讨论很完整
  - 一段时间内没有任何用户可见收益
- 目前 Gemini 的原始数据已经满足条件，而 Codex 还要改 scanner cache 结构。
- 现有 token trend section 已经支持 provider 分支：
  - `nolon/Skills/Domain/Providers/Usage/Engine/ProviderUsageEngine.swift:752-780`
  - Codex 与 Gemini 本来就是两条 service 路径

结论：

- 产品能力可以统一命名，但 provider 支持度允许分阶段：
  - Phase 1: Gemini intraday
  - Phase 2: Codex intraday

## 第 4 轮

### FluxGarden：交互上不要默认展示 24 根小时柱，应该先定义“观察窗口”和“桶宽度”

- “日内使用曲线”至少有两层变量：
  - 观察窗口：今天、过去 6 小时、过去 24 小时
  - 桶宽度：15 分钟、30 分钟、1 小时
- 如果这些概念不先收敛，工程实现会很容易被写死成“24 个小时桶”，后续再改会牵动数据模型和 UI。

建议：

- 第一版统一只做：
  - 观察窗口：`Today`
  - 桶宽度：`1h`
- 原因：
  - 和当前“按天”趋势的关系最清楚
  - summary 也最容易解释
  - 不需要引入第二套复杂控件

### MirrorNode：summary 不要跟着“日内曲线”重新发明一套指标

- 现有 trend 已经有稳定 summary：
  - Today
  - 7 Days
  - 30 Days
  - ALL
- 日内曲线如果再补：
  - 当前小时
  - 峰值小时
  - 平均小时
- 会把 section 变成两套 summary 叠加，认知负担太高。

结论：

- 第一版日内曲线只新增图表和 hover/selection 详情。
- 不新增第二排 summary 卡片。
- 顶部 summary 仍沿用现有日级口径。

## 第 5 轮

### AtlasByte：时区必须明确采用“本地时区 bucket”，不能混 UTC

- 现有日级聚合已经在使用本地时区概念：
  - `CodexTokenTrendService.dayKey(from:)`
  - `GeminiTokenTrendService.dayKey(from:)`
- 如果日内曲线改成 UTC 分桶，而 summary / Today 仍按本地时区，就会出现用户看到“今天总量”和小时曲线最后一小时对不上的问题。

结论：

- 第一版统一按本地时区分桶。
- 文案和调试信息里要显式标注 `Local Time`。

### RuntimeSmith：需要单独定义“provider 是否支持 intraday”的能力位，而不是靠空数组隐式判断

- 现在 token trend section 的显示是按 provider family 和 snapshot 是否为空来处理。
- 但“没有数据”和“根本不支持日内曲线”是两种不同语义：
  - 没数据：应该显示空态
  - 不支持：应该隐藏切换，避免用户误以为坏了

结论：

- 需要在 view model 或 provider metadata 上新增显式能力位，例如：
  - `supportsIntradayTokenCurve`
- 第一阶段 Gemini = true，Codex = false。
- Codex 做完 scanner 扩展后再打开。

## 第 6 轮

### 夜影信使：从产品与交互复核，`历史 / Today` 应被定义为“模式切换”，不是 range 扩展

- 当前页面本就只有一套趋势模块：
  - `nolon/Skills/Domain/Providers/Usage/Views/Common/ProviderTokenTrendSection.swift`
- 因此把日内曲线挂在现有 section 内，比新开独立 section 更符合当前信息层级。
- 复核重点不在“还能不能放进去”，而在“避免 Today 被误认成新的 range 选项”。
- 如果切到 `Today` 后仍保留 `7D / 30D / ALL`，用户会更容易把它理解成一个特殊 range，而不是另一种观察尺度。

结论：

- `Today` 应明确是模式，不是 range。
- UI 上应收敛为：
  - 模式：`历史 / Today`
  - 仅 `历史` 模式下显示 `7D / 30D / ALL`

### PulseArchitect：从性能与演进复核，intraday 不应被做成准实时监控

- `today` 模式当前目标是“补足日内观察能力”，不是实时 dashboard。
- 如果第一版就给 intraday 单独加 watcher、高频 polling、实时滚动更新，会明显抬高复杂度，且 Gemini 侧文件扫描开销会立刻暴露。
- 更合理的边界是：
  - 首次切入 `Today` 时加载
  - 用户手动 refresh 时刷新
  - 午夜 rollover 或视图重新激活时按本地日期重置并自动触发一次 refresh

结论：

- 第一版不做 intraday 高频刷新。
- 今日曲线遵循“首次切入 + 手动刷新 + 午夜重置”的节奏。

## 第 7 轮

### Cypher：从 Codex 链路复核，推荐扩现有 scanner/cache/fetcher，不建议另起临时 intraday scanner

- 原始 rollout token 事件已有 timestamp：
  - `libs/Providers/Sources/Providers/Codex/CodexSessionEventParser.swift`
- 现有 `CostUsageScanner` 也已经在使用 timestamp，只是最终折叠成了 `dayKey`：
  - `libs/Providers/Sources/Providers/Codex/CostUsage/Vendored/CostUsageScanner.swift`
  - `libs/Providers/Sources/Providers/Codex/CostUsage/Vendored/CostUsageScanner+Timestamp.swift`
- 如果为了 intraday 再另起一套扫描链路，会形成：
  - 日级 summary 走 scanner cache
  - 今日曲线走另一套临时聚合
- 这样极易出现 day/hour 口径漂移。

结论：

- Codex 应沿现有 scanner/cache/fetcher 扩小时粒度。
- 不建议 App 层或新的临时 service 单独再扫 rollout。

### Cypher：cache v2 的关键不是“能不能存小时桶”，而是“如何保证兼容与口径一致”

- 当前 `CostUsageCache` 只有：
  - `days: [String: [String: [Int]]]`
- 推荐扩成：
  - `days`
  - `hours`
- 但 cache v2 必须同时解决两件事：
  1. v1 旧 cache 没有 `hours` 字段时要能安全回退
  2. day/hour 必须共用同一套 timezone 与 timestamp parser
- 否则会出现：
  - 旧 cache 无法读
  - 或 `sum(hour) != day(total)`

结论：

- Codex Phase 2 的最小设计约束是：
  - cache v2 兼容 v1
  - hour/day 共享同一套 timestamp 解析逻辑
  - 测试中显式校验 `sum(hours in today) == day(today)`

## 第 8 轮

### Gemini CLI：主方案成立，但还需要补 3 个容易漏掉的工程边界

- 从外部 CLI 评审的角度，`同一趋势 section + 模式切换` 的方向是成立的。
- 它也支持以下核心判断：
  - `Today` 必须是 mode，而不是和 `7D / 30D / ALL` 并列的 range
  - Gemini 先做、Codex 后做是合理的分阶段策略
  - Codex 应扩现有 scanner/cache/fetcher，而不是另起临时 intraday scanner
- 但额外指出了 3 个我们文档里之前写得还不够“硬”的边界：
  1. **缓存体积控制**
     - Codex cache 引入 `hours` 后，不能无限保留所有历史小时桶
     - 推荐只保留一个有限窗口，例如最近 7 天的小时级 cache
  2. **跨天与时区变更**
     - `Today` 模式在午夜切换时会自然失效
     - 若设备时区发生变化，已有 intraday snapshot 可能和当前本地时间口径不一致
  3. **零桶补齐位置**
     - 补 0 不应留给 UI 组件
     - 必须在 service/fetcher 层直接输出连续桶数组

结论：

- 现有方案可继续推进，但推荐再追加 3 条实施约束：
  - Codex `hours` cache 必须有保留窗口与清理策略
  - intraday snapshot 必须携带 `timezoneIdentifier`
  - service/fetcher 必须输出从 `00:00` 到当前小时的连续桶，UI 不负责补洞

# 结论与行动项

## 当前结论

1. “日内使用曲线”应作为现有“历史 Token 消耗”模块里的新粒度，而不是新 section。
2. 数据模型不要污染现有 `ProviderTokenTrendSnapshot`，应新增独立 intraday snapshot/point/granularity。
3. Gemini 适合先落地，因为已有消息级时间戳；Codex 原始 rollout 也已有 timestamp，但当前 scanner/cache/fetcher 只暴露日级聚合，所以必须先扩这条聚合链路。
4. 第一版只做：
   - 观察窗口：`Today`
   - 桶宽度：`1h`
   - 时区：本地时区
   - UI：在现有 token trend section 增加 `Today` 粒度切换
5. 第一版不新增第二排 intraday summary 卡片，只复用现有日级 summary。
6. 三位 subagent 复核后，没有推翻主方案，但一致要求收紧 4 个边界：
   - `Today` 必须是模式，不是 range
   - intraday 必须保留独立状态模型
   - 第一版不做准实时 watcher / 高频刷新
   - Codex 必须扩 scanner/cache/fetcher，而不是另起临时数据链路
7. Gemini CLI 作为外部评审补充了 3 条工程边界：
   - Codex 小时级 cache 必须限制保留窗口，避免体积无限膨胀
   - intraday 需要显式处理午夜 rollover 与时区变更
   - 零桶补齐必须在 service/fetcher 层完成，不能把“补洞”职责下放给 UI

## 建议执行顺序

1. 先补 feature/spec，明确 intraday 的产品语义与 BDD。
2. 抽出通用模型：
   - `ProviderIntradayUsagePoint`
   - `ProviderIntradayUsageSnapshot`
   - `ProviderUsageCurveGranularity`
3. 先实现 Gemini intraday service，并接到现有 token trend section 的粒度切换。
4. Codex 单独立项，评估：
   - 扩 `CostUsageScanner` hour bucket
   - 或新增 scanner report 层
5. Codex 落地前，不在 UI 暴露 intraday 切换给 Codex，避免形成半可用入口。

## 设计方案（定稿）

### 1. 设计目标

1. 在不破坏现有日级 token trend 的前提下，为 `Usage` 页增加“日内使用曲线”。
2. 保持用户心智稳定：
   - 账号用量仍是第一层
   - 历史 Token 消耗仍是唯一趋势模块
   - 日内曲线只是趋势模块中的新观察尺度
3. 允许 provider 分阶段开通：
   - Gemini 先支持
   - Codex 后支持
4. 保证数据口径一致：
   - 同一 provider 的日级与日内数据尽量来自同一条聚合链
   - 避免 App 层临时扫文件造成“Today summary”和“Today chart”对不上

### 2. 非目标

1. 第一版不做分钟级曲线。
2. 第一版不做跨账号合并 intraday。
3. 第一版不新增“峰值小时/平均小时”这类第二排 summary。
4. 第一版不把现有 `7D / 30D / ALL` 的日级 summary 改成跟随 intraday 变化。
5. 第一版不尝试把 Claude / Copilot 一并接入。

### 3. 最终交互设计

#### 3.1 Section 位置

- 仍放在现有 `Usage` 页的“历史 Token 消耗” section 内。
- 不新增独立 section，不新增新的大标题。

#### 3.2 控件结构

- 第一排仍保留现有 section 标题与刷新动作。
- 第二排新增“观察尺度”切换，仅当 provider 支持 intraday 时显示：
  - `历史`
  - `Today`
- 第三排保留原有日级范围切换，但仅在 `历史` 模式下显示：
  - `7D`
  - `30D`
  - `ALL`

#### 3.3 交互规则

- 当用户选择 `历史`：
  - 使用现有日级数据
  - 显示现有 summary + chart + table
- 当用户选择 `Today`：
  - summary 仍显示日级稳定口径，不新增第二套 summary
  - chart 改为本地时区 `00:00 -> 当前小时` 的小时桶
  - table 改为小时 breakdown
  - `7D / 30D / ALL` 控件隐藏
- 当 provider 不支持 intraday：
  - 不显示 `Today` 切换
  - 保持现有 UI 不变

#### 3.4 第一版视觉约束

- `Today` 模式固定 `1h bucket`
- 横轴 label 使用本地时间小时：
  - `00`
  - `01`
  - ...
  - `23`
- 若当天尚未到某小时：
  - 不显示未来桶
- 若某小时无数据：
  - 显示 0 值桶，避免曲线断裂和宽度跳动

### 4. 推荐状态模型

#### 4.1 不修改现有日级模型

保留现有：

- `ProviderTokenTrendPoint`
- `ProviderTokenTrendSnapshot`

理由：

- 它已经被日级 chart、table、summary 广泛消费。
- 强行改成“既支持天又支持小时”的通用点位，会把现有文案和 UI 语义搅乱。

#### 4.2 新增 intraday 模型

推荐新增到 `libs/Providers/Sources/ProviderUsage/`：

```swift
public enum ProviderUsageCurveCapability: Sendable, Equatable {
    case dailyOnly
    case dailyAndIntradayToday
}

public enum ProviderIntradayBucket: String, Codable, Sendable, Equatable {
    case hour1
}

public struct ProviderIntradayUsagePoint: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let bucketStart: Date
    public let bucketEnd: Date
    public let label: String
    public let totalTokens: Int
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheReadTokens: Int
}

public struct ProviderIntradayUsageSnapshot: Codable, Sendable, Equatable {
    public let points: [ProviderIntradayUsagePoint]
    public let totalTokens: Int?
    public let updatedAt: Date
    public let sourceLabel: String
    public let bucket: ProviderIntradayBucket
    public let timezoneIdentifier: String
    public let localDayKey: String
}
```

#### 4.3 ViewModel 状态

推荐在 `ProviderUsageEngine` 新增：

```swift
enum TokenTrendMode: String, CaseIterable, Identifiable {
    case history
    case today
}

var tokenTrendMode: TokenTrendMode = .history
var intradayCapability: ProviderUsageCurveCapability = .dailyOnly
var intradaySnapshot: ProviderIntradayUsageSnapshot?
var intradayErrorMessage: String?
var isLoadingIntraday = false
```

设计意图：

- `history` 和 `today` 是并列模式，不把 `Today` 强塞到现有 `TokenTrendRange`。
- `TokenTrendRange` 继续只服务日级模式。

### 5. Provider API 设计

#### 5.1 统一协议

推荐新增一个轻量协议，而不是把 intraday 混进现有 daily service：

```swift
public protocol ProviderIntradayUsageDescribing: Sendable {
    var provider: UsageProvider { get }
    var capability: ProviderUsageCurveCapability { get }
    func fetchTodayIntradaySnapshot(
        timezone: TimeZone,
        environment: [String: String]
    ) async throws -> ProviderIntradayUsageSnapshot?
}
```

然后在 `ProviderUsageRegistry` 旁边新增：

```swift
public enum ProviderIntradayUsageRegistry {
    public static func descriptor(for provider: UsageProvider) -> (any ProviderIntradayUsageDescribing)?
}
```

#### 5.2 为什么不直接复用 `ProviderUsageDescribing`

- `ProviderUsageDescribing` 当前负责“账号用量快照”，不是趋势。
- 把 intraday trend 塞进去会让单次 fetch 变成：
  - account usage
  - credits
  - cost
  - daily trend
  - intraday trend
- 这会让链路过重，也会放大失败耦合。

结论：

- daily trend 与 intraday trend 应保持独立拉取、独立错误态。

### 6. UI 数据适配设计

#### 6.1 Section 适配层

当前 `ProviderTokenTrendSection` 只接受日级 snapshot。

推荐改成接受组合数据：

```swift
struct ProviderUsageTrendSectionInput {
    let mode: TokenTrendMode
    let dailySnapshot: ProviderTokenTrendSnapshot?
    let intradaySnapshot: ProviderIntradayUsageSnapshot?
    let dailyRange: ProviderUsageEngine.TokenTrendRange
    let availableDailyRanges: [ProviderUsageEngine.TokenTrendRange]
    let capability: ProviderUsageCurveCapability
    let isLoadingDaily: Bool
    let isLoadingIntraday: Bool
    let dailyErrorMessage: String?
    let intradayErrorMessage: String?
}
```

#### 6.2 NolonUIFoundation 层

不建议让 UI 组件直接知道 provider 原始模型。

推荐在 `libs/NolonUIFoundation/Sources/NolonUIFoundation/ProviderTokenTrendModels.swift` 增加一组通用展示模型：

```swift
public struct ProviderUsageTrendModeOption: Identifiable, Hashable, Sendable
public struct ProviderUsageCurvePointData: Hashable, Sendable
public struct ProviderUsageCurveSnapshotData: Sendable
public struct ProviderUsageTrendSectionData: Sendable
```

其中：

- `ProviderUsageCurvePointData` 用 `label` 作为横轴显示
- 日级与日内都转成这一层
- 这样 `NolonUI.ProviderTokenTrendSectionView` 可以升级成真正的“趋势通用视图”

#### 6.3 UI 行为

- `history` 模式：
  - 继续走现有 summary/card/chart/table
- `today` 模式：
  - 复用同一套 chart/table 组件
  - 仅替换 points 和行标题
  - table 第一列从 `Date` 改成 `Hour`

### 7. Gemini 实现方案

#### 7.1 数据来源

- 继续使用 `~/.gemini/tmp/**/chats/session-*.json`
- 不改 runtime home 规则
- 只统计活跃账号对应的全局 session 语义，保持与当前 daily trend 一致

#### 7.2 聚合逻辑

在 `GeminiTokenTrendService` 旁边新增：

```swift
public struct GeminiIntradayUsageService: Sendable
```

聚合规则：

1. 扫描所有 session JSON
2. 只取 `type == "gemini"` 且有 `tokens`
3. 读取 `timestamp`
4. 转为本地时区小时桶
5. 对当天 bucket 做累加：
   - `input`
   - `output`
   - `cached`
   - `total`

输出：

- 从本地 `00:00` 到当前小时的连续桶
- 缺失桶补 0

#### 7.3 风险

- session 文件数多时，冷启动读取量偏大
- 第一版可接受，因为数据源现成，且可后续再加 file-level cache

### 8. Codex 实现方案

#### 8.1 推荐方案

推荐方案是：

- 扩现有 `CostUsageScanner`
- 让 scanner 在解析 token delta 时同时维护：
  - `dayKey -> model -> packed usage`
  - `hourKey -> model -> packed usage`

不推荐第一版就另起一套完全独立的 intraday scanner。

#### 8.2 原因

1. 原始 rollout 已经有 timestamp，scanner 也已经在读。
2. 当前 cache/fetcher/UI 都依赖这条稳定链路。
3. 若 App 层临时再扫一次 rollout，会造成两套来源并存。

#### 8.3 Cache 设计

当前：

```swift
days: [String: [String: [Int]]]
```

推荐升级为：

```swift
days: [String: [String: [Int]]]
hours: [String: [String: [Int]]]
```

其中：

- `dayKey = yyyy-MM-dd`
- `hourKey = yyyy-MM-dd HH`

推荐保留在同一个 cache 文件版本里做 `v2` 升级，而不是新开独立 intraday cache 文件。

原因：

1. 避免两套缓存生命周期分裂
2. 同一批 scanner 解析结果一次写完
3. 后续更容易校验“日级总量 == 小时桶求和”

#### 8.4 Fetcher 设计

在 `CostUsageFetcher` 旁边新增：

```swift
public func loadIntradayTokenSnapshot(
    provider: UsageProvider,
    now: Date = Date(),
    bucket: ProviderIntradayBucket = .hour1,
    forceRefresh: Bool = false,
    environment: [String: String] = ProcessInfo.processInfo.environment
) async throws -> ProviderIntradayUsageSnapshot
```

只支持：

- `provider == .codex`
- `bucket == .hour1`
- 当地当天数据

#### 8.5 扫描规则

1. scanner 仍按现有 session 文件扫描范围工作
2. 当解析到 token delta 的 timestamp 时：
   - 先算本地 `dayKey`
   - 再算本地 `hourKey`
3. 对两个维度同时写入聚合
4. `loadIntradayTokenSnapshot(...)` 只从 `hours` 中取 `today` 的小时桶

#### 8.6 一致性校验

Codex 落地必须补一组测试：

- 同一批 token delta
- `sum(hours in today) == day(today)`

这组测试要在 scanner 层完成，而不是 UI 层。

### 9. Engine 与页面改造方案

#### 9.1 Engine

在 `ProviderUsageEngine.refreshTokenTrend()` 之外，新增：

```swift
func refreshIntradayUsage() async
func refreshTrendSectionForCurrentMode() async
func setTokenTrendMode(_ mode: TokenTrendMode)
```

行为：

- `setTokenTrendMode(.history)`：
  - 仅在首次为空时拉取 daily
- `setTokenTrendMode(.today)`：
  - 首次切换时拉取 intraday
  - 后续手动刷新时只刷新当前模式

#### 9.2 自动刷新

第一版建议：

- 页面自动刷新仍沿用现有 daily 刷新节奏
- intraday 不单独加高频轮询
- 用户切到 `Today` 后：
  - 页面首屏加载一次
  - 手动 refresh 可刷新

原因：

- 先控制复杂度
- 避免把 intraday 做成“准实时监控”

#### 9.3 文件监听

- Gemini 第一版不新增 watcher
- Codex 第一版依然依赖现有 trend refresh 触发
- 等 intraday 正式落地并确认体验需要时，再评估针对 intraday 的独立 watcher 或更细粒度 refresh

### 10. 调试与文案

#### 10.1 Page Marker

建议统一为：

- `provider / usage / 历史 Token 消耗 / 历史`
- `provider / usage / 历史 Token 消耗 / Today`

不要单开一个中文标题完全不同的 marker，避免调试路径分叉。

#### 10.2 文案

推荐：

- section 标题仍然是：`历史 Token 消耗`
- 模式切换：
  - `历史`
  - `Today`
- `Today` 模式下的辅助文案：
  - `Local Time · 1h buckets`

### 11. 迁移计划

#### Phase 0：模型与 UI 适配层

1. 新增 intraday domain models
2. 新增 UI foundation 展示模型
3. 改造 `ProviderTokenTrendSection` 为双模式 section
4. 先不接任何 provider 数据，只让静态预览跑通

#### Phase 1：Gemini

1. 新增 `GeminiIntradayUsageService`
2. `ProviderUsageEngine` 接入 Gemini intraday
3. 仅对 Gemini 显示 `Today`
4. 补 service + engine + section 的测试

#### Phase 2：Codex

1. 升级 `CostUsageCache` 到 v2
2. scanner 同时维护 `days/hours`
3. `CostUsageFetcher` 新增 intraday snapshot API
4. `Codex` 打开 `Today`
5. 补 scanner/fetcher 一致性测试

### 12. 测试方案

#### 12.1 Domain / Service

1. Gemini：
   - 给定多条不同小时的消息，正确聚合到小时桶
   - 缺失小时自动补 0
   - 非当天消息被过滤
2. Codex：
   - 给定 rollout token delta，正确写入 `hourKey`
   - 小时桶汇总与 `dayKey` 汇总一致
   - cache v1 -> v2 迁移后不丢日级数据

#### 12.2 Engine

1. `history` 与 `today` 模式切换行为正确
2. refresh 按当前模式触发，不串线
3. provider capability 为 `dailyOnly` 时不显示 `Today`

#### 12.3 UI

1. `history` 模式保持现有视觉行为不回归
2. `today` 模式 table 第一列显示小时
3. loading / error / empty state 三态完整
4. marker 路径正确包含 `Today`

### 13. 推荐最终决策

综合工程复杂度、数据口径和演进成本，推荐最终决策如下：

1. UI 采用“同一趋势 section + 模式切换”，不新增独立 section。
2. 状态模型采用“双模型并存”：
   - 日级继续用 `ProviderTokenTrendSnapshot`
   - 日内新增 `ProviderIntradayUsageSnapshot`
3. Gemini 先接入，Codex 后接入。
4. Codex 必须扩 scanner/cache/fetcher，不做 App 层临时扫 rollout。
5. 第一版固定：
   - `Today`
   - `1h bucket`
   - `Local Time`
   - 不新增 intraday summary
6. 三位 subagent 复核后的附加约束：
   - `Today` 以模式切换出现，不与 `7D / 30D / ALL` 同层并存
   - intraday 切换只对 `supportsIntradayTokenCurve == true` 的 provider 暴露
   - 首版刷新策略采用“首次切入 + 手动刷新 + 午夜重置”
7. Gemini CLI 外部评审后的附加约束：
   - Codex `hours` cache 需要清理策略，推荐有限保留窗口
   - `ProviderIntradayUsageSnapshot` 必须携带 `timezoneIdentifier`
   - service/fetcher 直接输出连续小时桶，UI 不做补零

## 开放问题

1. `Today` 是否需要在午夜自动滚动清零并触发一次无感刷新。
2. 图表是显示 24 个固定小时桶，还是“从本地 00:00 到当前小时”的动态桶。
3. Codex 的 hour bucket 应写入现有 cache 文件，还是新开 `-intraday` cache 版本。
4. 调试定位文案是沿用 `历史 Token 消耗 / Today`，还是新增更明确的 `日内使用曲线` marker。

## 第 9 轮

时间：2026-04-14 15:52（Asia/Shanghai）

### 背景

上一轮虽然主方案已经稳定，但仍有 3 类“有条件接受”意见集中在同一批边界上：

1. `Today` 的可见性、模式回退与 capability 之间的驱动关系还需要彻底写死。
2. `timezoneIdentifier`、`Today` 日边界、`sum(hours in today) == day(today)` 的对账口径需要统一到同一份 snapshot。
3. 午夜 rollover / 时区变化 / DST / 不完整桶 / freshness 提示这些实现边界需要从“建议”升级为“硬约束”。

### 本轮参与者观点

#### Anscombe（可靠性 subagent）

- 观点：有条件接受。
- 理由：
  - 主方案本身没有问题，问题只剩测试与可靠性边界是否写死。
  - 必须强制校验 `timezoneIdentifier` 存在并参与聚合。
  - 必须覆盖跨午夜、时区变化、cache 失效、补零失败等验证场景。

#### Claude Code（外部评审）

- 观点：有条件接受。
- 理由：
  - 主方向正确，但要补齐 `Today` 可用性回退、DST/跨时区边界、以及 freshness 可见性。

#### Codex CLI（外部评审）

- 观点：有条件接受。
- 理由：
  - 主方案已经收敛，但要把 `Today` 的统计口径、capability 驱动显隐、以及 snapshot/cache 失效规则写成一致口径。

### 修订版共识包

综合上述条件项，本轮把主方案升级为下面这 7 条明确约束：

1. `Today` 的显隐只能由 intraday capability 驱动，UI 不得再写 provider 名单判断或临时分支。
2. 当 provider 不支持 intraday、能力变更、或当天没有可展示 intraday 数据时，模式自动回退到 `历史`，不允许停留在无效 `Today`。
3. `Today` 的日边界、小时桶聚合、以及 `sum(hours in today) == day(today)` 校验，统一以同一份 intraday snapshot 的 `timezoneIdentifier`、同一聚合窗口、同一次快照为准。
4. DST / 时区变化场景不假定固定 24 桶；允许出现 `23 / 25` 个 `1h buckets`。
5. 午夜 rollover 或时区变化时，不仅 Codex 小时级 cache 失效，当前已加载的 intraday snapshot 也立即视为失效；下次进入 `Today` 或手动刷新时重取。
6. service/fetcher 层必须对不完整桶、补零失败、fetch 失败做标记或日志；UI 只消费结果与 freshness，不负责补洞。
7. `Today` 视图必须显示非实时 freshness 信息，例如 `loaded at` / `last updated`，避免被误读成准实时监控。

## 第 10 轮

时间：2026-04-14 15:56（Asia/Shanghai）

### 最终确认轮

本轮只问一个问题：在引入“修订版共识包”后，是否直接接受，不再允许提出新方案。

#### 三位 subagent

##### Meitner（UI/交互）

- 结论：接受。
- 理由：修订版已经明确 capability 驱动、自动回退、统一时区边界、`23 / 25` 桶、快照失效与 freshness 提示，现有 Usage 页的体验约束已经闭环。

##### Kant（数据架构）

- 结论：接受。
- 理由：修订版明确了 capability 驱动、退回逻辑、时区一致性、非 24 桶空间以及刷新/失效与新鲜度提示，数据一致性与演进边界都足够稳定。

##### Anscombe（可靠性/测试）

- 结论：接受。
- 理由：修订版通过统一 snapshot 口径、失效规则、日志标记与 freshness 提示，补齐了上一轮缺失的可靠性边界。

#### 外部 CLI

##### Claude Code

- 结论：接受。
- 理由：修订版已经把 `Today` 的能力来源、失效回退、时区 / DST 一致性、缓存边界、分层职责与 freshness 展示全部收敛清楚。

##### Gemini CLI

- 结论：接受。
- 理由：修订版清晰解决了 `Today` 视图的数据一致性、可用性以及用户体验问题。
- 备注：
  - `gemini-3.1-pro-preview` 在本机调用时出现容量不足（`429 RESOURCE_EXHAUSTED`）。
  - 切换到 `gemini-2.5-flash` 后得到稳定结论。

##### Codex CLI

- 结论：接受。
- 理由：修订版约束清晰且内部一致，已经覆盖 `Today` 模式的 capability 判定、失效回退、时区 / DST 一致性、缓存与快照失效、日志分层以及 freshness 展示边界。

## 最终共识状态

### 已达成一致的结论

1. 日内使用曲线继续放在现有 `历史 Token 消耗` section 内，以 `历史 / Today` 模式切换承载，不新增独立 section。
2. 第一版固定为 `Today + Local Time + 1h buckets`，不新增第二排 intraday summary，也不做准实时 watcher。
3. 日级与日内状态模型保持分离：
   - 日级继续使用 `ProviderTokenTrendSnapshot`
   - 日内使用独立 `ProviderIntradayUsageSnapshot`
4. `Today` 的显隐与可用性只能由 capability 驱动；能力缺失、能力变更或当天无 intraday 数据时，自动回退到 `历史`。
5. 所有 `Today` 相关对账口径统一以 snapshot 自带的 `timezoneIdentifier` 为准，不再假定永远 24 个小时桶；DST 日允许 `23 / 25` 桶。
6. Codex 必须扩现有 scanner/cache/fetcher，不允许 App 层临时另起 intraday 扫描链路。
7. service/fetcher 层负责补零、错误标记、完整性校验与 freshness 产出；UI 不负责补洞，只负责展示。
8. 首版刷新策略固定为：
   - 首次切到 `Today` 时加载
   - 手动刷新
   - 午夜 rollover / 时区变化后使当前 snapshot 失效，并在下次进入 `Today` 或手动刷新时重取

### 已关闭的问题

1. `Today` 是否需要午夜自动无感刷新：
   - 结论：第一版不做后台无感刷新，只做 snapshot 失效与下次进入/手动刷新重取。
2. 小时桶是否固定 24：
   - 结论：不写死 24，以 `timezoneIdentifier` 对应的本地日历为准；DST 日允许 `23 / 25` 桶。
3. 调试定位文案：
   - 结论：继续沿用 `provider / usage / 历史 Token 消耗 / Today`，不新开一条完全平行的 marker。

### 剩余未决点

1. `Codex` 的 hour bucket 最终落在现有 cache 文件还是拆出 `-intraday` 版本，仍属 Phase 2 的实现细节。
2. 该点不再阻塞产品方案、交互方案和模型边界，共识已经达成。

## 第 11 轮

时间：2026-04-14 16:05（Asia/Shanghai）

### 用户新增场景

用户追加的新交互前提是：

1. 当前图表主视图仍然是日级图表。
2. 当用户点击某一个具体日期时，展开该日期的更细粒度曲线。
3. 细粒度默认使用 `30min` bucket。
4. 用户可切换：
   - `15min`
   - `30min`
   - `60min`

### 对既有结论的影响

这个新增场景意味着，前文把 intraday 入口定义成 `Today` 独立模式的方案需要被修正：

1. intraday 不再只服务于 `Today`。
2. intraday 的入口不再是单独的 `Today` 模式切换，而是“在现有日级图表上点击某一天后进入单日钻取”。
3. `1h bucket` 不再是首版唯一粒度，而是三档粒度中的一档：
   - `15min`
   - `30min`
   - `60min`
4. 默认粒度从先前的 `1h` 改为 `30min`。

### 修正后的产品交互

#### 11.1 主视图

- `历史 Token 消耗` 的首屏仍然保持现有日级趋势。
- 现有 `7D / 30D / ALL` 继续表示“日级观察窗口”。
- 用户未点击具体日期前，不展示分钟级曲线。

#### 11.2 单日钻取

- 用户点击某一个日级点位后，在同一个 section 内展开第二层图表。
- 第二层图表语义是：
  - `选中日期的日内曲线`
- 展开区建议包含：
  - 选中日期标题
  - bucket 切换：`15min / 30min / 60min`
  - 关闭钻取或返回日级视图的入口

#### 11.3 默认状态

- 选中某一天后：
  - 默认加载该天的 `30min` bucket
- 用户手动切换到：
  - `15min`
  - `60min`

#### 11.4 `Today` 的位置

- `Today` 不再作为独立模式出现。
- `Today` 只是“日级图表中可被点击的一天”。
- 若后续需要强调当天，可在日级图表里对当天点位做视觉强调，但不再单独加一个 `Today` 模式。

### 修正后的状态模型

前文中 `history / today` 双模式模型不再适合作为最终方案，需要改成“日级主视图 + 单日钻取态”：

```swift
public enum TokenTrendPresentationMode: Sendable, Equatable {
    case daily
    case intraday(dayKey: String, bucket: ProviderIntradayBucket)
}
```

`ProviderIntradayBucket` 也要从原先的 `hour1` 扩为：

```swift
public enum ProviderIntradayBucket: String, Codable, Sendable, Equatable, CaseIterable {
    case minute15
    case minute30
    case hour1
}
```

`ProviderIntradayUsageSnapshot` 需要显式绑定“是哪一天”的本地口径：

```swift
public struct ProviderIntradayUsageSnapshot: Codable, Sendable, Equatable {
    public let providerID: String
    public let dayKey: String
    public let timezoneIdentifier: String
    public let bucket: ProviderIntradayBucket
    public let points: [ProviderIntradayUsagePoint]
    public let fetchedAt: Date
}
```

### 修正后的能力定义

provider capability 从“是否支持 Today intraday”改成“是否支持按日钻取 intraday”：

```swift
public enum ProviderUsageCurveCapability: Sendable, Equatable {
    case dailyOnly
    case dailyWithIntradayDrilldown
}
```

约束：

1. 只有 `dailyWithIntradayDrilldown` 的 provider，日级点位才允许进入钻取。
2. UI 不允许通过 provider 名单硬编码是否可钻取。
3. 若 provider 不支持 intraday，则点击日级点位不进入分钟级展开。

### 修正后的数据聚合与缓存策略

由于首版就要支持 `15 / 30 / 60 min` 三档切换，仅存小时桶已经不够。

#### 11.5 聚合基准粒度

推荐把内部 canonical bucket 固定为 `15min`：

1. `15min` 直接由原始事件按 timestamp 聚合得到。
2. `30min` 由两个 `15min` 桶合并得到。
3. `60min` 由四个 `15min` 桶合并得到。

这样做的原因：

1. 一套底层聚合即可支撑三档 UI 粒度。
2. `30min` 作为默认档不会要求单独保存第二套缓存。
3. 更容易校验：
   - `sum(15min buckets in day) == day(day)`
   - `sum(30min buckets in day) == day(day)`
   - `sum(60min buckets in day) == day(day)`

#### 11.6 Gemini

Gemini 第一版不需要先把所有历史分钟桶长期缓存到磁盘，可以先走“按选中日期即时聚合”的方案：

1. 日级趋势仍按现有方式提供。
2. 用户点击某一天时，扫描该 provider 可见 session/chat 数据。
3. 只取命中该本地日历日的数据。
4. 先聚合成 `15min` base buckets。
5. 再根据 UI 当前粒度输出 `15 / 30 / 60 min`。

#### 11.7 Codex

Codex 需要把前文的 `hours` 设计进一步修正为 `quarterHours` 或等价的 `15min` 基准桶，而不是只存小时桶。

推荐方向：

```swift
days: [String: [String: [Int]]]
quarterHours: [String: [String: [Int]]]
```

其中：

- `dayKey = yyyy-MM-dd`
- `quarterHourKey = yyyy-MM-dd HH:mm`
- `mm` 仅允许：
  - `00`
  - `15`
  - `30`
  - `45`

约束：

1. `30min` / `60min` 不单独落缓存，统一由 `15min` base 聚合导出。
2. 不能退回到“App 层单独再扫一天的 session/rollout”。
3. scanner/fetcher 仍然是 Codex intraday 的唯一正式数据链路。

### 修正后的刷新策略

由于现在支持“任意被点击的一天”：

1. 若选中的是今天：
   - 首次展开加载
   - 手动刷新
   - 午夜 rollover / 时区变化后失效
2. 若选中的是历史日：
   - 默认视为静态历史快照
   - 不参与午夜自动失效
   - 手动刷新时可重新拉取，但不需要准实时刷新

### 修正后的测试门禁

#### 11.8 Domain / Service

1. 点击某一天后，默认返回该天 `30min` buckets。
2. 同一份 `15min` base buckets 切换到 `30min` / `60min` 时，总量保持一致。
3. 非选中日期的数据不得混入。
4. DST 日不假定固定桶数：
   - `15min` 允许 `92 / 96 / 100` 桶
   - `30min` 允许 `46 / 48 / 50` 桶
   - `60min` 允许 `23 / 24 / 25` 桶

#### 11.9 Engine / UI

1. 日级图表点击某一天后，进入单日钻取态。
2. 钻取态默认 bucket 为 `30min`。
3. 切换 bucket 时，selected day 不应丢失。
4. 关闭钻取后，恢复原来的日级 range 与滚动位置。
5. provider 不支持 intraday drilldown 时，不进入展开态。

## 最新共识状态（覆盖前文 `Today-only` 结论）

以下结论覆盖前文把 intraday 定义为 `Today + 1h bucket` 的版本：

1. 主图仍然是日级趋势图，`7D / 30D / ALL` 继续存在。
2. intraday 的入口改为“点击某一个具体日期后展开单日钻取”，不再使用独立 `Today` 模式。
3. 单日钻取默认粒度是 `30min`，并允许用户切换：
   - `15min`
   - `30min`
   - `60min`
4. `Today` 仅是日级图表中的某一天，不再作为独立交互模式。
5. 日级与日内模型仍保持分离，但 intraday snapshot 必须绑定：
   - `dayKey`
   - `timezoneIdentifier`
   - `bucket`
6. provider capability 改为 `dailyOnly / dailyWithIntradayDrilldown`。
7. Gemini 第一版可先做“按选中日即时聚合 + 15min base buckets”。
8. Codex 不再以小时桶为缓存基准，而是升级为 `15min` 基准桶，再导出 `30 / 60 min` 视图粒度。
9. 所有对账口径统一为：
   - 同一选中日
   - 同一 `timezoneIdentifier`
   - 同一份 intraday snapshot
10. 仍然不做准实时 watcher；今天与历史日采用不同失效策略：
   - 今天：首次展开 + 手动刷新 + 跨日/时区变化失效
   - 历史日：静态历史快照 + 按需手动刷新

## 第 14 轮

时间：2026-04-14 16:38（Asia/Shanghai）

### 剩余 3 个歧义点

在单日钻取方案达成大方向共识后，还剩 3 个需要收口的实现/交互细节：

1. 单日钻取采用：
   - `A1` 内联展开
   - `A2` 详情态切换
2. 钻取打开后主图交互采用：
   - `B1` 保留主图 range 切换和 hover，但锁定 `selected day`
   - `B2` 冻结主图交互，改 range 先退出钻取
3. Gemini Phase 1 历史单日钻取是否加轻量文件级 cache：
   - `C1` 不做文件级 cache，只做按选中日即时聚合
   - `C2` 做轻量文件级 cache，但仅针对历史日单日钻取结果

### 本轮第一阶段票型

#### 三位 subagent

##### Descartes（UI/交互）

- 选择：`A1 + B1 + C1`
- 理由：保留主图上下文，同时避免引入额外 cache 成本。

##### Hubble（数据架构）

- 选择：`A2 + B1 + C1`
- 理由：详情态更干净，但仍希望保留主图分析连续性。

##### Popper（可靠性/测试）

- 选择：`A1 + B1 + C2`
- 理由：主图可见更利于核对全局趋势，历史日 cache 有助于复现。

#### 外部 CLI

##### Claude Code

- 选择：`A1 + B2 + C1`
- 理由：保留钻取上下文，但不赞成主图与钻取同时可操作。

##### Gemini CLI

- 选择：`A1 + B1 + C2`
- 理由：内联展开体验更连续，历史日 cache 可优化重复查看。

##### Codex CLI

- 选择：`A2 + B2 + C1`
- 理由：主图和钻取最好分层，且不建议 Phase 1 增加文件级 cache。

### 第一阶段结论

经过第一阶段投票后：

1. `C1` 明显占优：
   - `Descartes`
   - `Hubble`
   - `Claude Code`
   - `Codex CLI`
2. `B2` 被三位 subagent 一致否决，不适合作为最终方案。
3. `A` 仍有分歧，但 `A1` 票数略高，且与“钻取而非模式切换”的原始产品语义更一致。

因此，本轮进入第二阶段，只确认下面这个“逐项多数 + 不违反既有共识”的最终包是否接受：

1. `A1`：内联展开
2. `B1`：保留主图 range/hover，但锁定 `selected day`
3. `C1`：Gemini Phase 1 不做文件级 cache

## 第 15 轮

时间：2026-04-14 16:42（Asia/Shanghai）

### 最终确认包

最终确认包如下：

1. `A` 采用 `A1`：
   - 单日钻取以内联展开方式呈现，主图仍留在同一 section 内可见。
2. `B` 采用 `B1`：
   - 钻取打开后仍保留主图 range 切换和 hover，但锁定 `selected day`；
   - range 变化不能让 `selected day` 丢失或被重写。
3. `C` 采用 `C1`：
   - Gemini Phase 1 不做文件级 cache，只做按选中日即时聚合。
4. 既有共识保持不变：
   - `15min` 是唯一事实缓存
   - `30/60min` 为派生展示
   - `Today` 不是独立模式

### 最终确认结果

#### 三位 subagent

##### Descartes

- 结论：接受。
- 理由：`A1 + B1` 保留主图上下文、避免选日丢失，同时 `C1` 维持简单即时聚合。

##### Hubble

- 结论：接受。
- 理由：保留主图交互同时锁定选中日，满足连续探索与数据一致性，并且不引入额外 cache 复杂度。

##### Popper

- 结论：接受。
- 理由：内联钻取保持主图可见且 range/hover 仍可调，锁定 `selected day` 防止状态漂移，且即席聚合满足缓存共识。

#### 外部 CLI

##### Claude Code

- 结论：接受。
- 理由：该最终包在交互连续性、状态一致性与 Phase 1 实现复杂度之间达成了自洽且可落地的平衡。

##### Gemini CLI

- 结论：接受。
- 理由：这些点清晰地界定了最终包的范围和处理方式。

##### Codex CLI

- 结论：接受。
- 理由：该最终包在交互一致性、状态约束和 Phase 1 实现边界上自洽，并保持了既有缓存共识不变。

## 最终关闭状态

下面 3 个问题已经全部关闭，不再保留为开放问题：

1. 单日钻取呈现形态：
   - 结论：`A1` 内联展开。
2. 钻取打开后主图交互：
   - 结论：`B1` 保留主图 range 切换和 hover，但锁定 `selected day`。
3. Gemini Phase 1 历史单日钻取 cache：
   - 结论：`C1` 不做文件级 cache，只做按选中日即时聚合。

## 最新共识状态（全部歧义已关闭）

1. Usage 主图保持日级趋势图，保留 `7D / 30D / ALL`。
2. 用户点击某一天后，在同一 section 内以内联展开方式进入单日钻取。
3. 单日钻取默认 `30min`，可切换：
   - `15min`
   - `30min`
   - `60min`
4. 钻取态下主图仍可进行 range 切换和 hover，但必须锁定 `selected day`，不能让当前钻取对象丢失或变化。
5. `Today` 不再是独立模式，只是日级图中的一天。
6. intraday snapshot 的正式字段至少包括：
   - `dayKey`
   - `timezoneIdentifier`
   - `bucket`
   - `actualBucketCount`
   - `rangeStart`
   - `rangeEnd`
   - `fetchedAt`
7. `dayKey` 的口径固定为 `timezoneIdentifier` 下的本地自然日。
8. `15min` base buckets 是唯一事实缓存；`30/60min` 只做派生展示。
9. capability 固定为：
   - `dailyOnly`
   - `dailyWithIntradayDrilldown`
10. UI 必须提供：
    - 不支持 drilldown 时的禁用/原因提示
    - 所选粒度与实际桶数展示
    - 历史日的静态快照/手动刷新语义
11. `Today` 的失效策略固定为：
    - 跨到下一个本地自然日失效
    - 时区变化失效
    - 用户主动刷新时重取
12. 历史日默认静态，仅在手动刷新时更新。
13. Gemini Phase 1 不做文件级 cache，只做按选中日即时聚合。
14. 该版本已经得到 3 个 subagent、`Claude Code`、`Gemini CLI`、`Codex CLI` 的一致接受。

## 第 12 轮

时间：2026-04-14 16:28（Asia/Shanghai）

### 新一轮 agent 复核目标

本轮不再讨论“是否改成单日钻取”，而是只确认下面这个版本是否足够稳定，可以作为新的正式共识：

1. 主图保持日级趋势图，保留 `7D / 30D / ALL`。
2. 用户点击某一天后进入单日钻取；默认 `30min`，可切换 `15min / 30min / 60min`。
3. `Today` 不再是独立模式，只是日级图中的一天。
4. intraday snapshot 至少包含：
   - `dayKey`
   - `timezoneIdentifier`
   - `bucket`
   - `actualBucketCount`
   - `rangeStart`
   - `rangeEnd`
   - `fetchedAt`
5. `dayKey` 定义为：按 `timezoneIdentifier` 解释的本地自然日。
6. cache 的唯一事实源是该 `dayKey` 下的 `15min` base buckets；`30/60min` 只做派生展示，不另存事实缓存。
7. capability 固定为：
   - `dailyOnly`
   - `dailyWithIntradayDrilldown`
8. 不支持 drilldown 的 provider 在 UI 上必须显式禁用或提示原因。
9. 钻取 UI 必须展示所选粒度与实际桶数，例如 `30min · 48 桶`；历史日还要展示“静态快照 / 手动刷新”语义。
10. `Today` 的失效触发点固定为：
    - 跨到下一个本地自然日
    - `timezoneIdentifier` 变化
    - 用户主动刷新
11. DST 日允许变长桶数：
    - `15min`: `92 / 96 / 100`
    - `30min`: `46 / 48 / 50`
    - `60min`: `23 / 24 / 25`
12. 仍不做准实时 watcher。

### 本轮参与者观点

#### Kepler（UI/交互 subagent）

- 初始结论：有条件接受。
- 条件：
  - UI 需要显式展示实际桶数
  - 不支持 drilldown 的 provider 需要禁用/原因提示
  - 历史日需要显式“静态快照 / 手动刷新”反馈

#### Dirac（数据架构 subagent）

- 初始结论：有条件接受。
- 条件：
  - 必须补齐 snapshot metadata
  - 必须写死 `dayKey` 的本地自然日定义
  - 必须明确 `15min` 是唯一事实缓存，`30/60min` 只是派生视图

#### Nietzsche（可靠性/测试 subagent）

- 初始结论：有条件接受。
- 条件：
  - 必须用自动化测试锁定 `snapshot` 字段、DST 变长桶数、今天/历史日的失效差异

#### Claude Code

- 初始结论：有条件接受。
- 条件：
  - 需要把 `dayKey` 与缓存事实源再收口一次

#### Gemini CLI

- 初始结论：接受。
- 理由：
  - 单日钻取与数据策略已经足够完整

#### Codex CLI

- 初始结论：接受。
- 理由：
  - 单日钻取、缓存事实源、能力回退、失效语义与 DST 桶数已经形成闭环

### 修订后的收口

本轮把所有“有条件接受”项合并后，得到的结论是：

1. 单日钻取方案本身没有被任何 agent 反对。
2. 所有条件项都只是补齐边界，而不是推翻方向。
3. 条件项已经被吸收到上面的 12 条正式约束中。

## 第 13 轮

时间：2026-04-14 16:31（Asia/Shanghai）

### 最终确认轮

在吸收上述条件项后，再次要求所有参与者只给出 `接受 / 不接受`。

#### 三位 subagent

##### Kepler

- 结论：接受。
- 理由：方案已经明确了日级图与钻取的粒度、缓存、能力回退及失效逻辑，满足 UI 需要的反馈与操作约束。

##### Dirac

- 结论：接受。
- 理由：方案明确了数据粒度、缓存来源与失效规则，同时兼顾 DST / Today 语义，数据架构上可直接落地。

##### Nietzsche

- 结论：接受。
- 理由：方案明确规定了 intraday snapshot 结构、缓存粒度、失效策略和 UI 提示，满足可靠性 / 测试要求，可以按此实现。

#### 外部 CLI

##### Claude Code

- 结论：接受。
- 理由：方案已在日级入口、单日钻取、缓存事实源、能力回退、失效语义与 DST 变长桶数上形成闭环，且无明显冲突。

##### Gemini CLI

- 结论：接受。
- 理由：该修订版共识包详细且全面地定义了单日钻取功能，包括数据、UI 和缓存策略。

##### Codex CLI

- 结论：接受。
- 理由：该修订版已统一日级与单日钻取模型、缓存事实源、能力分层、UI 语义及 DST / 失效边界，约束完整且可实施。

## 最新共识状态（经 agent 复核确认）

1. intraday 方案已不再是 `Today-only + 1h bucket`，而是“日级主图 + 点击某一天进入单日钻取”。
2. 单日钻取默认 `30min`，支持 `15min / 30min / 60min`。
3. `Today` 不再是独立模式，只是日级图中的一天。
4. intraday snapshot 的正式字段至少包括：
   - `dayKey`
   - `timezoneIdentifier`
   - `bucket`
   - `actualBucketCount`
   - `rangeStart`
   - `rangeEnd`
   - `fetchedAt`
5. `dayKey` 的口径固定为 `timezoneIdentifier` 下的本地自然日。
6. `15min` base buckets 是唯一事实缓存；`30/60min` 只做派生展示。
7. capability 口径固定为：
   - `dailyOnly`
   - `dailyWithIntradayDrilldown`
8. UI 必须提供：
   - 不支持 drilldown 时的禁用/原因提示
   - 所选粒度与实际桶数展示
   - 历史日的静态快照/手动刷新语义
9. `Today` 的失效策略固定为：
   - 跨到下一个本地自然日失效
   - 时区变化失效
   - 用户主动刷新时重取
10. 历史日默认静态，仅在手动刷新时更新。
11. DST 场景不允许任何层假设固定桶数。
12. 该版本已经得到 3 个 subagent、`Claude Code`、`Gemini CLI`、`Codex CLI` 的一致接受。

# Provider Usage 单日钻取规格（2026-04-14）

## 背景

当前 `Usage` 页已有日级 `历史 Token 消耗` 趋势图，但缺少对某一天更细粒度消耗的查看能力。

经过 2026-04-14 多轮 debate 与多 agent 复核，最终方案已经收敛为：

1. 主图继续保持日级趋势图。
2. 用户点击某一天后，进入该天的单日钻取。
3. 单日钻取默认 `30min`，可切换 `15min / 30min / 60min`。
4. `Today` 不再是独立模式，只是日级图中的一天。

关联辩论文档：

- `docs-linhay/debate/20260414/codex-usage/20260414-intraday-usage-curve-v01.md`

## 目标

1. 在不破坏现有日级趋势图语义的前提下，提供单日分钟级钻取能力。
2. 保持 Gemini / Codex 在数据模型与聚合口径上的一致性。
3. 用最小复杂度完成 Phase 1 可交付版本，不引入准实时 watcher 或额外事实缓存层。

## 范围

包含：

1. 日级趋势图点选进入单日钻取。
2. 单日钻取 `15min / 30min / 60min` 三档切换。
3. intraday snapshot 独立模型、能力位、刷新与失效规则。
4. Gemini Phase 1 即时聚合。
5. Codex Phase 2 的 `15min` 基准桶设计方向。

不包含：

1. 准实时 watcher / 高频 polling。
2. `Today` 独立模式。
3. 第二排独立 intraday summary 卡片。
4. 跨账号合并单日钻取。
5. Phase 1 的 Gemini 文件级 cache。

## 最终交互

### 主图

1. `历史 Token 消耗` 主图仍然是日级趋势图。
2. `7D / 30D / ALL` 继续存在，语义不变。
3. 未点选具体日期前，不显示分钟级钻取内容。

### 单日钻取

1. 用户点击某一个日级点位后，在同一 section 内以内联展开方式显示该日钻取内容。
2. 钻取默认 bucket 为 `30min`。
3. 用户可切换：
   - `15min`
   - `30min`
   - `60min`
4. 钻取打开后：
   - 主图仍然可见
   - 主图仍允许 range 切换与 hover
   - 但必须锁定当前 `selected day`，不能因主图交互而丢失或改写当前钻取对象

### UI 反馈要求

1. 钻取区必须展示当前粒度与实际桶数，例如 `30min · 48 桶`。
2. 不支持 drilldown 的 provider，必须显式禁用或给出原因提示。
3. 历史日必须展示“静态快照 / 手动刷新”语义。

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

1. `15min` base buckets 是唯一事实缓存。
2. `30min` 与 `60min` 只做派生展示，不再单独保存事实缓存。
3. DST 场景下不允许任何层假设固定桶数：
   - `15min`: `92 / 96 / 100`
   - `30min`: `46 / 48 / 50`
   - `60min`: `23 / 24 / 25`

## Provider 分阶段要求

### Gemini Phase 1

1. 不做文件级 cache。
2. 仅做按选中日即时聚合。
3. 先聚合成 `15min` base buckets，再派生 `30/60min`。

### Codex Phase 2

1. 必须继续走 `scanner / cache / fetcher` 正式链路。
2. cache 基准粒度升级为 `15min` base buckets。
3. 不允许 App 层临时扫某一天的 rollout/session 作为平行数据源。

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
2. Given 单日钻取已打开，When 用户切换到 `15min` 或 `60min`，Then 当前 `selected day` 不变且总量口径与同一份 `15min` base buckets 保持一致。
3. Given 单日钻取已打开，When 用户切换主图 `7D / 30D / ALL`，Then 当前 `selected day` 继续锁定，不得丢失或跳到别的日期。
4. Given provider capability 为 `dailyOnly`，When 用户尝试点选日级点位，Then 不进入钻取并显示禁用或原因提示。
5. Given 历史日钻取已打开，When 页面渲染，Then UI 显示“静态快照 / 手动刷新”语义。
6. Given `timezoneIdentifier` 下该天是 DST 日，When 渲染 `15min / 30min / 60min` 钻取，Then 桶数允许按 `92/96/100`、`46/48/50`、`23/24/25` 变化，不得因固定桶数假设而丢数据。
7. Given 当前选中日期是 Today，When 跨到下一个本地自然日或时区变化，Then 当前钻取结果失效并在下次刷新/重取时更新。
8. Given Gemini Phase 1 已实现，When 用户首次点开某个历史日，Then 系统通过即时聚合得到钻取数据，而不是依赖额外文件级 cache。

## 非目标

1. 本轮不实现 Codex `15min` cache 的完整落地代码。
2. 本轮不处理历史日单日钻取的二级 cache 优化。
3. 本轮不改变现有 summary 卡片语义。

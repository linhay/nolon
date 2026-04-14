# Provider Usage 单日钻取执行前准备（2026-04-14）

## 会议总结

2026-04-14 围绕 `Usage` 页“日内使用曲线”做了多轮 debate、subagent 复核，以及 `Claude Code` / `Gemini CLI` / `Codex CLI` 外部评审。

最终已经关闭全部歧义，正式结论为：

1. 主图保持日级趋势图，不新增独立 `Today` 模式。
2. 点击某一天后，在同一 section 内以内联展开方式进入单日钻取。
3. 单日钻取默认 `30min`，支持 `15min / 30min / 60min`。
4. 钻取态下主图仍允许 range/hover，但必须锁定 `selected day`。
5. `15min` base buckets 是唯一事实缓存，`30/60min` 只做派生展示。
6. Gemini Phase 1 不做文件级 cache，只做按选中日即时聚合。

主结论来源：

- `docs-linhay/debate/20260414/codex-usage/20260414-intraday-usage-curve-v01.md`

## 开始执行前的固定前提

1. 以 `docs-linhay/features/provider-usage-intraday-drilldown-2026-04-14.md` 作为最新需求规格。
2. 以本文件作为执行顺序、文件落点、测试门禁与风险控制清单。
3. 代码实现阶段必须遵守：
   - 先补测试，再做最小实现
   - 每完成一个阶段就定向验证
   - 文档与 memory 同步更新

## 目标

1. 为现有 `历史 Token 消耗` section 增加单日钻取能力。
2. 先完成 Phase 1 的 UI 骨架、通用模型与 Gemini 数据接入。
3. 保证现有日级趋势行为不回归。

## 分阶段执行

### Phase 0：规格与 UI/模型骨架

目标：

1. 先让结构和状态模型成立。
2. 不急着接入真实 provider 数据。

执行项：

1. 新增单日钻取 presentation mode / section state。
2. 新增 intraday snapshot 展示模型。
3. 改造 `历史 Token 消耗` section，支持：
   - 主图日级趋势
   - 点选某天后内联展开钻取
   - bucket 切换 `15/30/60min`
4. 先用静态 preview / fixture 跑通 UI。

完成标志：

1. 日级图与钻取区可以共存。
2. bucket 切换行为与 `selected day` 锁定逻辑已具备。

### Phase 1：Gemini 单日钻取

目标：

1. 用最小复杂度交付第一个可工作的 provider。

执行项：

1. 新增 Gemini intraday service。
2. 实现“按选中日即时聚合”为 `15min` base buckets。
3. 从 `15min` 派生 `30/60min`。
4. 接入 `ProviderUsageEngine`。
5. 补 Gemini service / engine / section 的测试。

完成标志：

1. Gemini 日级图点击后可展开历史日/Today 单日钻取。
2. 不依赖新增文件级 cache。

### Phase 2：Codex 单日钻取

目标：

1. 在不破坏现有正式链路的前提下，为 Codex 提供同样的钻取能力。

执行项：

1. 把 Codex cache 基准从“小时桶设想”升级成 `15min` base buckets 设计。
2. 扩 `scanner / cache / fetcher`。
3. 保证 `15min` 是唯一事实缓存。
4. 补 scanner / fetcher 一致性测试。

完成标志：

1. Codex 单日钻取走正式链路。
2. 不存在 App 层临时扫单日文件的平行数据源。

## 推荐代码落点

### App / ViewModel / Engine

1. `nolon/Skills/Domain/Providers/Usage/Engine/ProviderUsageEngine.swift`
2. `nolon/Skills/Domain/Providers/Usage/Root/ProviderUsageRootViewModel.swift`
3. `nolon/Skills/Domain/Providers/Usage/Views/Common/ProviderUsageView.swift`

### 通用 usage 域模型

1. `libs/Providers/Sources/ProviderUsage/Models.swift`
2. `libs/Providers/Sources/ProviderUsage/ProviderUsageRegistry.swift`
3. `libs/Providers/Sources/ProviderUsage/ProviderUsageMonitor.swift`

### Gemini

1. `libs/Providers/Sources/ProviderUsage/GeminiTokenTrendService.swift`
2. 新增 `GeminiIntradayUsageService` 或等价文件

### Codex

1. `libs/Providers/Sources/ProviderUsage/CodexTokenTrendService.swift`
2. `libs/Providers/Sources/Providers/Codex/CostUsage/Vendored/CostUsageScanner.swift`
3. `libs/Providers/Sources/Providers/Codex/CostUsage/Vendored/CostUsageScanner+Timestamp.swift`
4. `libs/Providers/Sources/Providers/Codex/CodexSessionEventParser.swift`

## BDD / TDD 门禁

开始实现前，至少先补以下失败测试：

1. `Given daily chart when tap a day then section expands intraday drilldown with default 30min`
2. `Given drilldown opened when switch 15min/30min/60min then selected day remains stable`
3. `Given drilldown opened when switch daily range then selected day remains locked`
4. `Given provider capability is dailyOnly when tap a day then drilldown does not open`
5. `Given timezone DST day when derive 15/30/60 buckets then actual bucket count is variable but totals remain consistent`
6. `Given selected day is today when day rollover or timezone change happens then intraday snapshot invalidates`
7. `Given Gemini Phase 1 when open historical drilldown then service aggregates on demand without file cache`

## 验证清单

### UI / 状态

1. 主图不回归。
2. 单日钻取默认为 `30min`。
3. `selected day` 在钻取期间稳定。
4. UI 显示实际桶数。
5. 历史日显示“静态快照 / 手动刷新”语义。

### 数据口径

1. `dayKey` 始终是 `timezoneIdentifier` 下的本地自然日。
2. `15min` 是唯一事实缓存。
3. `30/60min` 总量与 `15min` 聚合一致。
4. DST 日桶数不被写死。

### 回归

1. 现有日级 `7D / 30D / ALL` 行为不变。
2. 不支持 intraday 的 provider 不误开入口。
3. Gemini 与 Codex 不出现两套并行 intraday 数据链路。

## 风险与防线

### 风险 1：主图与钻取同时存在时状态串线

防线：

1. 在 engine/state 层显式建模 `selected day`。
2. range 切换不得改写 `selected day`。

### 风险 2：DST / 时区变化导致口径错误

防线：

1. snapshot 强制携带 `timezoneIdentifier`。
2. 测试中覆盖 `92/96/100`、`46/48/50`、`23/24/25` 桶数。

### 风险 3：Gemini Phase 1 即时聚合性能不足

防线：

1. 第一版先交付正确性。
2. 若出现明显性能问题，再单独立项讨论历史日轻量 cache，不在本轮预埋复杂度。

## 非目标

1. 本文档不直接作为技术实现说明书替代代码设计。
2. 本轮不实现 Codex 完整 `15min` cache 代码。
3. 本轮不引入新的 debate 议题，除非执行中发现和本文件冲突的事实问题。

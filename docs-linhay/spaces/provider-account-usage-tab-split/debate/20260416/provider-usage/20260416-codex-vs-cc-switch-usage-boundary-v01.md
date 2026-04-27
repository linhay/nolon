# codex-vs-cc-switch-usage-boundary

**日期**：20260416
**模式**：合作型
**参与者**：Sagan（时间边界侦探） / Anscombe（token-cost 口径侦探） / Codex（主持）
**总轮次**：1 / 60
**结束原因**：第 1 轮达成主持裁定级共识

## 辩论背景

用户要求把当前 `nolon` 的 `codex` 用量实现，与参考项目 `cc-switch` 做代码级对比，重点确认：

1. 双方在“今日 / 日级统计”的时间边界和时区上是否有差异。
2. 双方在 `totalTokens`、`cached`、`cost` 的口径上是否有差异。
3. 上述差异是否足以解释“上游只有本地一半”。

## 各轮观点记录

### 第 1 轮

**[Sagan - 时间边界]**

- 代码事实：`nolon` 的 `trailingDays` 先按 `Calendar.current.date(byAdding: .day, value: -(trailingDays - 1), to: now)` 生成窗口，再转成 `yyyy-MM-dd` 的本地日键。  
  引用：[CostUsageFetcher.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CostUsage/CostUsageFetcher.swift#L38), [CostUsageScanner.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CostUsage/Vendored/CostUsageScanner.swift#L77)
- 代码事实：`nolon` 在事件落桶时用 `Calendar.current` 提取本地年月日；`todayTokens` 也显式使用 `TimeZone.current`。  
  引用：[CostUsageScanner+Timestamp.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CostUsage/Vendored/CostUsageScanner+Timestamp.swift#L100), [CodexTokenTrendService.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/ProviderUsage/CodexTokenTrendService.swift#L100)
- 代码事实：`cc-switch` 的 rollup 过滤、今日/月度统计都使用 SQLite `localtime`，例如 `date(?, 'unixepoch', 'localtime')`、`date(datetime(created_at, 'unixepoch', 'localtime')) = date('now', 'localtime')`。  
  引用：[usage_stats.rs](/Users/linhey/Desktop/FlowUp-Libs/nolon/docs-linhay/references/cc-switch/src-tauri/src/services/usage_stats.rs#L150), [usage_stats.rs](/Users/linhey/Desktop/FlowUp-Libs/nolon/docs-linhay/references/cc-switch/src-tauri/src/services/usage_stats.rs#L321), [usage_stats.rs](/Users/linhey/Desktop/FlowUp-Libs/nolon/docs-linhay/references/cc-switch/src-tauri/src/services/usage_stats.rs#L758)
- 代码事实：`cc-switch` 前端窗口是 `Date.now() - days * 86400` 到 `Date.now()` 的秒级滑动区间；后端对 `<=24h` 用小时桶，对 `>24h` 才切成天桶。  
  引用：[usage.ts](/Users/linhey/Desktop/FlowUp-Libs/nolon/docs-linhay/references/cc-switch/src/lib/query/usage.ts#L63), [usage_stats.rs](/Users/linhey/Desktop/FlowUp-Libs/nolon/docs-linhay/references/cc-switch/src-tauri/src/services/usage_stats.rs#L235)
- 结论：双方都按本地时区切日，没有“一个本地时区、一个 UTC”的直接差异；最大已确认差异只是 `nolon` 更偏“本地自然日 inclusive”，`cc-switch` 更偏“秒级滑动窗口”。这类边界差不足以稳定解释“上游只有本地一半”。

**[Anscombe - token / cost 口径]**

- 代码事实：`nolon` 的日汇总 `dayTotal = dayInput + dayOutput`，`cached` 只单列存入 `cacheReadTokens`。  
  引用：[CostUsageScanner.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CostUsage/Vendored/CostUsageScanner.swift#L438), [CostUsageScanner.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CostUsage/Vendored/CostUsageScanner.swift#L457)
- 代码事实：`nolon` parser 会同时保留 `inputTokens` 与 `cachedInputTokens`，但不会在 token 汇总阶段把 `cached` 再额外叠加进 `totalTokens`。  
  引用：[CodexSessionEventParser.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionEventParser.swift#L162), [CodexSessionEventParserTests.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Tests/ProvidersTests/CodexTests/CodexSessionEventParserTests.swift#L114)
- 代码事实：`cc-switch` 的 summary / trends / request detail 也都把 `totalTokens` 定义成 `input + output`，缓存读写单独展示。  
  引用：[usage_stats.rs](/Users/linhey/Desktop/FlowUp-Libs/nolon/docs-linhay/references/cc-switch/src-tauri/src/services/usage_stats.rs#L177), [usage_stats.rs](/Users/linhey/Desktop/FlowUp-Libs/nolon/docs-linhay/references/cc-switch/src-tauri/src/services/usage_stats.rs#L268), [UsageSummaryCards.tsx](/Users/linhey/Desktop/FlowUp-Libs/nolon/docs-linhay/references/cc-switch/src/components/usage/UsageSummaryCards.tsx#L53), [RequestDetailPanel.tsx](/Users/linhey/Desktop/FlowUp-Libs/nolon/docs-linhay/references/cc-switch/src/components/usage/RequestDetailPanel.tsx#L165)
- 代码事实：`cc-switch` 的成本计算会先从 `input_tokens` 中扣掉 `cache_read_tokens`，再分别计算普通输入、缓存读取、缓存写入、输出的成本。  
  引用：[usage_stats.rs](/Users/linhey/Desktop/FlowUp-Libs/nolon/docs-linhay/references/cc-switch/src-tauri/src/services/usage_stats.rs#L861), [PricingConfigPanel.tsx](/Users/linhey/Desktop/FlowUp-Libs/nolon/docs-linhay/references/cc-switch/src/components/usage/PricingConfigPanel.tsx#L367)
- 主持补证：`nolon` 的 `CostUsagePricing.codexCostUSD(...)` 也明确把 `cached` 单独折价计费：`nonCached * inputPrice + cached * cacheReadPrice + output * outputPrice`。  
  引用：[CostUsagePricing.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CostUsage/Vendored/CostUsagePricing.swift#L46)
- 结论：如果拿 `cc-switch` 参考实现对比，双方在 `totalTokens` 口径一致，`cached` 成本折价方向也一致，不存在“`cc-switch` 把 cached 排除而 `nolon` 把 cached 算进 total / cost`”的直接证据。

**[Codex - 主持补证]**

- 代码事实：`cc-switch` 这套 usage 统计的事实源是 `proxy_request_logs` 与 `usage_daily_rollups`，并非本地 `codex sessions/*.jsonl` 扫描。  
  引用：[usage_stats.rs](/Users/linhey/Desktop/FlowUp-Libs/nolon/docs-linhay/references/cc-switch/src-tauri/src/services/usage_stats.rs#L182), [usage_rollup.rs](/Users/linhey/Desktop/FlowUp-Libs/nolon/docs-linhay/references/cc-switch/src-tauri/src/database/dao/usage_rollup.rs#L3)
- 结论：`cc-switch` 更适合拿来对比“时间窗口/聚合口径/成本公式”，不适合直接当作 `codex sessions` 本地扫描实现的一一映射。

## 最终结论与行动项

### 达成共识 / 裁定结论

1. **时间不是主因**  
   `nolon` 与 `cc-switch` 都按本地时区切日。最大已确认差异只是“自然日窗口”对“秒级滑动窗口”，只能造成边界偏差，不能稳定解释“上游只有本地一半”。

2. **`totalTokens` 口径一致**  
   两边都把 `totalTokens` 定义成 `input + output`，缓存读写只单列展示，不会再额外叠加到总量里。

3. **`cached` 成本折价方向一致**  
   `cc-switch` 与 `nolon` 都明确对 cached input 做单独折价计费，不存在从参考实现上看出“我们把 cached 按 1x 算、cc-switch 按折价算”的证据。

4. **如果仍有巨大差异，优先怀疑数据源或 scope，而不是时间**  
   继续排查应优先看：
   - 本地 `codex sessions` 事实源是否和用户对比的“上游”是同一批请求
   - 是否存在 `global ~/.codex` 与账号隔离 scope 混算
   - 是否有重复 session / sidecar / fallback 路径把不该算的文件算进来了

### 行动项

| # | 行动 | 负责方 | 截止 |
|---|------|--------|------|
| 1 | 继续核对 `global ~/.codex` 与账号 scope 是否混算 | Codex | 本轮后续 |
| 2 | 对今天真实 sessions 做去重/来源维度审计，找是否有重复来源 | Codex | 本轮后续 |
| 3 | 在 UI 或调试信息里显式展示 source/scope/timezone，避免误解 | 待定 | 后续开发 |

### 未解问题

- 用户当前对比的“上游”到底是官方 raw token、credits、还是某个 provider 面板里的折价后 usage。
- 当前 `nolon` 的 `global` 聚合是否把不应算入当前比较对象的 session 文件也算进去了。

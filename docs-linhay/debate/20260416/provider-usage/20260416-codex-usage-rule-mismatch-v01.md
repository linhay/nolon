# Codex 今日用量与上游统计不一致 debate（2026-04-16）

## 背景

- 现象：用户观察到本地 `codex` Usage 页里的“今日用量”与上游统计不一致。
- 目标：确认差异来自规则口径还是实现 bug，并给出后续修正方向。
- 方法：按合作型 debate 的证据规则执行，只接受“代码引用 + 官方文档引用”的结论。

## 参与者

- 主持：Codex
- 证据源 A：本地代码审计
- 证据源 B：OpenAI 官方文档

## Round 1

### 论点 1：当前 Codex Usage 页的数据源不是上游官方 usage API，而是本地 session 日志扫描

- 引用：
  - `libs/Providers/Sources/ProviderUsage/CodexTokenTrendService.swift:26`
  - `libs/Providers/Sources/Providers/Codex/CostUsage/CostUsageFetcher.swift:48`
- 代码事实：
  - `CodexTokenTrendService.fetchGlobalSnapshot(...)` 内部直接调用 `CostUsageFetcher.loadTokenSnapshot(...)`。
  - `CostUsageFetcher` 通过 `codexHome.folder("sessions")` 读取本地 `sessions` 目录聚合 daily snapshot。
- 结论：
  - 本地 Usage 页的 token trend 事实源是本地 `jsonl` session 日志，不是 OpenAI 官方 Usage Dashboard / Usage API 的服务端统计。

### 论点 2：当前 Codex Usage 页是“global scope”，不是“当前账号 scope”

- 引用：
  - `libs/Providers/Sources/ProviderUsage/CodexTokenTrendService.swift:30`
  - `libs/Providers/Sources/ProviderUsage/CodexTokenTrendService.swift:75`
  - `libs/Providers/Sources/ProviderUsage/CodexIntradayUsageService.swift:69`
  - `docs-linhay/dev/nolon-codex-cli-dx-phase2.md:1117`
- 代码事实：
  - token trend 与 intraday 两条链路都会先 `removeValue(forKey: "CODEX_HOME")`。
  - `CodexTokenTrendService` 返回的 `sourceLabel` 也被硬编码为 `"global"`。
  - 文档里“按账号 `CODEX_HOME` 隔离 + 无会话回退全局”的设计，是 `CostUsageFetcher` / `auth usage` 能力层的规则；但 Usage tab 当前走的是 `fetchGlobalSnapshot`，没有保留账号级 scope。
- 结论：
  - 如果用户对比的是“某个 Codex 账号”在上游的统计，而本地 Usage 页展示的是 `~/.codex/sessions` 的全局本地聚合，两边天然可能不一致。

### 论点 3：当前“今日”按本地时区切天，而 OpenAI Usage Dashboard 明确使用 UTC

- 引用：
  - `libs/Providers/Sources/Providers/Codex/CostUsage/Vendored/CostUsageScanner+Timestamp.swift:101`
  - `libs/Providers/Sources/ProviderUsage/CodexTokenTrendService.swift:104`
  - `https://help.openai.com/en/articles/10478918-api-usage-dashboard`
- 代码事实：
  - `dayKeyFromTimestamp(...)` 在把事件时间解析成 `Date` 后，再用 `Calendar.current` 取本地年月日。
  - `CodexTokenTrendService.dayKey(from:)` 也显式使用 `TimeZone.current`。
- 官方事实：
  - OpenAI Help Center 的 `API Usage Dashboard` 写明：`Data in the usage dashboard are displayed using UTC.`
- 结论：
  - 当用户本地时区不是 UTC 时，特别是本地凌晨到 UTC 换日窗口附近，本地“今日”和上游“今日”会天然错位。

### 论点 4：`cached` 不是额外叠加到 total 之外的一栏；它属于 input 的明细

- 引用：
  - `libs/Providers/Sources/Providers/Codex/CodexSessionEventParser.swift:162`
  - `libs/Providers/Sources/Providers/Codex/CostUsage/Vendored/CostUsageScanner.swift:457`
  - `libs/Providers/Tests/ProvidersTests/CodexTests/CodexSessionEventParserTests.swift:114`
  - `https://platform.openai.com/docs/guides/prompt-caching`
  - `https://openai.com/index/api-prompt-caching/`
- 代码事实：
  - 本地 daily 汇总的 `dayTotal = dayInput + dayOutput`。
  - 测试样例里 `input_tokens=100, cached_input_tokens=80, output_tokens=30, total_tokens=130`，说明 `cached_input_tokens` 不是再额外加到 total 上，否则应为 `210` 而不是 `130`。
- 官方事实：
  - OpenAI Prompt Caching 文档把 `cached_tokens` 放在 `usage.prompt_tokens_details` / `usage` 的明细里，示例 `total_tokens = prompt_tokens + completion_tokens`，缓存命中是 prompt/input 内部明细，不是 total 之外再加一栏。
- 结论：
  - 当前 `codex` 本地实现并不存在“因为没把 cached 额外加进 total，导致 today 偏小”的规则错误。

### 论点 5：当前 today 卡片取的是“当日本地日桶 total”，不是额外一套 live session 指标

- 引用：
  - `libs/Providers/Sources/Providers/Codex/CostUsage/CostUsageFetcher.swift:118`
  - `libs/Providers/Sources/ProviderUsage/CodexTokenTrendService.swift:91`
- 代码事实：
  - `CostUsageFetcher.tokenSnapshot(...)` 会先从 `daily.data` 中筛出与 `now` 同一本地自然日的 entry，记为 `currentDay`。
  - `sessionTokens = currentDay?.totalTokens`。
  - `CodexTokenTrendService.todayTokens(...)` 优先返回 `sessionTokens`，也就是当日本地日桶 total。
- 结论：
  - 当前 today 卡片的语义并不是“当前活跃会话 token”，而是“本地日切下的今天累计 total”。

## 结论

### 已排除

1. `cached_input_tokens` 被遗漏，导致 today total 算少。
2. today 卡片取了另一套 live 指标，和日图 today bucket 不同。

### 新增证据：本地 raw token 与“按 cached 折价后的有效用量”差距，量级上可直接解释“上游只有一半”

- 引用：
  - `libs/Providers/Sources/Providers/Codex/CostUsage/Vendored/CostUsageScanner.swift:457`
  - `https://developers.openai.com/api/docs/models/gpt-5-codex`
  - `https://openai.com/index/api-prompt-caching/`
- 代码事实：
  - 本地日级 total 固定是 `input + output`，没有对 cached input 做任何折价。
- 官方事实：
  - OpenAI 官方文档明确 cached input 单独计量，且价格低于普通 input。
  - `GPT-5-Codex` 当前官方价格页显示：`Input $1.25 / 1M`，`Cached input $0.125 / 1M`，`Output $10 / 1M`。
  - Prompt Caching 官方说明也明确：cached prompt 会享受折扣，不应与 uncached input 按同一权重理解。
- 本机 2026-04-16 实测：
  - 扫描 `~/.codex/sessions/2026/04/16/*.jsonl` 共 `40` 个文件。
  - 按当前本地 raw 口径汇总：`455,321,165`。
  - 若只把 cached input 按 `50%` 权重折算：`248,928,077`，约为 raw 的 `54.7%`。
  - 若按更低 cached 权重折算：`145,731,533`，约为 raw 的 `32.0%`。
  - 多个大 session 的 cached 占 raw 比例超过 `90%`，例如：
    - `rollout-2026-04-16T10-50-07-019d9432-2675-7162-9f94-0f931b94803e.jsonl`
    - `rollout-2026-04-16T01-32-10-019d9233-5358-76c0-b9d1-a11a43bc6f97.jsonl`
    - `rollout-2026-04-16T02-26-03-019d9264-a949-7c92-bd58-90785caf7661.jsonl`
- 结论：
  - 如果上游展示的是“折价后的有效用量 / 计费用量 / credits 消耗”，而本地展示的是“raw total tokens”，那“上游约等于本地一半”是完全可能的，而且和你今天的真实数据非常接近。

### 当前最可能的真实原因

1. **cached input 权重不一致**
   - 本地：`raw total = input + output`
   - 上游：很可能不是 raw total，而是对 cached input 做了折价后的有效用量
2. **scope 不一致**
   - 本地 Usage 页当前是 `global ~/.codex/sessions` 口径。
   - 上游 Usage Dashboard / Usage API 通常带有组织、项目、账号或过滤器口径。
3. **时区不一致**
   - 本地按 `TimeZone.current` 切天。
   - OpenAI Usage Dashboard 明确按 UTC 展示。
4. **事实源不一致**
   - 本地扫的是已落盘的 session `jsonl`。
   - 上游看的是服务端 usage 聚合。

### 当前实现层面的明确缺口

1. Usage tab 没有保留账号级 `CODEX_HOME` 作用域。
2. UI 只暴露 `"global"`，没有把 `scopedSessions / globalFallback` 这类更精确来源传上来。
3. UI 没有提示“今日”的时区口径。

## 后续行动项

1. 明确产品定义：
   - Codex Usage tab 到底要展示“本地 raw tokens”，还是“更接近上游的有效用量 / 折价用量”。
2. 若要和上游对齐：
   - 优先改成账号级环境注入，不要在 Usage tab 默认剥离 `CODEX_HOME`。
   - 明确是否切到 UTC 日界线。
   - 为 cached input 引入可配置权重，至少支持 raw / weighted 两套口径。
   - 需要时接入已存在的 HTTP usage query 配置链路，直接走上游接口。
3. 无论是否改事实源：
   - 都应把 `sourceLabel` 与 timezone 口径显式展示出来，避免用户误以为它和上游统计是同一口径。

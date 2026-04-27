# Claude Usage Rule Mismatch

**日期**：20260416
**模式**：合作型
**参与者**：Gemini（规则口径）/ Copilot（实现偏差）/ Codex（主持）
**总轮次**：2 / 60
**结束原因**：已形成可操作共识

## 辩论背景
> 用户反馈：Claude “今日用量”与上游统计不一致，需要查清当前产品的用量规则，以及是“预期口径差异”还是“实现 bug”。

## 各轮观点记录

### 第 1 轮
**[Gemini - 规则口径]**
- 论点：当前产品统计的不是官方上游 usage 口径，而是“本地 Claude session 日志聚合”。
  → 引用：`docs-linhay/spaces/provider-account-usage-tab-split/README.md:35`
  → 代码事实：需求明确写的是“不走 web usage API”，而是扫描本地 Claude session 日志。
  → 结论：只要用户把“本地日志聚合”与“上游组织级/API 统计”直接对比，就会天然不一致。
- 论点：当前“今日”按本地时区切日，而上游官方 daily usage/analytics 示例按 UTC 日界线。
  → 引用：`libs/Providers/Sources/ProviderUsage/ClaudeTokenTrendService.swift:57-60`
  → 引用：`libs/Providers/Sources/ProviderUsage/ClaudeTokenTrendService.swift:141-147`
  → 代码事实：`timezone` 默认 `TimeZone.current`，`todayTokens` 用本地 todayKey 取值。
  → 结论：跨 UTC 零点时，本地“今日”和上游“今日”必然偏移。
- 论点：当前只解析 `type == "assistant"` 的消息行，而官方监控口径是“每次 API request”。
  → 引用：`libs/Providers/Sources/ProviderUsage/ClaudeSessionUsageSupport.swift:207-236`
  → 代码事实：本地只读取 assistant 消息里的 `message.usage`。
  → 结论：如果上游统计覆盖了更多 request 维度，本地会漏算一部分。

**[Copilot - 实现偏差]**
- 论点：当前 dedupeKey 把 `isSidechain` 放进 key，会让同一请求在 parent / subagent 两份日志里被算两次。
  → 引用：`libs/Providers/Sources/ProviderUsage/ClaudeSessionUsageSupport.swift:240-248`
  → 代码事实：dedupeKey = `sessionId|messageId|requestId|isSidechain`。
  → 结论：同一 `sessionId/messageId/requestId` 若分别以 `sidechain/primary` 形式出现，会生成两个不同 key。
- 论点：当前实现会递归扫描 `projects` 目录下所有 `.jsonl`，但没有做“跨文件 canonical 去重”。
  → 引用：`libs/Providers/Sources/ProviderUsage/ClaudeSessionUsageSupport.swift:103-123`
  → 引用：`libs/Providers/Sources/ProviderUsage/ClaudeSessionUsageSupport.swift:181-204`
  → 代码事实：所有文件 events 合并后仅依赖当前 dedupeKey 去重。
  → 结论：如果 parent log 和 subagent log 都带同一请求，就会双计。
- 论点：参考实现已经处理了这个问题。
  → 引用：`docs-linhay/references/CodexBar/Sources/CodexBarCore/Vendored/CostUsage/CostUsageScanner+Claude.swift:182-267`
  → 代码事实：参考实现 canonical key 不含 `isSidechain`，并在 parent/subagent 冲突时只保留一个 winner。
  → 结论：当前 Nolon Claude 聚合逻辑相较参考实现缺了一层关键去重。

### 第 2 轮
**[Gemini - 交叉质疑结论]**
- 论点：`isSidechain` 进入 dedupeKey 导致跨文件双计的判断成立。
  → 引用：`libs/Providers/Sources/ProviderUsage/ClaudeSessionUsageSupport.swift:240-248`
  → 引用：`libs/Providers/Sources/ProviderUsage/ClaudeSessionUsageSupport.swift:103-123`
  → 引用：`docs-linhay/references/CodexBar/Sources/CodexBarCore/Vendored/CostUsage/CostUsageScanner+Claude.swift:182-195`
  → 代码事实：当前 key 比参考实现多了 `isSidechain`，且当前没有跨文件 canonical 合并。
  → 结论：这会让本地统计偏大。

## 最终结论与行动项

### 达成共识 / 裁定结论
- 结论 1：当前 Claude “今日用量”与上游统计不一致，首先是**预期口径差异**，不是单纯 UI 算错。
  - 本地统计源：扫描本机 Claude session `.jsonl`。
  - 上游统计源：官方组织级 Usage / Analytics / OpenTelemetry request 口径。
- 结论 2：当前“今日”按**本地时区**切日，而官方 daily usage / analytics 示例按 **UTC** 日界线返回，这会造成跨日偏差。
- 结论 3：当前实现里存在一个会把本地统计**抬高**的真实 bug：
  - `dedupeKey` 把 `isSidechain` 纳入 key，导致 parent/subagent 对同一请求无法合并。
- 结论 4：当前实现还可能存在让本地统计**偏低**的结构性差异：
  - 只统计 `assistant` 消息里的 `message.usage`，而不是完整 API request 事件。
- 结论 5：`cache_creation_input_tokens` 被并入 input 展示是设计选择，不影响当前 `total = input + cacheCreation + cacheRead + output` 的总量，但会影响 input 分项与上游字段逐列对比。

### 确认的代码事实
| # | 事实 | 来源 |
|---|------|------|
| 1 | Claude Usage 页明确不走 web usage API，而是扫描本地 session 日志 | `docs-linhay/spaces/provider-account-usage-tab-split/README.md:35` |
| 2 | `todayTokens` 按 `TimeZone.current` 对应的 todayKey 取值 | `libs/Providers/Sources/ProviderUsage/ClaudeTokenTrendService.swift:57-60`, `:141-147` |
| 3 | 本地只解析 `type == "assistant"` 的 usage 行 | `libs/Providers/Sources/ProviderUsage/ClaudeSessionUsageSupport.swift:207-236` |
| 4 | 本地总量公式是 `input + cacheCreation + cacheRead + output` | `libs/Providers/Sources/ProviderUsage/ClaudeSessionUsageSupport.swift:228-236` |
| 5 | 当前 dedupeKey 包含 `isSidechain` | `libs/Providers/Sources/ProviderUsage/ClaudeSessionUsageSupport.swift:240-248` |
| 6 | 当前扫描会递归读取 `projects` 目录下全部 `.jsonl` | `libs/Providers/Sources/ProviderUsage/ClaudeSessionUsageSupport.swift:103-123` |
| 7 | 参考实现 canonical key 不含 `isSidechain`，并在跨文件冲突时选单个 winner | `docs-linhay/references/CodexBar/Sources/CodexBarCore/Vendored/CostUsage/CostUsageScanner+Claude.swift:182-267` |

### 行动项
| # | 行动 | 负责方 | 截止 |
|---|------|--------|------|
| 1 | 修复 Claude 去重：改成 canonical key = `sessionId + messageId + requestId`，不要把 `isSidechain` 放进 key；必要时补 parent/subagent winner 规则 | Codex | 下一轮开发 |
| 2 | 增加覆盖 parent/subagent 双份日志的回归测试，证明不会双计 | Codex | 下一轮开发 |
| 3 | 明确产品口径：当前页面展示“本机 Claude session usage”还是“对齐上游 UTC daily usage” | 用户 / 产品 | 待确认 |
| 4 | 若要求对齐上游“今日”，统一日界线到 UTC，或在 UI 显式标注“本地时区 / 本机日志口径” | Codex | 待产品确认 |
| 5 | 若要求尽量逼近上游 request 统计，评估是否接入官方 Usage / Analytics API 或 OTel 事件，而不是仅靠 assistant message | Codex / 产品 | 待方案确认 |

### 未解问题
- 真实用户本地的 Claude session 样本里，parent/subagent 重复率有多高。
- 用户对比的“上游统计”具体是哪个面板/API：Claude Console、Analytics API、Usage API、还是 OTel。
- 产品是否要追求“可离线、本机真实会话视角”，还是追求“官方组织级统计对齐”。

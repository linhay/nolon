# codex-auth-identity-takeover

**日期**：20260428
**模式**：合作型
**参与者**：Gemini（策略审计） / Claude（首轮淘汰） / Copilot（实现反例审计）
**总轮次**：2 / 60
**结束原因**：关键分歧已通过代码证据收敛，继续加轮收益低

## 执行元数据
- 候选参与者：Gemini / Claude / Copilot
- 首轮实际启用：Gemini / Claude
- 后续 active participants：Gemini / Copilot
- 淘汰参与者：Claude
- 不可用原因：
  - Claude：首轮直接失败，报错“selected model may not exist or you may not have access”
  - Copilot：首轮长 prompt 超时，第二次短 prompt 成功补位

## 辩论背景
> 讨论主题是 Codex 在外部程序修改 provider `auth.json` 后的托管边界。当前代码刚落成一条新规则：如果外部 payload 能形成稳定唯一身份，则继续托管并切到对应账号；如果身份不足或歧义，则退选、撤回托管 relay 配置、保留外部 `auth.json` 并暂停接管。用户要求进一步深入研讨这条边界还有什么风险和补充点。

## 各轮观点记录

### 第 1 轮
**[Gemini - 策略审计]**
- 论点：当前策略整体偏防御，核心边界清晰。  
  引用：`libs/Providers/Sources/ProviderUsage/CodexAuthManager+ProviderSync.swift:529-551`  
  代码事实：`usage_load/background_poll` 下，如果 `hasStableCredentialIdentity(authData:)` 为假，就执行 `clearActiveSelectionAndRestoreProviderState(... preserveProviderAuthFile: true, pauseMonitoring: true)`。  
  结论：代码确实保证了“看不懂就退让，不强改用户文件”。
- 论点：稳定身份的定义极窄。  
  引用：`libs/Providers/Sources/ProviderUsage/CodexAuthManager.swift:1652-1701`  
  代码事实：当前只有 `api_key+base_url`、`api_key`、`email+account_id` 三类组合是 `.valid`。  
  结论：身份判断保守，能降低误接管，但也意味着外部工具只要丢掉 `email` 等字段，托管会被立刻放弃。
- 论点：Gemini 额外提出一个“未知但稳定的新身份”体验风险。  
  引用：`libs/Providers/Sources/ProviderUsage/CodexAuthManager+ProviderSync.swift:499-539`  
  代码事实：稳定身份时会 `relinkProviderAuth(... resolved: driftResolvedAccount)` 并继续托管。  
  结论：推断存在“外部切到全新账号时，UI 是否足够可见”的产品侧补充点。

**[Claude - 首轮淘汰]**
- 无有效论点。  
  原因：模型不可用，未返回可用技术内容。

### 第 2 轮
**[Copilot - 实现反例审计]**
- 论点：`paused` 后 `background_poll` 存在单向门风险。  
  引用：`libs/Providers/Sources/ProviderUsage/CodexAuthManager+ProviderSync.swift:817-849`，`libs/Providers/Sources/ProviderUsage/CodexAuthManager.swift:1298-1300`  
  代码事实：`pollProviderAuthChange` 先更新 `providerAuthLastHashes`，再进 `preflightManagedAuthIfNeeded`；而 `preflight` 在 `paused + background_poll` 时直接 `return nil`。  
  结论：如果之后文件内容不再变化，就不会再自动触发恢复，`paused` 对轮询来说是单向门。
- 论点：`api_key` 被视为稳定身份，但漂移修复中的严格匹配不使用它。  
  引用：`libs/Providers/Sources/ProviderUsage/CodexAuthManager.swift:1692-1696`，`libs/Providers/Sources/ProviderUsage/CodexAuthManager+SnapshotHelpers.swift:145-170`，`libs/Providers/Sources/ProviderUsage/CodexAuthManager+ProviderSync.swift:499-526`  
  代码事实：`api_key` 属于 `.valid`；但 `matchAccountByStrictIdentity` 先 `guard let authAccountID`，纯 API key 身份会直接失败，然后 drift 路径落入 `upsertSnapshotFromProviderData`。  
  结论：同一 API key 账号的外部漂移存在重复 snapshot 的风险。

**[Gemini - 交叉复核]**
- 论点：Copilot 指出的 `paused` 单向门成立。  
  引用：`libs/Providers/Sources/ProviderUsage/CodexAuthManager+ProviderSync.swift:827-845`，`libs/Providers/Sources/ProviderUsage/CodexAuthManager.swift:1298-1300`  
  代码事实：hash 会先被消耗，而自动恢复逻辑只在 `reconcileActiveSymlinkDriftIfNeeded` 内部；`preflight` 提前返回后，恢复路径不会执行。  
  结论：这不是产品权衡，而是实现层面的真实缺口。
- 论点：Copilot 指出的 `api_key` snapshot 膨胀风险也成立。  
  引用：`libs/Providers/Sources/ProviderUsage/CodexAuthManager+SnapshotHelpers.swift:145-170, 291-326`，`libs/Providers/Sources/ProviderUsage/CodexAuthManager+ProviderSync.swift:499-539`  
  代码事实：strict identity 不认纯 API key；而 drift repair 先看 strict match，再 upsert。  
  结论：当前“稳定身份”与“drift repair 匹配规则”不完全一致，API key 这条线还存在重复快照风险。

## 最终结论与行动项

### 达成共识 / 裁定结论
- 当前“稳定身份继续托管，不稳定身份退选暂停”的总方向是对的。  
  引用：`CodexAuthManager+ProviderSync.swift:529-551`  
  代码事实：被动场景明确分成继续托管与保留外部文件两条路径。  
  结论：总体治理方向成立。
- 但“稳定身份”的定义与实际 drift repair 匹配规则还没有完全对齐。  
  引用：`CodexAuthManager.swift:1652-1701`，`CodexAuthManager+SnapshotHelpers.swift:145-170`，`CodexAuthManager+ProviderSync.swift:499-539`  
  代码事实：`api_key` 被认作稳定身份，但 strict identity 完全不认纯 API key。  
  结论：这是当前最明确的代码不一致点。
- `paused` 对 `background_poll` 来说是单向门。  
  引用：`CodexAuthManager+ProviderSync.swift:827-845`，`CodexAuthManager.swift:1298-1300, 1397-1407`  
  代码事实：轮询先消费 hash，再被 paused 短路；自动解除 paused 只在用户重新激活时发生。  
  结论：这会让“外部先写坏、再写回稳定身份”的场景无法自动恢复。

### 行动项
| # | 行动 | 负责方 | 截止 |
|---|------|--------|------|
| 1 | 为 `paused -> 外部再次写入稳定身份 -> 自动恢复托管` 补实现与回归测试 | Codex | 下一个修复轮次 |
| 2 | 审计 `api_key` 漂移路径，避免同一 API key 账号生成重复 snapshot | Codex | 下一个修复轮次 |
| 3 | 评估是否为 paused 状态补 UI 提示，避免用户误以为仍在托管 | 产品 / 客户端 | 后续设计评审 |

### 未解问题
- `base_url` 是否需要在身份判断前做更强的标准化（例如末尾斜杠、大小写、默认端口）。
- `nolon.account.id` 是否应该升级为托管层可独立使用的稳定身份，而不只是在 strict match 中做辅助信号。

# 争论背景

在 Codex 账号卡片区域，从 OAuth 卡片切换到 API Key 卡片时，界面出现了“OAuth 仍为实线选中，API Key 变成虚线”的状态。争论点是：这是否属于 UI 选中态没有完整切换过去。

# 参与者观点

## 第 1 轮

### 观点 A：这是 UI 切换不完整

- 用户感知上，点击 API Key 卡片后，旧卡片仍保留实线高亮，新卡片只出现虚线边框，看起来像“选中态卡在中间态”。
- 如果目标是表达“当前将切换到 API Key”，那么 OAuth 不应继续维持主选中视觉。

### 观点 B：这是当前实现刻意区分 `active` 与 `pending`

- 点击卡片不会立即激活目标账号，而是先进入确认流程。
- 代码中 `requestActivateCodexAccount(id:)` 只会设置 `pendingActivateCodexAccount` 并打开确认框，不会立即切换当前 active 账号。
- 当时卡片样式由 `AccountCardPresentation.codex(...)` 决定，优先级为 `active > pending > selected > neutral`。
- 因此在确认前会同时出现：
  - 旧账号：`active`，实线主边框
  - 新账号：`pending`，虚线主边框

# 代码依据

- 点击卡片仅发起待确认激活：
  - `nolon/Skills/Domain/Providers/Usage/Views/Common/ProviderUsageView.swift`
  - `handleCodexAccountCardTap(accountID:)`
  - `nolon/Skills/Domain/Providers/Usage/Engine/ProviderUsageEngine+CodexLogin.swift`
  - `requestActivateCodexAccount(id:)`

- 待确认状态会弹确认框，而不是直接完成切换：
  - `nolon/Skills/Domain/Providers/Usage/Views/Common/ProviderUsageView.swift`
  - `codexActivateAlertData`
  - `.confirmationAlert(...)`

- 卡片展示状态来自 `active/pending/...`：
  - `nolon/Skills/Domain/Providers/Usage/Root/ProviderUsageAccountsViewModel+CardModels.swift`
  - `makeUsageCardModel(...)`
  - `libs/NolonUIFoundation/Sources/NolonUIFoundation/AccountCard/AccountCardPresentation.swift`

- 边框样式定义：
  - `libs/NolonUI/Sources/NolonUI/Components/AccountCard/UnifiedAccountCardComponents.swift`
  - `active` 为实线，`pending` 为虚线

## 第 2 轮

### 观点 C（Copilot）：`pending` 承担了两个不同语义，这是问题根源；且存在路径一致性漏洞

#### C-1：问题根源不是视觉设计，是状态触发时机

当前 `pending` 状态在弹窗**打开时**就已设置，用户在做决策期间看到两张同时高亮的卡片：

- 旧卡片：`active`，实线 2px 主色边框
- 新卡片：`pending`，虚线 1px 主色边框

这不符合用户的任何一种心理预期：
- 「已切换」→ 应该只有新卡片 `active`
- 「正在询问我」→ 两张卡都应回到 `neutral`，弹窗才是当前焦点

一实一虚同时存在，产生了「split selection」视觉，映射到「切换卡在了中间」的错误认知。

#### C-2：菜单路径绕过了确认弹窗，一致性漏洞

代码证据：

```swift
// tap 卡片 → 设置 pending + 弹确认框
func requestActivateCodexAccount(id: UUID) {
    pendingActivateCodexAccount = account
    isShowingActivateConfirm = true
}

// 菜单「激活」→ 直接激活，无 pending，无弹窗
case .activate:
    Task { await activateAccountImmediately(id: accountID) }
```

相关文件：
- `nolon/Skills/Domain/Providers/Usage/Engine/ProviderUsageEngine+CodexLogin.swift` — `requestActivateCodexAccount` / `activateCodexAccountImmediately`
- `nolon/Skills/Domain/Providers/Usage/Root/ProviderUsageAccountsViewModel+CardModels.swift` — `handleUsageCardAction(.activate:)`

如果 `~/.codex/auth.json` 文件覆写风险大到需要确认弹窗，菜单路径同样应弹；若菜单无需弹窗，则 tap 路径是否需要弹窗同样值得存疑。

#### C-3：确认后 pending 不会立即清除，存在感知 lag

代码证据（`ProviderUsageEngine+CodexLogin.swift`）：

```swift
func confirmActivate() async {
    guard let account = pendingActivateCodexAccount else { return }
    await performCodexActivation(account)   // 耗时操作
    // pendingActivateCodexAccount 在 performCodexActivation 内部才清除
}
```

用户点击「确认」后，弹窗消失，但新卡片**仍保持虚线**直到激活完成。这期间用户感知为「已确认但状态没变」，是额外一层混淆。

#### C-4：对比其他 Provider，Codex 的 pending 状态是孤立设计

Claude / Gemini tap 处理直接调用激活，无 `pending`，无确认弹窗：

```swift
onTap: { [claude] in
    guard !model.isActive else { return }
    await claude.activateAccount(id: account.id)
}
```

Codex 单独引入 `pending` + 确认弹窗，是因为操作涉及本地文件覆写（`~/.codex/auth.json`）。但这一风险差异应体现在**弹窗文案与时机**上，而非通过卡片半选中状态来暗示风险。

#### C-5：建议行动方向

**如果保留确认弹窗：**
- 弹窗打开时，旧卡片降为 `neutral`，新卡片也保持 `neutral`；弹窗本身承担「焦点」角色
- 确认后进入独立的 `loading`/`transitioning` 视觉态（新增 `AccountCardSelectionStyle` 值或用 overlay），而不是复用 `pending`
- `pendingActivateCodexAccount` 在确认后、激活完成前保持，但对应视觉应改为 loading 而非虚线

**如果移除确认弹窗：**
- 对齐菜单路径（已是无确认直接激活），两者统一走 `activateCodexAccountImmediately`
- 补充撤销机制（undo toast）或操作后的轻量提示，替代弹窗的「感知防护」作用

#### C-6：核心结论

`pending` 当前同时承担了「等待用户确认」和「激活进行中」两个语义，两者应拆开表达：

| 阶段 | 当前状态 | 建议状态 |
|---|---|---|
| 弹窗打开中（等待决策） | 新卡片 `pending`，旧卡片 `active` | 两张卡均 `neutral` |
| 确认后激活进行中 | 新卡片 `pending`（复用） | 新卡片 `loading`/`transitioning` |
| 激活完成 | 新卡片 `active` | 新卡片 `active`（不变） |

# 结论与行动项

## 结论

- 当前现象符合现有实现逻辑，不是状态没写进去。
- 但从交互语义看，这个视觉结果非常容易被理解成“切换失败”或“选中态未完成迁移”。
- 因此问题本质是：`pending` 的视觉语义与“卡片切换”场景不匹配，而不是状态机本身失效。

## 行动项

- 评估是否保留确认弹窗。
- 如果保留确认弹窗，需重设计 `pending` 的视觉表达，避免与“未切换成功”混淆。
- 如果希望点击卡片即完成切换，可改为直接调用 `activateCodexAccountImmediately(id:)`，并补充对应 BDD/TDD 测试。

## 第 3 轮

### 对比结论：观点 B 解释了“现象为什么出现”，观点 C 解释了“问题为什么成立”

- 观点 B 是对现状实现的准确描述：
  - 当前并不是状态丢失，而是旧卡片保持 `active`，新卡片进入 `pending`
  - 因此“oauth 实线、apikey 虚线”符合现有代码行为

- 观点 C 指出了更深层根因：
  - `pending` 被同时用于“等待用户确认”和“确认后正在执行切换”
  - 并且它在弹窗打开前就写入了卡片状态，导致卡片区提前进入“半切换”视觉

### 最终判断：根因分两层，主因是状态建模，次因是交互路径不一致

#### 主因：状态建模错误

- 当前阶段至少有三个语义：
  - 当前已激活账号
  - 用户正在被询问是否切换
  - 用户已确认，系统正在执行切换
- 但实现里只有：
  - `active`
  - `pending`
- 于是 `pending` 被复用到两个不同阶段，直接造成：
  - 弹窗出现时，卡片区已经发生视觉变化
  - 确认后到切换完成前，仍然沿用同一套虚线视觉

#### 次因：入口行为不一致

- tap 卡片：
  - 进入 `pending` + 弹确认框
- 菜单 `Activate`：
  - 直接调用 `activateAccountImmediately`
- 这说明“是否需要确认”本身也没有在交互层被统一定义

### 归纳

- 如果只问“为什么会看到 oauth 实线、apikey 虚线”：
  - 答案是：旧卡片仍是 `active`，新卡片只是 `pending`

- 如果问“为什么用户会觉得 UI 没完整切换过去”：
  - 真正根因是：`pending` 的状态建模和触发时机不对
  - 视觉样式只是把这个建模问题暴露出来，不是根因本身

## 第 4 轮

### 落地后的新问题与收口结论

第一轮修正把“等待确认”和“执行切换”拆成了不同状态，但上线后又暴露出三个后续问题：

- 切换过程中同时出现两个高亮：
  - 旧账号仍按 `active` 高亮
  - 新账号按 `transitioning` 高亮
- 右上角 `Switching` badge 会长时间停留
- 菜单 `Activate` 和卡片 tap 仍然不是同一条交互路径

### 最终收口

本轮确认了更严格的产品约束：

- 同一时刻只能有一个账号处于“激活态视觉”
- `transitioning` 只是瞬时过程态，不应再通过常驻 badge 暴露成独立业务状态
- 菜单激活和卡片激活必须统一走“先确认，再执行”流程

### 已实施修正

- 当存在 `activatingCodexAccountId` 时：
  - 只有目标卡片保留 `transitioning` 高亮
  - 旧 `active` 卡片立即退回非高亮
- 移除 `Switching` badge：
  - `transitioning` 只保留卡片边框/选中视觉，不再映射为右上角常驻文案
- 激活失败时：
  - 不再把失败账号偷偷回填为隐藏的 `pending`
  - 直接清空瞬时状态，仅保留失败提示
- 菜单 `Activate`：
  - 改为与 tap 一致，先进入确认流程，不再直接执行激活
- 激活成功时：
  - `activatingCodexAccountId` 延迟到 reload 完成后再清理，避免中间出现“无卡高亮”的空档

### 验证

- `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/ProviderUsageEngineActivationTests -only-testing:nolonTests/ProviderUsageUnifiedAccountsPipelineTests`
- 结果：`TEST SUCCEEDED`

## 第 5 轮

### 新参与者补充后的最终收口

- 继续追查后确认，问题已经不只是“视觉语义不合适”，而是旧实现把 Codex 卡片状态拆散在多处重复推导：
  - 交互层有 `activeCodexAccountId`
  - 切换层有 `pendingActivateCodexAccount` / `activatingCodexAccountId`
  - 展示层再用多个布尔重新拼 `AccountCardPresentation.codex(...)`
- 这会直接导致两个异常：
  - 旧 OAuth 卡片视觉上似乎退下去了，但点击逻辑仍把它当成 active，所以点回去没反应
  - 切换中旧卡和目标卡可能同时高亮，因为展示和点击不是同一份状态源

### 最终根因

- 根因不是 `apikey` 和 `oauth` 的账号 UUID 不同。
- 根因是：
  - 点击是否允许切换
  - 卡片当前边框/高亮样式
  - 菜单里是否显示 `Activate`
  - 这三件事在旧实现里不是从同一个状态枚举推导出来的。

### 最终修正

- Foundation 层已废弃 Codex 卡片的多布尔拼装方式，改成单一展示状态：
  - `inactive`
  - `active`
  - `switching`
  - `selected`
- 业务层新增统一交互状态：
  - `inactive`
  - `active`
  - `awaitingConfirmation`
  - `switching`
- 当前规则变为：
  - 所有点击、菜单 `Activate` 显示条件、卡片展示态，都先经过同一个 `codexInteractionState(accountID:)`
  - 只要存在 `activatingCodexAccountId`，除目标卡外，其余卡片一律按 `inactive` 处理
  - 因此切换中只会有目标卡高亮，旧 active 卡立即退回非高亮，但重新变得可点击

### 最终结论

- 这次问题的根源是“同一业务语义有多份状态源”，不是单纯的边框样式 bug。
- 修正后，Codex 卡片已经满足新的产品约束：
  - 同一时刻只有一个账号能处于激活态视觉
  - 旧卡片不会再被逻辑误判成 active 而导致点击失效
  - UI 选中态和点击切换能力来自同一份交互状态

### 本轮验证

- `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/AccountCardPresentationTests -only-testing:nolonTests/ProviderUsageEngineActivationTests -only-testing:nolonTests/ProviderUsageUnifiedAccountsPipelineTests -only-testing:nolonTests/CodexAccountDisplaySectionsTests -only-testing:nolonTests/NolonAccountsViewModelTests`
- 结果：`TEST SUCCEEDED`

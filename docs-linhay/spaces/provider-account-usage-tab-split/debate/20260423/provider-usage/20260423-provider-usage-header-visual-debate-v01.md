# Provider Usage Header 视觉辩论记录（2026-04-23）

## 辩论背景

- 主题：`Provider Usage -> Trend Workspace` 顶部控制区视觉重构。
- 起因：用户在真实运行截图中指出顶部控制区“太丑、太像设置页、占高过多”，并明确希望参考 Gemini 的审美判断。
- 当前代码上下文：
  - `/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedProviderUsageSupportViews.swift`
  - `/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/NolonUI/Sources/NolonUI/Components/Shared/ProviderTokenTrendIntradayWorkspaceViews.swift`

## 参与者观点

### 17:00 Codex（主持人）

- 论点：现状的主要问题不是功能缺失，而是 `Trend Content / Usage Metric / Chart Style / Bucket` 被拆成了纵向 card groups，视觉上更像设置页而不是分析工具条。
- 引用：
  - `/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedProviderUsageSupportViews.swift:496`
  - `/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedProviderUsageSupportViews.swift:535`
  - `/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedProviderUsageSupportViews.swift:555`
  - `/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedProviderUsageSupportViews.swift:573`
- 代码事实：
  - 顶部控制区由多个 `ProviderTokenTrendControlCard` 组成；
  - 每个 control card 都有标题、边框、背景和内部 segmented；
  - `Bucket` 在 intraday 上下文里再占一层。
- 结论：
  - 这会把图前高度抬高，也让信息主次失衡。

### 17:01 Gemini

- 论点：应该从“表单思维”切换到“工具思维”，把顶部区域重构为双层 rails，而不是卡片堆叠。
- 引用：
  - `/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedProviderUsageSupportViews.swift:496`
  - `/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/NolonUI/Sources/NolonUI/Components/Shared/ProviderTokenTrendIntradayWorkspaceViews.swift:142`
- 代码事实：
  - 顶部控件本身都是高频切换动作，天然更适合 toolbar rail；
  - 日期与 usage summary 是上下文状态，应该比主控件更轻。
- Gemini 原话摘要：
  - 当前 UI 是“把分析工具栏做成设置卡片”；
  - 应改成 `single-rail toolbar + contextual bottom rail`；
  - 用 `Divider` 分组，不要再给每组单独一张 card。
- 结论：
  - 顶部应改成统一 toolbar，下方只保留 context tags。

## 轮次变化

### 第 1 轮

- Codex 判断：需要去掉 control card，改成统一 toolbar。
- Gemini 判断：不仅要去掉 card，还要把 `Bucket` 收回主工具栏，让中间层只承担 context。
- 共识：
  - 顶部是主工具栏；
  - 第二层是上下文轨道；
  - `legend / freshness / bucketSummary / presentationNote` 下沉到图表脚注区。

## 结论与行动项

### 结论

1. 采用“单一分析工具栏 + 轻量上下文轨道”的桌面分析工具布局。
2. 不再使用多张 `ControlCard` 纵向堆叠。
3. `Bucket` 只在 intraday 时以内联方式出现在主工具栏。
4. `selected day + range` 与 `usage summary` 作为第二层 context rail。

### 行动项

1. 新增统一 `ProviderTokenTrendToolbarRail`。
2. 把 `workspaceControlDeck` 重构为 inline segmented controls + divider。
3. 删除 `Daily` 图区下方重复说明，只保留 legend。
4. 回归验证：
   - `swift test --package-path libs/NolonUI --filter 'ProviderTokenTrendSectionViewTests|ProviderTokenTrendDailyChartSupportTests|ProviderTokenTrendIntradayChartSupportTests'`
   - `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/ProviderTokenTrendViewModelParityTests`

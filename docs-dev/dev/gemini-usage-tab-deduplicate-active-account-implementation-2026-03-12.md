# Gemini 用量页去掉激活账号重复展示：实现说明（2026-03-12）

## 原因
- `ProviderUsageViewModel.load()` 会同时加载：
  - `geminiAccounts`
  - `outcomes`
- `GeminiUsageDescriptor` 只会为当前激活账号生成一条 outcome。
- `ProviderUsageView.genericUsageContent` 之前同时渲染账号卡和 outcome 卡，导致当前激活账号视觉上重复出现。

## 实现
- 在 `ProviderUsageViewModel` 新增纯函数：
  - `displayedGenericUsageOutcomes(usageProvider:hasGeminiAccounts:outcomes:)`
- 规则：
  - 当 `usageProvider` 是 `.gemini` 或 `.antigravity` 且已经存在账号卡时，返回空数组。
  - 其他情况原样返回 outcomes。
- `ProviderUsageView` 改为渲染该纯函数返回的结果，而不是无条件渲染 `viewModel.outcomes`。

## 测试
- 在 `CodexUsageTabPresentationTests` 新增：
  - `testBDD_GivenGeminiAccountsPresent_WhenResolvingDisplayedGenericUsageOutcomes_ThenHidesDuplicateOutcomeCards`
  - `testBDD_GivenGeminiWithoutAccounts_WhenResolvingDisplayedGenericUsageOutcomes_ThenKeepsOutcomeCardsForEmptyState`
- 已运行：
  - `xcodebuild test -quiet -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexUsageTabPresentationTests`

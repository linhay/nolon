# Codex 账号与用量支持列表/卡片切换（2026-03-20）

## 背景
- 页面：`Main / Codex / 账号与用量`
- 问题：当前账号区与网关卡片区仅支持卡片网格展示，缺少列表模式。

## 需求
1. 支持在 `卡片` 与 `列表` 两种模式间切换。
2. 切换应作用于：
   - Codex 账号展示区
   - 网关卡片展示区
3. 展示模式需要持久化，重开应用后保持上次选择。

## BDD 场景
1. Given `codexUseListLayout = true`，When 打开 `账号与用量`，Then 默认以列表模式展示。
2. Given 当前为卡片模式，When 切换到列表模式，Then `settings.codexUseListLayout == true`。
3. Given 当前为列表模式，When 切换到卡片模式，Then `settings.codexUseListLayout == false`。

## 实现要点
1. 在 `ProviderUsageMonitorSettings` 新增 `codexUseListLayout: Bool`（默认 `false`），并纳入 Codable。
2. 在 `ProviderUsageViewModel` 新增：
   - `CodexAccountLayoutMode`（`cards` / `list`）
   - `codexAccountLayoutMode`
   - `setCodexAccountLayoutMode(_:)`
3. 在 `ProviderUsageView`：
   - 顶部新增分段切换控件（卡片/列表）
   - 菜单“显示”分组中新增布局 Picker
   - 账号区与网关区按模式切换 `LazyVGrid` / `LazyVStack`

## 验证
1. `swift test -q --package-path libs/Providers --scratch-path /tmp/providers-scratch-layout-mode --filter ProviderUsageMonitorSettingsTests`
2. `xcodebuild test -quiet -project nolon.xcodeproj -scheme nolon-app -destination 'platform=macOS' -only-testing:nolonTests/CodexUsageTabPresentationTests`

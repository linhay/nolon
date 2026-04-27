# Gemini Auth CLI 隔离实现说明（2026-03-05）

关联 feature: `docs-linhay/spaces/gemini-antigravity-auth-isolation/README.md`

## 实现摘要
1. `gemini` 命令组从 `usage` 改为 `auth`。
2. 新增子命令：`list/status/login/refresh/activate/delete/usage/doctor`。
3. `--provider` 统一必填，去除默认 provider。
4. Runner 内部账号存储基于 `ProviderUsage` 的 `token-accounts.json`，按 `UsageProvider` 分桶（`gemini` 与 `antigravity` 互不共享）。

## 关键接口
- `NolonCoreCLICommand`
  - 移除 `geminiUsageOverview/geminiUsageDoctor`
  - 新增 `geminiAuthList/status/login/refresh/activate/delete/usage/doctor`
- `NolonCoreCLIRunner`
  - 新增 provider 解析与账号 CRUD/touch 逻辑
  - 新增 Gemini auth payload:
    - `GeminiAuthAccountView`
    - `GeminiAuthListPayload`
    - `GeminiAuthStatusPayload`
    - `GeminiAuthMutationPayload`

## 行为说明
1. `login`
- 支持 `--token`；若未传，按 `GEMINI_API_KEY` -> `GOOGLE_API_KEY` 回退。
- 登录成功后自动激活该账号。

2. `activate/delete`
- 仅在目标 provider 桶中查找与修改账号。
- 未命中账号时返回明确错误。

3. `usage/refresh/doctor`
- 保留原有本地 probe 诊断能力。
- 命令 ID 统一迁移到 `gemini.auth.*`。
- Descriptor 行为补充：
  - `sourceMode == .localProbe` 且缺少 probe 数值时，维持 `unsupported` 失败（用于 CLI doctor 诊断）。
  - `sourceMode == .auto` 且缺少 probe 数值时，返回 fallback 成功快照（无 primary/secondary/tertiary 指标），避免 App 默认会话显示错误卡片。
  - App 卡片在“成功但无指标”时显示占位文案：`No usage metrics available for this account yet.`。
  - App header 行为补充：Gemini/Antigravity 不再展示 `Sign in…`（该入口仅打开 dashboard，不存在 OAuth URL 提取）；统一展示 `Refresh`。

## 兼容策略
- 本次为破坏性更新，不保留旧命令兼容。

## 回归修复（2026-03-05）
1. 现象
- Gemini Usage Header 仍显示 `登录`，用户点击后期望出现 OAuth URL 提取，但 Gemini CLI 官方流程并不提供稳定的外部 URL 回传链路（与 Codex AppServer 登录不同）。

2. 修复
- `ProviderUsageLoginPolicy.shouldUseCLILogin(for:)` 对 `gemini|antigravity` 返回 `false`。
- Gemini/Antigravity Header 统一使用 `Refresh`（若无 dashboard sign-in 场景），不再暴露误导性的 CLI 登录入口。

3. 验证
- 新增 BDD 测试：
  - `testBDD_GivenGeminiProvider_WhenResolvingCLILoginPolicy_ThenUsesRefreshOnly`
- 通过测试：
  - `CodexUsageTabPresentationTests`
  - `UsageIssueClassifierTests`
  - `GeminiUsageTabConfigurationTests`
  - `./build.sh`

## 回退修复（2026-03-05）
1. 现象
- 实际使用中（如 `No active account for gemini. Please sign in.`），页面只有 `Refresh`，用户没有可见登录入口。

2. 修复
- 恢复 Gemini/Antigravity 的 CLI 登录入口：
  - `ProviderUsageLoginPolicy.shouldUseCLILogin(for:)` 对 `gemini|antigravity` 返回 `true`。
- Header 展示 `登录 + Refresh`，与错误提示中的“请先登录”保持一致。

3. 验证
- 更新 BDD 用例为：
  - `testBDD_GivenGeminiProvider_WhenResolvingCLILoginPolicy_ThenShowsLoginAction`
- 通过测试：
  - `xcodebuild ... -only-testing:nolonTests/CodexUsageTabPresentationTests/testBDD_GivenGeminiProvider_WhenResolvingCLILoginPolicy_ThenShowsLoginAction`
  - `xcodebuild ... -only-testing:nolonTests/CodexUsageTabPresentationTests -only-testing:nolonTests/UsageIssueClassifierTests`

## CLI 可执行路径容错（2026-03-05）
1. 现象
- 使用 GUI 启动 App 时可能出现：`Missing CLI 'gemini'. Install Gemini CLI and make it available in PATH.`
- 根因是 GUI 进程 PATH 与终端 PATH 不一致，导致 `resolveExecutable("gemini")` 失败。

2. 修复
- 按要求收敛为单一解析策略：
  - 非绝对路径命令（`gemini`）仅调用 `resolveExecutableInUserShellSync`。
  - 不再注入 PATH、不再使用覆盖变量、不再做候选路径回退。
- 兼容显式路径调用：
  - 当 binary 包含 `/` 时，直接按路径校验可执行性。

3. 验证
- 新增 `GeminiLoginRunnerTests`：
  - `resolve executable uses user shell resolver result when available`
  - `resolve executable throws not found when user shell resolver misses binary`
  - `resolve executable accepts explicit executable path`
- `swift test --package-path libs/Providers --filter GeminiLoginRunnerTests --filter GeminiAuthStoreTests --filter GeminiUsageDescriptorTests` 通过。

## Gemini 已登录但 App 仍提示无 active account（2026-03-05）
1. 现象
- 用户在终端已完成 `gemini` 登录，但 App Usage 仍报：
  - `No active account for gemini. Please sign in.`

2. 根因
- App 的 Gemini usage 读取 `GeminiAuthStore`（`Application Support/Nolon/gemini-auth/...`）作为账号源。
- 终端 CLI 历史登录缓存（`~/.gemini/...`）不会自动导入到该 store，导致 active account 为空。

3. 修复
- 改为“用户确认后导入”，取消自动导入：
  - `GeminiUsageDescriptor.fetchOutcome` 保持纯读取，不再隐式导入。
  - `GeminiAuthStore` 新增两段式 API：
    - `globalSessionImportCandidate(provider:environment:)`：仅检测是否存在可导入会话（仅 `provider == .gemini`）。
    - `importFromCLIGlobalSession(provider:environment:)`：仅在 UI 明确确认后执行导入。
  - Usage 页点击 Gemini `登录` 时，若检测到 `~/.gemini` 可导入凭据，先弹确认框：
    - `Import`：导入并激活账号。
    - `Continue OAuth Login`：不导入，继续走 Gemini OAuth 登录流程。

4. 验证
- 新增 `GeminiAuthStoreTests`：
  - `detects import candidate from existing Gemini CLI login cache`
  - `imports only after explicit confirmation call`
  - `import candidate keeps antigravity isolated from global gemini cache`
- 命令：
  - `swift test --package-path libs/Providers --filter GeminiAuthStoreTests --filter GeminiUsageDescriptorTests --filter GeminiLoginRunnerTests`
- 结果：通过（12 tests in 3 suites）。

## Gemini 导入入口直出修正（2026-03-05）
1. 现象
- 用户已登录 Gemini CLI，但 Usage 页面仅提示 `No active account for gemini. Please sign in.`，导入入口未稳定出现。

2. 根因
- 导入卡片展示条件绑定在 `missingAccount(.gemini)` 错误分支上。
- 当错误类型/状态与该分支不完全一致时，即使存在可导入会话也不会显示入口。

3. 修复
- 改为“候选即显示”：
  - `ProviderUsageViewModel.shouldShowGeminiImportAction` 仅要求 `usageProvider == .gemini && candidateAvailable == true`。
  - `refreshGeminiImportCandidateAvailabilityIfNeeded` 对 Gemini 始终执行候选检测，不再依赖 `missingAccount` 前置条件。
- 仍保持“显式确认后导入”，未恢复自动导入。

4. 验证
- 更新 BDD 用例：
  - `testBDD_GivenGeminiCandidate_WhenEvaluatingInlineImportPolicy_ThenShowsImportAction`
  - `testBDD_GivenGeminiWithoutCandidate_WhenEvaluatingInlineImportPolicy_ThenHidesImportAction`
- 命令：
  - `xcodebuild -project nolon.xcodeproj -scheme nolon-app -destination 'platform=macOS' test -only-testing:nolonTests/CodexUsageTabPresentationTests -only-testing:nolonTests/UsageIssueClassifierTests`
- 结果：`TEST SUCCEEDED`。

## Antigravity 失败态切换 Tab 不刷新修复（2026-03-05）
1. 现象
- Antigravity Usage 出现 `Failed to load usage` 后，切换到其他 tab 再回来，经常不触发重新拉取。

2. 根因
- `handleUsageViewAppear` 的刷新决策仅依赖 `UsageRefreshPolicy`（首屏/时间窗）。
- 在失败后仍会更新 `lastUsageRefreshAt`，导致回到 tab 时常落在间隔窗口内，被判定为“不刷新”。

3. 修复
- 新增失败态强制刷新策略：
  - `ProviderUsageViewModel.shouldForceRefreshOnAppearForFailedOutcomes(_:)`。
  - `handleUsageViewAppear` 中将决策改为：`时间窗策略 || 失败态强制刷新`。
- 结果：只要当前 outcome 仍是失败，切回该 tab 会立即重试，不受自动刷新间隔限制。

4. 验证
- 新增 BDD 用例：
  - `testBDD_GivenFailedUsageOutcome_WhenEvaluatingAppearRefreshPolicy_ThenForcesRefresh`
  - `testBDD_GivenSuccessfulUsageOutcome_WhenEvaluatingAppearRefreshPolicy_ThenDoesNotForceRefresh`
- 命令：
  - `xcodebuild -project nolon.xcodeproj -scheme nolon-app -destination 'platform=macOS' test -only-testing:nolonTests/CodexUsageTabPresentationTests -only-testing:nolonTests/UsageIssueClassifierTests`
  - `xcodebuild -project nolon.xcodeproj -scheme nolon-app -destination 'platform=macOS' test -only-testing:nolonTests/CodexUsageTabPresentationTests/testBDD_GivenFailedUsageOutcome_WhenEvaluatingAppearRefreshPolicy_ThenForcesRefresh -only-testing:nolonTests/CodexUsageTabPresentationTests/testBDD_GivenSuccessfulUsageOutcome_WhenEvaluatingAppearRefreshPolicy_ThenDoesNotForceRefresh`
- 结果：`TEST SUCCEEDED`。

## Antigravity -> Gemini 切换不刷新修复（2026-03-05）
1. 现象
- 从 `antigravity` usage tab 切到 `gemini` usage tab 时，页面未触发刷新，表现为仍停留在旧 provider 状态。

2. 根因
- `ProviderUsageView` 使用 `@State` 持有 `ProviderUsageViewModel`，在父层切换 provider 时可能复用旧 view 状态，导致 viewModel 未重建。
- 旧 viewModel 绑定旧 provider，`loadIfNeeded()` 可能直接返回，造成“切换不刷新”。

3. 修复
- 在 `ProviderUsageView` 增加 `onChange(of: provider.id)`，provider 变化时重建 viewModel 并立即 `loadIfNeeded()`。
- 在 `ProviderDetailGridView` 的 `.accounts/.usage` 分支对 `ProviderUsageView` 增加 `.id(provider.id)`，强制 provider 维度重建视图。

4. 验证
- 命令：
  - `xcodebuild -project nolon.xcodeproj -scheme nolon-app -destination 'platform=macOS' test -only-testing:nolonTests/CodexUsageTabPresentationTests -only-testing:nolonTests/UsageIssueClassifierTests`
- 结果：`TEST SUCCEEDED`。

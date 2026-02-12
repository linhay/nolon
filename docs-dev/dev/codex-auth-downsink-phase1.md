# Codex Auth 下沉（Phase 1）

## 目标
- 将 Codex 认证账户管理核心逻辑从 `nolon` app 下沉到 `libs/Providers`。
- app 层仅保留薄编排/桥接，不再持有 auth 细节实现。

## BDD 验收场景
1. Given 账户快照包含 `id_token/access_token`，When 读取 token，Then 返回完整 token pair。
2. Given 选中快照包含 `nolon` 元数据，When 激活到 provider `auth.json`，Then 写入 clean auth（去除 `nolon`）。
3. Given CLI 登录后新写入 `auth.json`，When finalize 登录，Then 新快照入库且 active account 被标记。

## TDD 过程
- 先新增库侧测试（红灯）：`CodexAuthManagerTests`。
- 新增 `ProviderUsage.CodexAuthManager`、`ProviderUsage.CodexAuthAccount`、`ProviderUsage.CodexAuthSummary`。
- app 层 `CodexAuthService` 改为桥接 `CodexAuthManager`。
- app 层模型 `CodexAuthAccount/CodexAuthSummary` 改为对库类型的 typealias。
- 处理 Swift 6.2 并发约束：
  - 去除 actor 静态 `ISO8601DateFormatter` 共享实例，改为按需创建 formatter。
  - `CLILoginError.errorDescription` 提升为 `public`。
  - app 桥接层改为 `async/await` 转发，避免跨 actor 同步调用。

## 变更文件
- `libs/Providers/Sources/ProviderUsage/CodexAuthManager.swift`
- `libs/Providers/Sources/ProviderUsage/CodexAuthAccount.swift`
- `libs/Providers/Tests/ProvidersTests/CodexTests/CodexAuthManagerTests.swift`
- `libs/Providers/Package.swift`
- `nolon/Skills/Infrastructure/CodexAuthService.swift`
- `nolon/Skills/Models/CodexAuthAccount.swift`

## 验证
- `swift test --package-path libs/Providers --filter CodexAuthManagerTests`
- `xcodebuild test -project nolon.xcodeproj -scheme nolon -destination 'platform=macOS' -only-testing:nolonTests/CodexAuthServiceTests`

## 未迁移清单（下一阶段）
1. app 侧事件去抖与 watcher 策略（`TimedEventDeduplicator` / `CodexAuthEventPolicy`）仍在 `nolonTests` 侧验证，尚未下沉到库。
2. Codex runtime account switch 与 auth snapshot 的统一门面尚未收敛（`CodexRuntimeAccountSwitcher` 与 `CodexAuthManager` 仍分离）。
3. usage/session 全事件模型（`response_item/event_msg/compacted`）未并入统一 auth+usage parser。

## Phase 1.1：Auth 事件策略与抑制器下沉

### 目标
- 将 app 侧 auth 文件变更策略中的可复用部分下沉到 `ProviderUsage`：
  - 已知账户文件 rename 过滤策略
  - auth 变更短窗口抑制存储

### 新增库能力
- `ProviderUsage/CodexAuthEventPolicy.swift`
  - `CodexAuthEventChangeKind`
  - `CodexAuthEventPolicy.shouldIgnoreKnownAuthRename(...)`
  - `CodexAuthChangeSuppressionStore`

### App 接入调整
- `ProviderUsageViewModel`：
  - 原 `codexAuthChangeSuppressions: [String: Date]` 替换为 `CodexAuthChangeSuppressionStore`
  - rename 过滤改为调用 `CodexAuthEventPolicy.shouldIgnoreKnownAuthRename`

### 测试
- 库侧新增：`CodexAuthEventPolicyTests`、`CodexAuthChangeSuppressionStoreTests`
- app 侧 `CodexAuthServiceTests` 的策略测试改为直接验证库实现（删除本地重复策略定义）

### 验证
- `swift test --package-path libs/Providers --filter 'CodexAuthEventPolicyTests|CodexAuthChangeSuppressionStoreTests'`
- `xcodebuild test -project nolon.xcodeproj -scheme nolon -destination 'platform=macOS' -only-testing:nolonTests/CodexAuthServiceTests`

## Phase 1.2：Auth + Runtime 统一门面

### 目标
- 在库侧提供统一编排入口：读取 auth snapshot token 并执行 Codex runtime account switch。
- app 层调用统一门面，不直接拼装 token 切换流程。

### 新增库能力
- `ProviderUsage/CodexAuthRuntimeCoordinator.swift`
  - `CodexAuthRuntimeCoordinator.activateAccountInRuntime(...)`
  - `CodexAuthRuntimeCoordinatorError`
    - `tokenPairMissing(accountID:)`
    - `runtimeSwitchFailed(reason:)`

### 测试（先红后绿）
- `CodexAuthRuntimeCoordinatorTests`
  - Given token pair, Then runtime switch 使用对应 token
  - Given token 缺失, Then 抛 `tokenPairMissing` 且不触发 switch
  - Given runtime 异常, Then 抛 `runtimeSwitchFailed`

### app 接入
- `ProviderUsageViewModel.confirmActivate()`
  - 激活 snapshot 到 provider auth 后，调用 `CodexAuthRuntimeCoordinator.shared.activateAccountInRuntime`
  - runtime 切换失败仅记录日志，不阻塞激活流程

### 验证
- `swift test --package-path libs/Providers --filter 'CodexAuthRuntimeCoordinatorTests|CodexAuthEventPolicyTests|CodexAuthChangeSuppressionStoreTests'`
- `xcodebuild test -project nolon.xcodeproj -scheme nolon -destination 'platform=macOS' -only-testing:nolonTests/CodexAuthServiceTests`

## Phase 1.3：Session 事件类型化与统一解析 API

### 目标
- 为 `~/.codex/sessions/**/*.jsonl` 提供统一事件解析入口，覆盖：
  - `response_item`
  - `event_msg`
  - `compacted`
- 让 token 统计链路通过统一 parser fast-path 获取 `token_count/turn_context/session_meta`，不再在 scanner 内部散落解析逻辑。

### 新增库能力（CodexProvider）
- `CodexSessionEventParser.swift`
  - `CodexSessionEvent`（完整事件模型）
  - `CodexSessionUsageEvent`（统计 fast-path 模型）
  - `parseEventLine(...)`（完整解析）
  - `parseUsageEventLine(...)`（高性能统计路径）

### 现有链路接入
- `CostUsageScanner.parseCodexFile` 改为调用 `CodexSessionEventParser.parseUsageEventLine(data:)`：
  - `session_meta` -> session id
  - `turn_context` -> current model
  - `token_count` -> 增量 token 聚合

### 测试
- 新增 `CodexSessionEventParserTests`
  - 解析 `response_item` 类型化输出
  - 解析 `event_msg` 与 `compacted` 类型化输出
  - fast-path 对 `session_meta/turn_context/token_count` 的提取与过滤
- 回归 `CostUsageStoragePathTests` 确认 token 统计链路仍正确。

### 验证
- `swift test --package-path libs/Providers --filter 'CodexSessionEventParserTests|CostUsageStoragePathTests'`

## Phase 1.4：移除 App Auth 包装层（Service => Typealias）

### BDD 场景
- Given app 层仍保留 `CodexAuthService` 包装 actor，When 执行下沉收敛，Then app 类型应直接等同 `ProviderUsage.CodexAuthManager`，不再维护重复转发实现。

### TDD（红 -> 绿）
- 先新增迁移守卫测试（红灯）：
  - `CodexAuthServiceTests.testBDD_GivenAppAuthServiceType_WhenCheckingMigrationBoundary_ThenUsesProviderUsageManagerType`
- 最小实现（绿灯）：
  - `nolon/Skills/Infrastructure/CodexAuthService.swift` 改为：
    - `typealias CodexAuthService = CodexAuthManager`
  - 删除 app 侧 1:1 转发包装实现，保留调用点 API 不变。

### 影响文件
- `nolon/Skills/Infrastructure/CodexAuthService.swift`
- `nolonTests/CodexAuthServiceTests.swift`

### 验证
- `xcodebuild test -project nolon.xcodeproj -scheme nolon -destination 'platform=macOS' -only-testing:nolonTests/CodexAuthServiceTests/testBDD_GivenAppAuthServiceType_WhenCheckingMigrationBoundary_ThenUsesProviderUsageManagerType`
- `xcodebuild test -project nolon.xcodeproj -scheme nolon -destination 'platform=macOS' -only-testing:nolonTests/CodexAuthServiceTests -only-testing:nolonTests/CodexBinaryDownsinkMigrationTests -only-testing:nolonTests/CodexBinaryAutoUpdateBehaviorTests`

## Phase 1.5：去除 App 侧 Auth 旧名（CodexAuthService）

### 目标
- 将 app 代码与测试中的 `CodexAuthService` 旧名彻底移除，统一使用 `CodexAuthManager`，并删除别名文件，降低迁移期认知噪音。

### 变更
- 删除：
  - `nolon/Skills/Infrastructure/CodexAuthService.swift`
- app 接入统一：
  - `ProviderUsageViewModel` 内部依赖改为 `codexAuthManager: CodexAuthManager`
  - `cleanedAuthJSONData` 调用统一为 `CodexAuthManager.cleanedAuthJSONData(...)`
- 测试统一：
  - `nolonTests/CodexAuthServiceTests.swift` 中实例化调用改为 `CodexAuthManager(...)`
  - 测试类统一为 `CodexAuthManagerTests`

### 验证
- `xcodebuild test -project nolon.xcodeproj -scheme nolon -destination 'platform=macOS' -only-testing:nolonTests/CodexAuthManagerTests -only-testing:nolonTests/CodexAuthTokenExtractionTests -only-testing:nolonTests/CodexAuthActiveAccountRegistryTests -only-testing:nolonTests/CodexAuthCompatSyncTests -only-testing:nolonTests/CodexBinaryDownsinkMigrationTests -only-testing:nolonTests/CodexBinaryAutoUpdateBehaviorTests`

## Phase 1.6：CLI 登录快照编排继续下沉

### BDD 场景
- Given CLI 登录产出的 auth JSON 与已有快照，When 记录登录快照，Then 优先更新指定账号并刷新登录/同步元数据。

### TDD（红 -> 绿）
- 先新增库侧测试（红灯）：
  - `CodexAuthManagerTests.recordCLILoginSnapshotUpdatesPreferredAndMetadata`
- 最小实现（绿灯）：
  - `CodexAuthManager` 新增 `recordCLILoginSnapshot(authJSONString:preferredAccountID:loginAt:)`
  - 内部统一调用：
    - `upsertAccountFromCLILogin(...)`
    - `updateLoginSuccess(...)`
    - `updateSyncSuccess(...)`
- app 编排收敛：
  - `ProviderUsageViewModel.runCLILoginFlow` 删除本地“按 email/哈希匹配 + add/update + 时间戳写入”细节
  - 改为单点调用 `codexAuthManager.recordCLILoginSnapshot(...)`

### 测试修正（行为对齐）
- `ProviderUsageViewModelCLILoginTests` 旧断言“运行中重复点击登录会被忽略”与现实现不一致（当前语义是重启并携带 preferred account）。
- 更新用例为：
  - `testBDD_GivenCLILoginAlreadyRunning_WhenRequestingCardLoginAgain_ThenFlowRestartsWithPreferredAccount`

### 验证
- `swift test --package-path libs/Providers --filter CodexAuthManagerTests`
- `xcodebuild test -project nolon.xcodeproj -scheme nolon -destination 'platform=macOS' -only-testing:nolonTests/CodexAuthManagerTests -only-testing:nolonTests/ProviderUsageViewModelCLILoginTests`

## Phase 1.7：激活编排门面下沉（auth + runtime）

### BDD 场景
- Given 账户激活成功且 runtime 切换成功，When 触发统一激活，Then 返回 runtime 切换成功结果。
- Given 账户激活成功但 runtime 切换失败，When 触发统一激活，Then 不抛错且返回 runtime 失败信息（不阻断激活）。
- Given 账户激活失败，When 触发统一激活，Then 抛出激活错误且 runtime 不执行。

### TDD（红 -> 绿）
- 新增库侧门面测试：
  - `CodexAuthActivationCoordinatorTests`
- 新增库侧门面实现：
  - `CodexAuthActivationCoordinator`
  - `CodexAuthActivationResult`
- app 接入：
  - `ProviderUsageViewModel.confirmActivate` 改为调用 `CodexAuthActivationCoordinator.shared.activate(...)`
  - 继续保持现有策略：runtime 错误只记录日志，不弹窗阻断激活。

### 验证
- `swift test --package-path libs/Providers --filter CodexAuthActivationCoordinatorTests`
- `xcodebuild test -project nolon.xcodeproj -scheme nolon -destination 'platform=macOS' -only-testing:nolonTests/CodexAuthManagerTests -only-testing:nolonTests/ProviderUsageViewModelCLILoginTests`

## Phase 1.8：激活后 active registry 标记下沉

### BDD 场景
- Given 通过统一激活门面完成账户激活，When provider `auth.json` 后续缺失，Then 仍可通过 active registry 识别当前激活账户。

### TDD（红 -> 绿）
- 先补库侧红灯：
  - `CodexAuthManagerTests.activateAccountAndMarkActivePersistsRegistry`
  - 期望存在统一 API：`activateAccountAndMarkActive(...)`
- 最小实现（绿灯）：
  - `CodexAuthManager` 新增：
    - `activateAccountAndMarkActive(_:, for:)`
    - 内部执行 `activateAccount` + `setActiveAccount`
  - `CodexAuthActivationCoordinator` 默认 auth 激活路径切换为该新 API。

### 验证
- `swift test --package-path libs/Providers --filter CodexAuthManagerTests`
- `swift test --package-path libs/Providers --filter CodexAuthActivationCoordinatorTests`
- `xcodebuild test -project nolon.xcodeproj -scheme nolon -destination 'platform=macOS' -only-testing:nolonTests/CodexAuthManagerTests -only-testing:nolonTests/ProviderUsageViewModelCLILoginTests`

## Phase 1.9：App 激活编排行为测试补齐

### BDD 场景
- Given runtime 切换失败但 auth 激活成功，When `confirmActivate()`，Then 不弹错误、清空 pending 并继续执行 reload。
- Given 激活流程抛错，When `confirmActivate()`，Then 保留 pending 并展示激活失败 alert。

### TDD（红 -> 绿）
- 为 `ProviderUsageViewModel` 增加可测试注入点（不改变默认行为）：
  - `codexActivateAction`
  - `postActivationLoadAction`
- 新增 app 侧测试：
  - `ProviderUsageViewModelActivationTests.testBDD_GivenRuntimeSwitchFailure_WhenConfirmActivate_ThenActivationContinuesAndReloadRuns`
  - `ProviderUsageViewModelActivationTests.testBDD_GivenActivationFailure_WhenConfirmActivate_ThenShowsActivationAlert`
- 修复测试并发与本地化断言：
  - `XCTAssert` 前先 `await` 取值，避免在 autoclosure 中 `await`
  - alert 文案改为使用 `NSLocalizedString` key 对齐中英文环境

### 验证
- `xcodebuild test -project nolon.xcodeproj -scheme nolon -destination 'platform=macOS' -only-testing:nolonTests/ProviderUsageViewModelActivationTests`
- `xcodebuild test -project nolon.xcodeproj -scheme nolon -destination 'platform=macOS' -only-testing:nolonTests/CodexAuthManagerTests -only-testing:nolonTests/ProviderUsageViewModelCLILoginTests -only-testing:nolonTests/ProviderUsageViewModelActivationTests`

## Phase 1.10：Usage parser 归约 API 统一（scanner 只消费 parser）

### BDD 场景
- Given `turn_context` 设置了 model，When 后续 `token_count` 未携带 model，Then 归约结果应回退到当前 model。
- Given 连续 `total_token_usage`，When 第二条到达，Then 应按上一次 totals 做差分。
- Given `cached_input_tokens > input_tokens`，When 产生当次增量，Then cached 增量应被 clamp 到 input 增量。
- Given `last_token_usage` 行，When 执行归约，Then 应返回本次增量且不覆盖累计 totals。

### TDD（红 -> 绿）
- 先补红灯：
  - `CodexSessionEventParserTests.reduceUsageLineForTokenDelta`
  - 期望新增 parser 统一归约入口：`reduceUsageLine(data:currentModel:previousTotals:)`
- 最小实现（绿灯）：
  - `CodexSessionEventParser` 新增：
    - `CodexSessionTokenTotals`
    - `CodexSessionTokenDelta`
    - `CodexSessionUsageReduction`
    - `reduceUsageLine(...)`
  - `CostUsageScanner.parseCodexFile` 删除本地 token 差分细节，改为消费 `reduceUsageLine` 结果：
    - 会话 id 收敛
    - model/totals 状态推进
    - token delta 落日聚合

### 验证
- `swift test --package-path libs/Providers --filter CodexSessionEventParserTests`
- `swift test --package-path libs/Providers --filter CostUsageStoragePathTests`
- `swift test --package-path libs/Providers --filter CostUsageFetcherTests`

## Phase 1.11：修复 JSONL EOF 最后一行扫描边界

### BDD 场景
- Given `rollout.jsonl` 最后一行没有 trailing newline，When 扫描 usage 文件，Then 最后一行 token 事件也应被计入聚合。

### TDD（红 -> 绿）
- 先补红灯：
  - `CostUsageStoragePathTests.costUsageScannerParsesLastLineWithoutTrailingNewline`
  - 期望无尾换行时仍能统计最后一条 `last_token_usage`。
- 最小实现（绿灯）：
  - `CostUsageJsonl.scan(...)` 在 EOF 且 `buffer` 非空时，先把残留 bytes 作为最后一行拼接，再统一 `flushLine()`。
  - 抽出 `appendLinePart(...)`，复用换行行与 EOF 残留行处理逻辑，保持 truncation 规则一致。

### 验证
- `swift test --package-path libs/Providers --filter CostUsageStoragePathTests`
- `swift test --package-path libs/Providers --filter CodexSessionEventParserTests`
- `swift test --package-path libs/Providers --filter CostUsageFetcherTests`

## Phase 1.12：UsageMonitor 环境拼装下沉到 ProviderUsage

### BDD 场景
- Given provider 为 codex，When 执行 usage 拉取，Then 运行环境应自动合并 managed binary env 并注入 `CODEX_CLI_PATH`。
- Given provider 非 codex，When 执行 usage 拉取，Then 使用基础环境且不注入 codex 专有变量。

### TDD（红 -> 绿）
- 先补库侧测试：
  - `ProviderUsageMonitorServiceTests.resolveCodexEnvironmentMergesManagedValues`
  - `ProviderUsageMonitorServiceTests.resolveNonCodexEnvironmentKeepsBase`
- 最小实现：
  - `ProviderUsageMonitorService` 内置 codex 环境解析：
    - `resolveEnvironmentForFetch(provider:)`
    - 默认通过 `CodexBinaryManager.shared` 读取 managed env 与 active cli path
  - `fetchOutcomes(...)` 统一使用解析后的环境创建 `ProviderFetchContext`
  - app 侧 `UsageMonitorService` 删除本地 codex 环境拼装，改为直接委托 `ProviderUsageMonitorService`

### 验证
- `swift test --package-path libs/Providers --filter ProviderUsageMonitorServiceTests`
- `swift test --package-path libs/Providers --filter ProviderUsageTokenAccountsTests`
- `swift test --package-path libs/Providers --filter ProviderUsageRegistryTests`
- `xcodebuild test -project nolon.xcodeproj -scheme nolon -destination 'platform=macOS' -only-testing:nolonTests/UsageMonitorServiceTests`

## Phase 1.13：Token account 默认路径规则下沉

### BDD 场景
- Given app 需要 token account 存储路径，When 读取默认路径，Then 应由 `ProviderUsage` 统一给出 `/Nolon/token-accounts.json` 规则。

### TDD（红 -> 绿）
- 先补红灯：
  - `ProviderUsageTokenAccountsTests.defaultTokenAccountsFilePathLayout`
  - 期望库侧存在 `ProviderUsagePaths.defaultTokenAccountsFileURL(baseDirectory:)`
- 最小实现（绿灯）：
  - `ProviderUsage.TokenAccounts` 新增 `ProviderUsagePaths`：
    - `defaultTokenAccountsFileURL(baseDirectory:)`
  - `UsageMonitorService.defaultTokenAccountsFileURL()` 改为委托 `ProviderUsagePaths`，删除 app 层重复路径拼装逻辑。

### 验证
- `swift test --package-path libs/Providers --filter ProviderUsageTokenAccountsTests`
- `swift test --package-path libs/Providers --filter ProviderUsageMonitorServiceTests`
- `xcodebuild test -project nolon.xcodeproj -scheme nolon -destination 'platform=macOS' -only-testing:nolonTests/UsageMonitorServiceTests`

## Phase 1.14：app 层去除 token path 静态桥接

### BDD 场景
- Given app 需要监听 token account 文件变更，When 构建 watcher 路径，Then 应直接依赖库侧 `ProviderUsagePaths`，不再经 app 层静态桥接。

### TDD（红 -> 绿）
- 依赖已有库侧路径测试：
  - `ProviderUsageTokenAccountsTests.defaultTokenAccountsFilePathLayout`
- 最小实现：
  - `ProviderUsageViewModel.updateUsageFileWatcher()` 改为直接使用 `ProviderUsagePaths.defaultTokenAccountsFileURL().path`
  - `UsageMonitorService` 初始化直接使用 `ProviderUsagePaths.defaultTokenAccountsFileURL()`
  - 删除 `UsageMonitorService.defaultTokenAccountsFileURL()` 静态桥接
  - `UsageMonitorServiceTests` 改为直接断言 `ProviderUsagePaths` 输出

### 验证
- `swift test --package-path libs/Providers --filter ProviderUsageTokenAccountsTests`
- `swift test --package-path libs/Providers --filter ProviderUsageMonitorServiceTests`
- `xcodebuild test -project nolon.xcodeproj -scheme nolon -destination 'platform=macOS' -only-testing:nolonTests/UsageMonitorServiceTests`

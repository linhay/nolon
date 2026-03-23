# Codex Runtime Refactor（2026-02-12）

## 背景
在完成 Codex CLI + app-server 全覆盖后，`libs/Providers` 内出现了多处重复实现：
- 二进制路径解析（`CODEX_CLI_PATH` / PATH / fallback）
- `CODEX_HOME` 推导
- account/rateLimits 的 RPC DTO 与 decode
- runtime service 生命周期（initialize/shutdown）

这会提高维护成本，也容易产生行为漂移。

## 本轮收敛
1. 统一路径与 home 解析
- 下沉到 `CodexCLIKit.CodexCommandExecutor`
- 新增 `codexHomeDirectoryURL` / `codexHomeDirectoryPath`

2. 统一 runtime account/rateLimits 协议模型
- 下沉到 `CodexAppServerKit`：
  - `CodexRuntimeRateLimitsSnapshot`
  - `CodexRuntimeRateLimitWindow`
  - `CodexRuntimeCreditsSnapshot`
- `CodexAccountRuntimeService` 增加 `readRateLimits()`

3. 删除 Provider 内重复 RPC 客户端
- 删除 `CodexProvider/CodexRPCClient.swift`
- `CodexHelper` 与 `CodexCreditsFetcher` 改为复用 `CodexAccountRuntimeService`

4. 提供 Provider 侧统一调用辅助
- 新增 `CodexRuntimeSupport`，统一：
  - `resolvedBinary(preferredBinary:environment:)`
  - `withRuntimeService(...)`

5. 消除构建噪音
- `Package.swift` 中 `Providers` target 增加 `exclude: ["Shared"]`
- 清除 `swift test` unhandled files 警告

## 行为边界
- 不改变外部 API 行为，仅做内部下沉与去重。
- 保持“RPC 优先，TTY 回退”的 credits 读取策略。
- 保持 app 层只负责编排，CLI/RPC 逻辑都在 `libs/Providers`。

## 验证
- `swift test --package-path libs/Providers`
- 全部通过（35 tests）。

## 后续建议
- 如果后续要支持更多 app-server 方法，优先在 `CodexAppServerKit` 增加 typed API，避免回到 Provider 层手工 JSON 解析。

## 增量（继续推进）
- `CodexLoginRunner` 可执行解析改为复用 `CodexCommandExecutor`，避免与 CLI 解析规则分叉。
- 新增测试 `CodexLoginRunnerTests`，覆盖 `CODEX_CLI_PATH` 优先级与 `CODEX_HOME` 注入行为。
- `CodexRuntimeAccountSwitcher` 改为先归一化解析 binary 再做 service cache key，减少同环境重复会话实例。

## 增量（switcher 可测试性）
- `CodexRuntimeAccountSwitcher` 引入内部 service 抽象与 factory 注入（public API 不变），用于隔离会话缓存逻辑测试。
- 新增 `CodexRuntimeAccountSwitcherTests`：验证同一 resolved binary 命中同一缓存 service，不重复初始化。
- 修正 `CodexRuntimeSupport.resolvedBinary`：优先通过 `CodexCommandExecutor` 解析（含 `CODEX_CLI_PATH` 规则），解析失败再回落 candidate。

## 增量（2026-02-12，继续推进）
- `CodexGeneratedFilesParser` 的 `response_item.custom_tool_call` / `custom_tool_call_output` 从字符串收窄改为 `CodexJSONValue`，避免结构化 payload 信息丢失。
- 新增测试 `CodexGeneratedFilesParserTests.parseRolloutCustomToolItems`，覆盖 structured input/output 解析。
- app 层 `URLSchemeHandler` 抽出 `normalizeIncomingURL(_:)` 纯函数，补齐 `URLSchemeHandlerTests`（nolon/nln -> https、query 保留、非目标 scheme 过滤）。
- 清理 app 层残留 `print()`，统一使用 `OSLog`（`URLSchemeHandler` / `AppDelegate`）。

## 增量（2026-02-12，STFilePath 下沉）
- `libs/Providers` 引入 `STFilePath` 依赖，作为 Codex 相关本地文件路径/读写的统一类型层。
- `FileTokenAccountStore` 内部从 `URL + FileManager` 读写切到 `STFile`（保留 `init(fileURL:)` 兼容入口，新增 `init(file:)`）。
- `CodexModelsCache` 新增 `load(from file: STFile)` 与 `load(from path: STPath)`，并移除重复 URL 读取分支。
- `CodexGeneratedFilesParser` 新增 `loadAllGeneratedFiles(codexHome: STFolder/STPath)` 与 `loadAuth/loadHistory/loadConfig/loadRollout` 的 STFolder 入口。
- `CodexGeneratedFilesParser` 内部文件存在判断、读取与 `sessions/**/*.jsonl` 扫描改为 STFilePath 实现（`STFolder.allSubFilePaths` + `STFile.data()`）。
- 新增/更新测试：
  - `ProviderUsageTokenAccountsTests.fileTokenAccountStoreSupportsSTFile`
  - `CodexModelsCacheTests.loadsFromSTFile`
  - `CodexGeneratedFilesParserTests.loadAllGeneratedFilesFromSTFolder`
  - `CostUsageStoragePathTests`（`CostUsageCacheIO` 的 STFolder cacheRoot 与 `CostUsageScanner.parseCodexFile(file: STFile)`）
- `CostUsageCacheIO` 新增 STFilePath 入口并保留 URL 兼容入口：
  - `cacheFile(provider:cacheRoot: STFolder?) -> STFile`
  - `load/save(..., cacheRoot: STFolder?)`
- `CostUsageScanner.Options` 的本地路径类型切换为 `STFolder?`，并增加 URL 兼容构造器：
  - `init(codexSessionsRootURL:cacheRootURL:forceRescan:)`
- `CostUsageScanner` 会话文件发现链路切到 STFilePath：
  - sessions root 列表使用 `STFolder`
  - 文件集合使用 `STFile`
  - 日期分区/平铺扫描使用 `STFolder.files(...)`

### 本轮验证
- `swift test --package-path libs/Providers`
- 全量通过（48 tests）。

## 增量（2026-02-12，STFilePath 下沉第三批）
- `CodexCLIKit.CodexCommandExecutor` 新增 STFilePath 入口：
  - `codexHomeDirectory(environment:) -> STFolder`
  - 旧入口 `codexHomeDirectoryURL/codexHomeDirectoryPath` 继续保留并转调。
- `CodexCommandExecutor` 的可执行文件判定改为 STFilePath（`STFile + permission`）链路，减少 `FileManager` 直接依赖。
- `CodexLoginRunner` 新增 `startLogin(..., codexHome: STFolder)`，旧 `URL` 入口保留兼容。
- `CodexHelper` 读取 models cache 改为 `STFolder.file("models_cache.json")` + `CodexModelsCache.load(from: STFile)`。
- 新增/更新测试：
  - `CodexCLIKitEnvironmentTests.codexHomeFolderOverride`
  - `CodexLoginRunnerTests.startLoginWithSTFolder`
- 验证结果：
  - `swift test --package-path libs/Providers --filter "(CodexCLIKitEnvironmentTests|CodexLoginRunnerTests|CodexModelsCacheTests)"`
  - `swift test --package-path libs/Providers`
  - 全量通过（50 tests）。

## 增量（2026-02-12，STFilePath 下沉第四批）
- `ProviderCatalog` 目标引入 STFilePath 依赖。
- `ProviderTemplate` 内部 home 基路径推导改为 `STFolder(NSHomeDirectory())`（外部 API 仍返回 URL，保持兼容）。
- `ProviderTemplateLoader` 资源 JSON 读取改为 `STFile(url).data()`。
- `ProvidersShared` 目标引入 STFilePath 依赖。
- `TTYCommandRunner` 本地可执行判定和 executableURL 组装改为 STFilePath：
  - `which` 的绝对路径分支改为 `STFile + permission`
  - `/usr/bin/which` 与运行时 binary 路径通过 `STFile(...).url` 传递给 `Process`
- 新增测试：
  - `ProviderCatalogTemplateTests`
  - `TTYCommandRunnerTests`
- 验证结果：
  - `swift test --package-path libs/Providers --filter ProviderCatalogTemplateTests`
  - `swift test --package-path libs/Providers --filter TTYCommandRunnerTests`
  - `swift test --package-path libs/Providers`
  - 全量通过（54 tests）。

## 增量（2026-02-12，STFilePath 下沉第五批）
- `ProviderCatalog.Provider` 新增 STFilePath 视图属性：
  - `path: STPath`
  - `additionalPaths: [STPath]`
- 保持 URL 兼容：
  - `pathURL` 与 `additionalPathURLs` 内部转调到 STPath 视图。
- `CodexAppServerSession` 的 app-server executable URL 组装改为 `STFile(...).url`。
- 新增测试覆盖：
  - `ProviderCatalogTemplateTests.providerPathViews`
- 验证结果：
  - `swift test --package-path libs/Providers --filter "(ProviderCatalogTemplateTests|CodexAppServerKitTests)"`
  - `swift test --package-path libs/Providers`
  - 全量通过（55 tests）。

## 增量（2026-02-12，STFilePath 下沉第六批 / 收口）
- `CostUsageCacheIO.defaultCacheRoot` fallback 从 `FileManager.default.urls(for: .cachesDirectory, ...)` 切换为 STFilePath 组合路径：
  - `~/Library/Caches/CodexBar`
- 新增测试：
  - `CostUsageStoragePathTests.costUsageCacheDefaultPathLayout`
- 验证结果：
  - `swift test --package-path libs/Providers --filter CostUsageStoragePathTests`
  - `swift test --package-path libs/Providers`
  - 全量通过（56 tests）。
- 结果检查：
  - `rg -n "FileManager|Data\\(contentsOf:|URL\\(fileURLWithPath:" libs/Providers/Sources`
  - 已无匹配，`libs/Providers/Sources` 的这批本地路径热点全部清零。

## 增量（2026-02-12，远程仓库识别/拉取/资源发现下沉）
- `ProviderCatalog` 新增 `RemoteGitRepositorySupport`（`libs/Providers/Sources/ProviderCatalog/RemoteGitRepositorySupport.swift`）：
  - Git URL 识别与规范化：`extractURLComponents / normalizeGitURL / extractSubpath / suggestedClonePath`
  - 远程拉取能力：`syncRepository(gitURL:localClonePath:accessToken:)`（clone/pull）
  - 资源发现能力：`detectSkillsDirectories(at:)`（覆盖 `libs/agent-skills` 风格目录）
- 新增测试：
  - `libs/Providers/Tests/ProvidersTests/RemoteGitRepositorySupportTests.swift`
- App 层复用下沉能力：
  - `nolon/Skills/Models/RemoteRepository.swift`
    - `localClonePath`、`normalizeGitURL`、`extractSubpath`、`extractURLComponents` 均改为委托 `RemoteGitRepositorySupport`
  - `nolon/Skills/Infrastructure/GitRepository.swift`
    - clone/pull/sync 与技能目录识别改为委托 `RemoteGitRepositorySupport`
    - 删除 app 层重复 Git URL 解析/SSH 检测/目录扫描实现
- 验证结果：
  - `swift test --package-path libs/Providers` 通过（60 tests）。
  - `xcodebuild -project nolon.xcodeproj -scheme nolon ... test` 与 `./build.sh` 在当前分支仍被既有依赖问题阻塞：
    - `Unable to find module dependency: 'ProviderCatalog'`
    - `Unable to find module dependency: 'ProviderUsage'`

## 增量（2026-02-28，STJSON JSON-RPC 协议校验接入）
- 背景：`JsonRPCKit` 之前对入站 `method` 消息仅做松散 JSON 解析，未执行 JSON-RPC 2.0 的严格 method 约束（例如 `rpc.*` 保留前缀）。
- 变更：
  - `libs/Providers/Package.swift`
    - `JsonRPCKit` target 新增 `STJSON` 依赖。
  - `libs/Providers/Package.resolved`
    - `STJSON` 从 `1.4.8` 升级到 `1.4.9`（引入 JSON-RPC 2.0 协议层）。
  - `libs/Providers/Sources/JsonRPCKit/JsonRPCLineProcessSession.swift`
    - 入站 `method` 消息先通过 `JSONRPC.decodeInbound(from:)` 做协议校验；
    - 通过 `JSONRPC.Request` 的 `params` 还原为现有 `Any` 结构，保持对外 API 不变。
- 测试：
  - 新增 `JsonRPCKitTests.reservedRPCPrefixNotificationIsIgnored`（先红后绿）；
  - 回归 `JsonRPCKitTests` + `CodexAccountRuntimeServiceTests` 全通过。

## 增量（2026-02-28，STJSON JSON-RPC 出站校验补齐）
- 在前一轮“入站 strict 校验”基础上，补齐出站 request/notify 的协议约束。
- `JsonRPCLineProcessSession.request/notify` 改为构造 `JSONRPC.Request` 后编码发送，统一遵循 JSON-RPC 2.0 method/params 规则。
- 新增测试：`JsonRPCKitTests.reservedRPCPrefixOutboundMethodIsRejected`（先红后绿）。
- 回归：`JsonRPCKitTests` + `CodexAccountRuntimeServiceTests` 全通过。

## 增量（2026-02-28，STJSON JSON-RPC 响应 strict 校验）
- `JsonRPCLineProcessSession` 的响应分支改为优先解码 `JSONRPC.Response`：
  - 校验 `jsonrpc == 2.0`、`result/error` 二选一约束；
  - 校验响应 `id` 与 pending request 一致。
- 非法响应（例如同时包含 `result` 与 `error`）会使对应 pending request 失败，不再静默透传到业务层。
- 新增测试：`JsonRPCKitTests.invalidResponseWithResultAndErrorIsRejected`（先红后绿）。

## 增量（2026-02-28，STJSON 参数编码收敛）
- `JsonRPCLineProcessSession.encodeParams(_:)` 从 `JSONSerialization` 切换为 `JSONRPC.Params` + `JSONEncoder`。
- 收益：
  - 避免 `JSONSerialization` 对 `AnyCodable`/`__SwiftValue` 的 ObjC 异常崩溃路径；
  - 统一 params 顶层约束（仅 object/array）。
- `decodeOutboundParams(_:)` 同步改为 `JSONDecoder` 直接解码 `JSONRPC.Params`，去除二次 `JSONSerialization` 解析。
- 新增测试：`JsonRPCKitTests.encodeParamsSupportsAnyCodablePayload`（先红后绿）。

## 增量（2026-02-28，server-request 回包 STJSON 化）
- 问题：`handleServerRequest` 回包仍使用 `JSONSerialization`，当 handler 返回 `AnyCodable` 时会触发 `Invalid type in JSON write (__SwiftValue)` 崩溃。
- 修复：
  - server-request 成功回包改为 `JSONRPC.Response(id:result:error:)` + `JSONRPC.encodeResponse(_)`；
  - 错误回包同样走 `JSONRPC.Response`（`error.code = -32000` custom）。
- 新增测试：`JsonRPCKitTests.serverRequestReplySupportsAnyCodablePayload`（先红后绿）。
- 结果：`JsonRPCKit` 端到端 request/response/notification/server-request 四条链路均有 STJSON 协议校验与编码覆盖。

## 增量（2026-02-28，移除 JsonRPCKit 入站分发中的 JSONSerialization）
- `handleIncomingLine` 从 `JSONSerialization` 字典分发改为：
  - 先解码轻量 envelope（`id/method`）做消息分流；
  - response 分支使用 `JSONRPC.Response` strict 解码；
  - request/notification 分支使用 `JSONRPC.decodeInbound` strict 解码。
- 兼容语义保持：`id: null` 的 method 消息仍按 notification 处理；`id: null` 的 response 忽略。
- 结果：`JsonRPCLineProcessSession.swift` 已无 `JSONSerialization` 直接调用。

## 增量（2026-02-28，JsonRPCKit 结构化错误）
- 新增 `JsonRPCSessionError`：
  - `transport` / `shutdown` / `invalidMessage` / `invalidParams` / `protocolViolation` / `invalidResponse`。
- `JsonRPCLineProcessSession` 关键抛错点改为结构化错误：
  - 出站 method 违规 -> `protocolViolation`
  - 无效 response -> `invalidResponse`
  - params 非 object/array -> `invalidParams`
  - 管道/启动问题 -> `transport`
  - 关停中断 pending -> `shutdown`
- 测试更新：`JsonRPCKitTests` 中违规 method 与无效 response 用例改为断言 `JsonRPCSessionError` case，而非字符串匹配。

## 增量（2026-02-28，CodexAppServerKit 错误分类透传）
- `CodexAppServerSession.mapError` 新增对 `JsonRPCSessionError` 的分类映射：
  - `transport` -> `protocolError("transport: ...")`
  - `shutdown` -> `protocolError("session_shutdown")`
  - `invalidMessage` -> `protocolError("invalid_message")`
  - `invalidParams` -> `protocolError("invalid_params: ...")`
  - `protocolViolation` -> `protocolError("protocol_violation: ...")`
  - `invalidResponse` -> `protocolError("invalid_response: ...")`
- 新增测试：`CodexAppServerKitTests.mapsProtocolViolationCategory`。
- 结果：上层在不改异常类型签名（仍为 `CodexCLIError`）前提下，获得稳定错误分类前缀，便于 CLI/UI 分支处理。

## 增量（2026-02-28，错误分类映射覆盖补齐）
- 在 `CodexAppServerKitTests` 补齐 error 分类映射覆盖：
  - `mapsInvalidParamsCategory`
  - `mapsInvalidResponseCategory`
  - `mapsProtocolViolationCategory`
- 目标：防止 `CodexAppServerSession.mapError` 后续改动导致分类前缀回退为非结构化字符串。

## 增量（2026-03-01，账号 runtime typed 错误 + STJSON decode 收敛）
- 背景：`CodexAccountRuntimeService` 仍以字符串 `protocolError` 抛错，且 `decodeResult` 仍依赖 `JSONSerialization`，上游难以稳定分流账号场景错误。
- 变更：
  - `libs/Providers/Sources/CodexAppServerKit/CodexAccountRuntimeService.swift`
    - 新增 `CodexAccountRuntimeServiceError`（`code + LocalizedError`）：
      - `unsupportedServerRequest`
      - `runtimeServiceDeallocated`
      - `loginStartMissingLoginID`
      - `loginStartMissingAuthURL`
      - `loginCompletedUnexpectedID`
      - `loginCompletedFailed`
      - `invalidPayload`
    - `startChatGPTLogin` / `awaitChatGPTLoginCompletion` / `decodeResult` 改为抛 typed 错误，不再拼字符串。
    - `decodeResult` 改为 `Any -> AnyCodable -> JSONEncoder/JSONDecoder`，移除 `JSONSerialization` 路径。
  - `libs/Providers/Package.swift`
    - `CodexAppServerKit` target 增加 `STJSON` 依赖（直接使用 `AnyCodable`）。
  - `libs/Providers/Sources/Providers/Codex/CodexRuntimeAccountSwitcher.swift`
    - 映射 `CodexAccountRuntimeServiceError -> CodexCLIError.protocolError("account/<code>: ...")`，保证分类码向上游保留。
  - `libs/Providers/Sources/ProviderUsage/CodexAuthRuntimeCoordinator.swift`
    - 对 `CodexCLIError.protocolError` / `recoverableFallback` 使用原始 message 透传，避免被 `localizedDescription` 包装后丢失分类码前缀。
- 测试（先红后绿）：
  - `CodexAccountRuntimeServiceTests.startChatGPTLoginMissingLoginIDThrowsTypedError`
  - `CodexRuntimeAccountSwitcherTests.mapsTypedServiceErrorIntoProtocolCategory`
  - `CodexAuthRuntimeCoordinatorTests.runtimeSwitchProtocolCategoryPreserved`
- 回归：
  - `swift test --package-path libs/Providers --filter "JsonRPCKitTests|CodexAccountRuntimeServiceTests|CodexAppServerKitTests/mapsInvalidParamsCategory|CodexAppServerKitTests/mapsInvalidResponseCategory|CodexAppServerKitTests/mapsProtocolViolationCategory|CodexRuntimeAccountSwitcherTests|CodexAuthRuntimeCoordinatorTests"`
  - 25 tests 通过。

## 增量（2026-03-01，account 负例契约测试 + 登录链路 E2E）
- 目标：补齐 `account/read`、`account/rateLimits/read` 的字段异常负例，并新增从登录到读取账号/配额的一条端到端场景测试。
- 新增测试（`CodexAccountRuntimeServiceTests`）：
  - `readAccountInvalidPayloadThrowsTypedError`
    - 当 `requiresOpenaiAuth` 返回错误类型（string）时，断言抛出 `CodexAccountRuntimeServiceError.invalidPayload(context: "account/read", ...)`。
  - `readRateLimitsInvalidPayloadThrowsTypedError`
    - 当 `rateLimits` 对象缺失时，断言抛出 `invalidPayload(context: "account/rateLimits/read", ...)`。
  - `endToEndLoginThenReadAccountAndRateLimits`
    - 覆盖 `initialize -> account/login/start -> account/login/completed -> account/read -> account/rateLimits/read` 完整链路。
- 小修：
  - 去除测试中的类型推断告警：`async let completion: Void = ...`。
- 回归：
  - `swift test --package-path libs/Providers --filter "CodexAccountRuntimeServiceTests|CodexAppServerKitTests/mapsInvalidParamsCategory|CodexAppServerKitTests/mapsInvalidResponseCategory|CodexAppServerKitTests/mapsProtocolViolationCategory|CodexRuntimeAccountSwitcherTests|CodexAuthRuntimeCoordinatorTests|JsonRPCKitTests"`
  - 28 tests 通过。

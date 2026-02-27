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

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

### 本轮验证
- `swift test --package-path libs/Providers`
- `xcodebuild -project nolon.xcodeproj -scheme nolon -destination 'platform=macOS' -only-testing:nolonTests/URLSchemeHandlerTests test`
- `./build.sh`

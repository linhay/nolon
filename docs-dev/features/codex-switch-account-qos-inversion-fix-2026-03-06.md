# Codex 切换账号 QoS 反转告警修复（2026-03-06）

## 背景
- 切换账号时触发 `Thread Performance Checker`：
  - `User-initiated` 线程等待 `Utility` 线程，出现 priority inversion 告警。
- 栈指向：
  - `CodexStatusProbe.fetch`
  - `CodexCommandExecutor.resolveExecutable`
  - `SKProcessRunner.resolveExecutableInUserShellSync`

## 目标
1. 账号切换链路不再在高优先级任务中调用同步 shell 解析。
2. 保持状态探测行为不变（找不到 codex 仍返回 `codexNotInstalled` 语义）。

## BDD 场景
1. Given 需要解析 codex 可执行路径，When 使用异步解析 API，Then 不应走同步 `resolveExecutableInUserShellSync`。
2. Given 可执行文件存在，When 调用异步必需解析，Then 返回可执行路径。
3. Given 可执行文件不存在，When 调用异步必需解析，Then 抛出 `executableNotFound`。

## 实现
- `CodexCommandExecutor` 新增：
  - `requireResolvedExecutableAsync() async throws -> String`
- `CodexStatusProbe.fetch()` 改为：
  - 先 `await requireResolvedExecutableAsync()`
  - 将 `CodexCLIError.executableNotFound` 映射为 `CodexStatusProbeError.codexNotInstalled`

## 测试
- 新增/更新：
  - `CodexCLIKitEnvironmentTests`
    - `async required resolver returns executable path`
    - `async required resolver throws when executable is missing`
- 结果：
  - 新增用例通过。
  - 全量 `swift test` 存在与本改动无关的既有失败（`NolonCoreCLIKitTests` 中 gemini doctor / plugin start 场景）。

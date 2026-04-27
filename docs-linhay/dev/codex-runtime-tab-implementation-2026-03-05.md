# Codex Runtime Tab 实现说明（2026-03-05）

## 关联需求
- `docs-linhay/spaces/codex-runtime-tab/README.md`

## 实现概览
- ProviderCatalog:
  - `codex.vendorTabs` 新增 `runtime`
  - `codexXcode.vendorTabs` 新增 `runtime`
- App 侧 Tab 枚举:
  - `ProviderContentTabType` 增加 `.runtime`
  - 增加 `tab.runtime` 本地化 key
  - 对 codex/codexXcode 增加运行时排序修正（分别插入到 usage/binary 后）
- 详情页内容:
  - `ProviderDetailGridView.tabContent` 增加 `.runtime -> CodexRuntimeTabView`
- Runtime UI:
  - 新增 `CodexRuntimeTabView`
  - 包含：刷新、诊断面板、进程行 Stop/Force、PID 日志区（刷新/复制/清空）
- Runtime 逻辑:
  - 新增 `CodexRuntimeTabViewModel`
  - 新增 `CodexRuntimeCLIService`（调用 `NolonCodexCLIServing`）
  - 新增 `CodexPIDSystemLogService`（通过 `log show --predicate processIdentifier == <pid>` 读取日志并裁剪）

## 关键实现决策
1. `statusProbe` 失败不阻断整体诊断：
   - 诊断快照允许 `probe` 为可选；
   - 失败时将错误落到 `probeWarning`，但 `auth/binary/runtime` 仍可返回。
2. 强制停止采用二次确认：
   - 避免误触 `SIGKILL`。
3. 日志错误局部化：
   - 日志拉取失败只写入 `logsErrorMessage`，不污染全局 alert。

## 测试与验证
- `xcodebuild -project nolon.xcodeproj -scheme nolon-app -destination 'platform=macOS' -only-testing:nolonTests/CodexRuntimeTabConfigurationTests -only-testing:nolonTests/CodexRuntimeTabViewModelTests -only-testing:nolonTests/CodexPIDSystemLogServiceTests test`
- 结果：`TEST SUCCEEDED`

## 增量更新（2026-03-06）
- 目标：支持 Runtime 进程列表自动探测增删（5 秒轮询）。
- 代码变更：
  - `CodexRuntimeTabViewModel`
    - 新增 `startProcessPolling()` / `stopProcessPolling()`
    - 新增 `pollProcessesOnly()`：仅轮询 `runtimeList`，不重复拉取 diagnostics
    - 轮询默认间隔 `5_000_000_000ns`
    - 选中 PID 被删除时自动切换到首个可用 PID，并刷新日志
  - `CodexRuntimeTabView`
    - 在 `.task(id: provider.id)` 启动轮询
    - 在 `.onDisappear` 停止轮询
- 新增测试：
  - `testBDD_GivenPollingEnabled_WhenRuntimeProcessesChange_ThenProcessesTrackAddRemove`
  - 使用短轮询间隔验证进程新增、删除后的列表更新行为

## 增量更新（2026-03-06，条目化诊断展示）
- 目标：将 `Provider/Accounts/Active/Running/Binary/Path Active/Executable/Hint` 从顶部汇总区移动到 `Runtime Processes` 的具体条目中。
- 代码变更：
  - `CodexRuntimeTabView`
    - 移除顶部 `diagnosticsSection`
    - 在进程条目展开态新增 `processDiagnosticsSection(process:)`
  - `CodexRuntimeTabViewModel`
    - 新增 `CodexRuntimeProcessDiagnosticField`
    - 新增 `processDiagnosticsRows(for:)`，统一构建条目级诊断字段
- 新增测试：
  - `testBDD_GivenDiagnosticsAndProcess_WhenBuildingProcessDiagnosticRows_ThenIncludesExpectedFields`

## 风险与后续
- 当前日志读取基于系统 `log show`，对历史窗口和权限有环境依赖。
- 后续可扩展：
  - runtime inspect/restart
  - 按 provider/session 聚合过滤日志

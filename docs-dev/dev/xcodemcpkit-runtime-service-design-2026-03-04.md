# XcodeMCPKit Runtime Service 设计（2026-03-04）

## 关联需求
- `docs-dev/features/xcodemcpkit-runtime-controls-2026-03-04.md`

## 设计摘要
1. 新增 `XcodeMCPKitRuntimeService` 管理会话内进程：
- 状态：idle/starting/running/stopping/failed
- 动作：refresh/start/stop
2. `PluginManagementViewModel` 注入运行服务并桥接状态给 UI。
3. UI 在插件卡片增加运行控制按钮与状态文案。

## 行为细节
1. 启动命令：`xcodemcpkit`（长期驻留的 HTTP/SSE 代理进程）。
2. stop 默认先 terminate，超时后 kill。
3. 进程异常退出转 failed 并展示错误摘要。
4. 插件安装状态由二进制探测决定：PATH 可执行文件中存在 `xcodemcpkit` 即 installed。
5. `installed_version.txt` 仅作为版本来源，不参与 installed 判定；当未安装时 UI 隐藏 Installed 版本。
6. 新增 `XcodeMCPKitInstallService`：调用 GitHub Releases API 选择 darwin 包，下载并解压后安装到 `~/.nolon/bin`。
7. 兼容旧产物命名：`xcode-mcp-proxy-server -> xcodemcpkit`，`xcode-mcp-proxy -> xcode-mcp-server`。
8. 安装后写回 `~/.nolon/plugins/xcodemcpkit/installed_version.txt` 与 `~/.nolon/mcps/xcodemcpkit.json`。
9. 升级流程复用安装服务：`Upgrade` 按钮触发 `installLatest()`，完成后 reload 刷新 upgrade 状态。

## 测试
1. `PluginManagementViewModelTests` 新增 start/stop/status 文案用例。

## 2026-03-04 App 侧对齐（CLI 语义同步）
1. Resource Center 内置 xcodemcpkit MCP 的 command 从 `xcode-mcp-proxy` 改为 `xcode-mcp-server`。
2. `XcodeMCPKitRuntimeService` 默认运行命令从 `xcode-mcp-proxy-server` 改为 `xcodemcpkit`。
3. 运行日志与 binary-not-found 提示文案同步改为 `xcodemcpkit`。
4. `ResourceCatalogGridViewModelTests` 断言同步更新为 `xcode-mcp-server`。
5. `PluginManagementViewModel` 新增 `binaryExistsProvider` 注入点，支持 TDD 验证 installed/版本显示分离语义。
6. 未安装主按钮行为从“打开 release 页面”改为“应用内安装并刷新状态”。
7. 升级按钮行为从“打开 release 页面”改为“应用内升级并刷新状态”。

## 验证
- `xcodebuild -project nolon.xcodeproj -scheme nolon-app -configuration Debug test -only-testing:nolonTests/ResourceCatalogGridViewModelTests -only-testing:nolonTests/PluginManagementViewModelTests`
- 结果：通过（12/12）。

## 2026-03-04 SKProcessRunner 化改造
1. 运行层从 `Foundation.Process` 迁移到 `SKProcessPipeSession`，避免 `task already launched` 类型生命周期错误。
2. `XcodeMCPKitRuntimeService` 内部新增 `XcodeMCPKitRuntimeSessioning` 抽象，默认实现为 `SKProcessPipeSession`。
3. start 路径：创建 session -> 状态置为 running -> 后台 `wait()` 监听退出。
4. stop 路径：
- 普通停止：`session.terminate()`
- 强制停止：`session.sendSignal(SIGKILL)`
- 轮询 `isRunning()`，超时后升级 SIGKILL。
5. 失败路径统一：
- `SKProcessRunError.nonZeroExit` 优先展示 stderr。
- 其余错误回退 `localizedDescription`。

## SKProcessRunner 依赖升级
1. 上游仓库：`linhay/SKProcessRunner`
2. 本次新增能力：`SKProcessPipeSession.isRunning()` 与 `sendSignal(_:)`。
3. 上游提交：`1512ca7`（已推送 master）。
4. 本仓库依赖更新：
- `libs/Providers/Package.swift` revision -> `1512ca7`
- `libs/Providers/Package.resolved` revision -> `1512ca731064b202981a9d862c5ee31c23d3eba1`

## 新增测试
1. `nolonTests/XcodeMCPKitRuntimeServiceTests.swift`
- 二进制缺失 -> failed
- start + stop -> running -> idle
- 非零退出 -> failed 且保留 stderr
2. 回归：
- `PluginManagementViewModelTests`
- `XcodeMCPKitInstallServiceTests`
- `XcodeMCPKitRuntimeServiceTests`

# Codex Provider 编排接入指南（App 层）

## 目标
确保 `nolon` app 层只做编排，不直接处理 Codex CLI / app-server / JSON-RPC 细节。

## 分层边界
1. `nolon`（App）：负责 UI 事件、流程编排、状态展示、错误映射。
2. `libs/Providers`：负责 Codex 二进制解析、进程生命周期、RPC 协议、生成文件解析。
3. 禁止 app 层直接读取 `~/.codex/*` 或直接调用 JSON-RPC。

## 推荐调用面
1. 账号与会话运行时：使用 `CodexAccountRuntimeService` / `CodexRuntimeAccountSwitcher`。
2. 生成文件解析：使用 `CodexGeneratedFilesParser.loadAllGeneratedFiles(codexHome:includeArchived:)`。
3. 二进制与环境解析：统一走 `CodexCommandExecutor` / `CodexRuntimeSupport`。

## BDD 验收场景
### 场景 1：读取本地 Codex 状态
- Given app 需要展示 Codex 账号/历史/配置/会话
- When app 调用 `loadAllGeneratedFiles`
- Then app 仅消费 typed snapshot，不感知文件格式细节

### 场景 2：运行时切换账号
- Given 当前已存在活跃 app-server 会话
- When app 发起账号切换
- Then 仅通过 runtime service 执行，不写 provider `auth.json`

### 场景 3：裁剪归档会话
- Given 页面只需活跃会话
- When app 调用 `loadAllGeneratedFiles(..., includeArchived: false)`
- Then 仅返回 `sessions` 下 rollout 文件

## 回归清单
1. `swift test --package-path libs/Providers`
2. `./build.sh`
3. 关键测试：`CodexGeneratedFilesParserTests`

## 变更守则
1. 若新增 Codex RPC 方法，先在 `libs/Providers` 增加 typed API，再开放 app 编排调用。
2. 若新增 `~/.codex` 文件类型，先补 parser + tests，再接入 UI。
3. 避免在 app 层复制任何 CLI 参数、路径解析或 JSON 结构字段。

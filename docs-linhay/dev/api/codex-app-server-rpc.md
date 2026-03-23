# Codex app-server RPC 契约（Nolon）

## 协议边界
- 传输：`stdin/stdout`。
- 编码：JSON-RPC 2.0。
- framing：一行一个 JSON（line-delimited）。
- 代码边界：
  - 通用 JSON-RPC 会话：`libs/Providers/Sources/JsonRPCKit/JsonRPCLineProcessSession.swift`
  - Codex typed 封装：`libs/Providers/Sources/CodexAppServerKit/`
  - app 层禁止直接做 RPC 细节解析。

## 初始化流程
1. 启动：`codex app-server`
2. 请求：`initialize`
3. 通知：`initialized`

说明：Nolon 通过 `CodexAppServerSession.initialize(clientName:clientVersion:experimentalApi:)` 完成握手。

## 核心方法（当前业务依赖）

### `account/login/start`
- 作用：运行时账号切换（不重启子进程）。
- 常用 params：
  - `type`: `chatgptAuthTokens`
  - `accessToken`: string
  - `chatgptAccountId`: string
  - `chatgptPlanType`: string (可选)
- 成功后期望通知：`account/updated`

### `account/read`
- 作用：读取当前账号状态。
- 常用 params：
  - `refreshToken`: bool（通常 `false`）

### `account/logout`
- 作用：登出当前 runtime 账号。

### `account/rateLimits/read`
- 作用：读取额度窗口与 credits 快照。

## 通知（当前重点）
- `account/updated`: 账号状态变化（切换成功信号）。
- `account/rateLimits/updated`: 额度变化。
- 其余通知（turn/item/thread 系列）目前作为会话过程信号，不作为账号切换成功判据。

## 服务端请求（Server Request）
- `account/chatgptAuthTokens/refresh`
- `item/commandExecution/requestApproval`
- `item/fileChange/requestApproval`
- `item/tool/call`
- `item/tool/requestUserInput`

说明：Nolon 目前对 server request 保持“可接入”能力；账号切换主链路不依赖这些请求完成。

## 错误语义
- JSON-RPC `error` 将映射为 `CodexCLIError.protocolError`。
- `waitForNotification` 超时同样映射为 `protocolError`，错误消息包含 method 与 timeout。
- 运行策略：
  - 账号切换链路：必须观测到 `account/updated` 才算成功。
  - 额度读取链路：允许 best-effort（失败不阻塞主 UI）。

## 类型契约来源
- 方法/通知/请求枚举：`CodexAppServerMethods.swift`
- 会话行为（start/request/notify/wait）：`CodexAppServerSession.swift`

## 兼容性约束
- 该文档代表 Nolon 当前“消费契约”，不是 Codex 官方完整协议镜像。
- 新增方法时，优先在 `CodexAppServerKit` 增加 typed API，再由上层调用。

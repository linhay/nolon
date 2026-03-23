# SKProcessRunner 能力缺口：非 PTY 双向长连接会话

## 背景
- 当前 `libs/Providers/Sources/JsonRPCKit/JsonRPCLineProcessSession.swift` 使用 `Process + Pipe` 与子进程做 JSON-RPC over stdio 通信。
- 该场景要求：
  1. 持续读取 stdout 按行解析；
  2. 持续写入 stdin；
  3. 能在会话生命周期内收发多轮消息（非一次性命令）。

## 现状
- `SKProcessRunner` 已有能力：
  - 一次性执行：`run / runSync / runPTY / runPTYSync`
  - 交互式 PTY 会话：`SKProcessPTYSession`
- `SKProcessRunner` 缺失能力：
  - 非 PTY（Pipe-based）的双向长连接会话 API。

## 为什么不能直接改用 PTY
- JSON-RPC stdio 协议期望“原始字节流（pipe）”语义。
- PTY 会引入终端层行为（回显、行规约、控制字符等），可能污染协议帧，存在兼容风险。

## 建议新增 API（草案）
- 新增 `SKProcessPipeSession`（命名可调整），能力与 `SKProcessPTYSession` 对齐：
  1. `init(_ payload: SKProcessPayload) throws`
  2. `var stdout: AsyncStream<Data> { get }`
  3. `func send(_ data: Data) async throws`
  4. `func closeStdin() async throws`
  5. `func wait() async throws -> SKProcessResult`
  6. `func terminate() async`
  7. `var pid: pid_t { get }`

## 验收标准（用于提 issue）
1. 能稳定承载 JSON line / JSON-RPC 双向通信（1000+ 往返）。
2. 不引入 PTY 字符污染。
3. 支持 timeout、非 0 退出码、stdout/stderr 分离。
4. 支持与当前 `SKProcessPayload` 环境/工作目录配置兼容。

## 当前项目处理策略
- 在 `Providers` 中，除 `JsonRPCLineProcessSession` 外，其它 shell 执行已统一迁移至 `SKProcessRunner`。
- `JsonRPCLineProcessSession` 暂保留 `Process` 实现，等待 `SKProcessRunner` 提供非 PTY 会话 API 后再迁移。

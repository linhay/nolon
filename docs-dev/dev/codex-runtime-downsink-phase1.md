# Codex Runtime 下沉 Phase 1（CLI）

## 背景
为 `nolon codex` 增加“运行中实例可观测/可终止”的最小闭环能力，首期仅交付 `list + stop`，避免一次性引入 `inspect/restart/logs` 复杂度。

## 命令

### 1. `nolon codex runtime list`
- 输出列：`PID | PPID | 运行时长 | Provider | 命令`
- 只展示与 Codex 相关进程（`codex` / `codex-app-server`）
- 默认按 `PID` 升序

### 2. `nolon codex runtime stop --pid <pid> [--force] [--timeout-seconds <n>]`
- 默认策略：先 `SIGTERM`
- 若在 `timeoutSeconds` 内未退出：升级 `SIGKILL`
- `--force`：直接 `SIGKILL`
- 防护：禁止 `pid <= 1`，禁止停止当前 `nolon` 进程

## 实现位置
- 命令定义：`libs/Providers/Sources/NolonCoreCLIKit/NolonCodexCommands.swift`
- 执行与输出：`libs/Providers/Sources/NolonCoreCLIKit/NolonCodexCLIExecutor.swift`
- Help 文本：`libs/Providers/Sources/NolonCoreCLIKit/NolonCodexCLIHelp.swift`
- 服务与运行时适配：`libs/Providers/Sources/NolonCoreCLIKit/NolonCodexCLI.swift`

## 测试
- Entrypoint：`libs/Providers/Tests/ProvidersTests/NolonCodexCLIEntrypointTests.swift`
  - 新增 runtime group/action help、路由、非法参数、unsupported action
- Service：`libs/Providers/Tests/ProvidersTests/NolonCodexCLIServiceTests.swift`
  - 新增 `runtime list` 过滤排序
  - 新增 `runtime stop` TERM→KILL 升级行为

## 已知边界
- Provider 识别仅做轻量 hint（从 command 文本推断）
- 仅支持本机进程层控制，不处理会话级语义（如“哪个会话正在执行某任务”）
- 不包含 `inspect/restart/logs`（放到后续 phase）

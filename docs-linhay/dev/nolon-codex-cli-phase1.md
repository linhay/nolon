# nolon Codex CLI Phase 1（ArgumentParser）

## 目标
- CLI 可执行统一为 `nolon`，不再兼容 `nolon-core`。
- `codex` 作为外部二进制，`nolon` 只做编排。
- 命令解析统一使用 `swift-argument-parser`，不再扩展自研参数解析。

## 范围
- `nolon codex auth list|status|activate|login`
- `nolon codex auth delete`
- `nolon codex binary list|current|install|use|available|switch|doctor`
- `nolon codex status probe`

## 实现要点
- `NolonCoreCLIKit` 新增 `NolonCodexCLI.swift`：
  - `NolonCodexCLIServing` 协议与 `NolonLiveCodexCLIService` 实现
  - `NolonCLIEntrypoint.execute(arguments:)` 统一 JSON 输出
  - 参数解析改为 `ParsableArguments`（ArgumentParser）
- `Package.swift`：
  - 新增依赖 `swift-argument-parser`
  - 新可执行：`nolon`（target: `NolonCLI`）
  - 删除 `NolonCoreCLI` target/product
- 新增执行入口：`Sources/NolonCLI/main.swift`
- 新增环境变量：`NOLON_HOME`
  - 用途：覆盖默认 `~/.nolon` 根目录，便于多项目隔离和测试沙盒。
  - 生效模块：`CodexAuthManager`、`CodexBinaryManager`。
  - 优先级：显式传入 `rootURL/nolonHomeURL` > `NOLON_HOME` > 默认 `~/.nolon`。
- rollout 事件兼容策略（`CodexGeneratedFilesParser`）：
  - 核心事件（token_count/user_message/agent_message/task_* 等）保持强类型解析。
  - codex schema 内其他 `event_msg.type` 统一映射为 `.known(type:payload:)`。
  - schema 外未知事件保留 `.other(type:payload:)`，避免解析中断。

## BDD 验收
1. Given `auth activate` 参数有效，When 执行命令，Then 路由到 auth 激活并返回 `codex.auth.activate`。
2. Given `--account-id` 非 UUID，When 执行命令，Then 返回结构化 `invalid_arguments`。
3. Given `binary install <version> --set-default`，When 执行命令，Then 路由安装并返回 `codex.binary.install`。
4. Given `status probe`，When 执行命令，Then 路由探测并返回 `codex.status.probe`。
5. Given `auth delete --account-id` 有效，When 执行命令，Then 删除本地快照并返回 `codex.auth.delete`。
6. Given `auth delete` 账号不存在，When 执行命令，Then 返回结构化业务错误 `codex_auth_account_not_found`。
7. Given `binary install <version>` 或 `binary use --version` 为空白字符串，When 执行命令，Then 返回 `invalid_arguments`。

## 测试与验证
- `swift test --package-path libs/Providers --filter NolonCodexCLIEntrypointTests`
- `swift test --package-path libs/Providers --filter NolonCodexCLIServiceTests`
- `swift test --package-path libs/Providers --filter 'NolonCoreCLIKitTests|NolonCodexCLIEntrypointTests'`
- `swift run --package-path libs/Providers nolon codex binary list`

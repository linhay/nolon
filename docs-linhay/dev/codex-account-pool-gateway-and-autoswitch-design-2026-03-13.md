# Codex 账号池统一网关与自动切号技术设计（2026-03-13）

## 目标
在保持 `nolon` app 层只做编排的前提下，为 Codex 账号池增加两条自动调度路径：
1. 本地 HTTP gateway 调度。
2. 非网关自动切号调度。

## 当前实现进度
### 已完成（2026-03-13 第一轮）
1. 在 `ProviderUsage` 落地非网关自动切号核心：
   - `CodexAutoSwitchConfig`
   - `CodexAutoSwitchState`
   - `CodexAutoSwitchCandidate`
   - `CodexAutoSwitchDecision`
   - `CodexAutoSwitchCoordinator`
2. 已落地最小状态持久化：
   - `CodexAutoSwitchStateStore`
   - 默认状态文件路径为 `~/.nolon/codex/auto-switch/state.json`
3. 已落地账号池适配层：
   - `CodexAutoSwitchService`
   - 负责从 `CodexAuthManager` 读取活跃账号、usage cache、auth summary，再委托 coordinator 决策
4. 已完成测试覆盖：
   - `CodexAutoSwitchCoordinatorTests`
   - `CodexAutoSwitchServiceTests`
5. 当前已验证规则：
   - disabled
   - threshold not reached
   - low quota switch
   - cooldown
   - skip relay
   - no candidate
   - 从现有 auth manager usage cache 构建候选并触发切号

### 已完成（2026-03-14 第二轮）
1. `ProviderUsageViewModel.performAutoRefresh()` 已接入 auto-switch 挂点。
2. 触发边界当前收敛为：
   - 仅 `Codex + multi account + auto refresh`
   - 仅在刷新当前活跃账号之后执行 auto-switch 判断
   - 若返回 `switched`，则立即执行一次 `reloadCodexFromDisk(refreshUsage: false)`，让 UI 跟上新的 active account
3. 新增 `CodexAutoSwitchSettingsStore`
   - 使用 `UserDefaults` 持久化 `CodexAutoSwitchConfig`
   - 默认 key：`nolon.codex.auto_switch.<provider.id>`
4. `ProviderUsageViewModel` 默认行为：
   - 从 `CodexAutoSwitchSettingsStore` 读取配置
   - 若 `enabled == true`，则构造 `CodexAutoSwitchService` 执行判断
   - 若 `enabled == false`，则跳过 auto-switch

### 已完成（2026-03-14 第三轮）
1. `ProviderUsageViewModel` 已新增 auto-switch 配置状态与更新入口：
   - `codexAutoSwitchConfig`
   - `setCodexAutoSwitchEnabled`
   - `setCodexAutoSwitchThresholdPercent`
   - `setCodexAutoSwitchMinimumCandidateRemainingPercent`
   - `setCodexAutoSwitchSkipRelay`
2. `ProviderUsageView` 已把 auto-switch 接入 Codex Usage 菜单：
   - 自动切号开关
   - 切号阈值菜单
   - 候选余量阈值菜单
   - 跳过 Relay 开关
3. 测试已补齐：
   - `CodexAutoSwitchSettingsStoreTests`
   - `CodexUsageTabPresentationTests` 新增 auto-switch 初始化/更新用例
4. 当前已验证：
   - `swift test --package-path libs/Providers --filter CodexAutoSwitch`
   - `xcodebuild build -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS'`
   - `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexUsageTabPresentationTests`

### 下一步
1. 为自动切号补 `events.jsonl` 事件日志与最近一次切号状态。
2. 增加 CLI 侧 `autoswitch status/enable/disable` 命令。
3. 开始 gateway 最小闭环：配置接管、HTTP server、基础调度。

## 分层边界
1. `nolon`（App）
   - 负责 UI 事件、开关、状态展示、错误映射。
   - 不直接实现 HTTP server、调度算法或上游 credential 转发。
2. `libs/Providers`
   - 负责 gateway server、scheduler、forwarder、state/log store、auto-switch coordinator。
   - 负责 Codex config patch / restore。
3. `NolonCoreCLIKit`
   - 负责 gateway / autoswitch 命令入口与输出。

## 新增模块
### `CodexGatewayKit`
新增 package target 与 product：
1. `CodexGatewayConfig`
2. `CodexGatewayConfigWriter`
3. `CodexGatewayStateStore`
4. `CodexGatewaySessionStore`
5. `CodexGatewayAccountPool`
6. `CodexGatewayScheduler`
7. `CodexGatewayCircuitBreaker`
8. `CodexGatewayScoringModel`
9. `CodexGatewayMetricsStore`
10. `CodexGatewayRequestLogStore`
11. `CodexGatewayForwarder`
12. `CodexGatewayServer`
13. `CodexGatewayControlService`
14. `CodexGatewayDiagnosticsService`

### Gateway HTTP 框架决策
1. Gateway 数据面统一使用 Vapor 实现。
2. 路由、请求解析、响应编码、测试基建优先复用 Vapor / XCTVapor。
3. 首期仅在 `CodexGatewayKit` 内引入 Vapor，不把该依赖扩散到 app 层。

### `ProviderUsage`
新增：
1. `CodexPoolManagementConfig`
2. `CodexAutoSwitchPolicy`
3. `CodexAutoSwitchDecision`
4. `CodexAutoSwitchCoordinator`
5. `CodexAutoSwitchEventStore`

## 统一配置模型
```swift
struct CodexPoolManagementConfig {
    var mode: Mode
    var gateway: GatewayConfig
    var autoSwitch: AutoSwitchConfig
}
```

### `mode`
1. `gateway`
2. `directAutoSwitch`
3. `directManual`

### `GatewayConfig`
1. `enabled`
2. `bindHost`
3. `port`
4. `autoPatchCodexConfig`
5. `stickySessionTTLSeconds`
6. `maxAccountSwitches`
7. `topK`
8. `weights`
9. `circuitBreakerFailureThreshold`
10. `circuitBreakerCooldownSeconds`
11. `excludedAccountIDs`

### `AutoSwitchConfig`
1. `enabled`
2. `thresholdPercent`
3. `minimumCandidateRemainingPercent`
4. `cooldownMinutes`
5. `skipRelayAccounts`
6. `checkTiming`

## 数据落位
### Gateway
目录：`~/.nolon/codex/gateway/`

文件：
1. `config.json`
2. `state.json`
3. `sessions.json`
4. `metrics.json`
5. `recent-errors.jsonl`
6. `recent-requests.jsonl`
7. `gateway.pid`
8. `logs/gateway.log`

### Auto-switch
目录：`~/.nolon/codex/auto-switch/`

文件：
1. `config.json`
2. `state.json`
3. `events.jsonl`

## 账号池快照
新增统一快照模型：
```swift
struct CodexPoolAccountSnapshot {
    let accountID: UUID
    let kind: CodexAuthSummary.CardKind
    let displayName: String
    let email: String?
    let priority: Int
    let concurrencyLimit: Int
    let forwardingMode: ForwardingMode
    let quotaSnapshot: UsageSnapshot?
    let lastSelectedAt: Date?
    let lastFailureAt: Date?
    let isSchedulable: Bool
    let unschedulableReason: String?
}
```

### 构建来源
1. 账号基础信息：`CodexAuthManager`
2. quota / credits 信息：`ProviderUsageMonitorService` 或现有 descriptor 输出缓存
3. 运行时统计：gateway metrics store

## Gateway 数据面
### 路由
1. `POST /v1/responses`
2. `POST /responses`
3. `GET /healthz`
4. `GET /gateway/status`
5. `GET /gateway/metrics`
6. `GET /gateway/recent-errors`
7. `GET /gateway/accounts`

### 请求流程
1. server 接收 HTTP 请求
2. 解析 session key
3. account pool 生成候选快照
4. scheduler 生成选择顺序
5. forwarder 对候选账号逐个尝试
6. 成功则写 metrics / request log / sticky session
7. 失败则按错误类型决定 failover 或终止

## Gateway Session Key
提取顺序固定：
1. `session_id`
2. `conversation_id`
3. `previous_response_id`
4. `prompt_cache_key`
5. 请求体规范化 hash

TTL：`3600` 秒。

## Gateway Scheduler
### 候选过滤
1. 账号存在且未禁用
2. 凭证完整
3. 非熔断
4. 当前并发未超限
5. 具备转发能力

### 选择顺序
1. Sticky hit
2. 打分
3. Top-K
4. 加权随机
5. 逐个尝试转发
6. Failover

### 评分因子
1. `priority`
2. `inFlightCount`
3. `waitingCount`
4. `errorRate`
5. `avgLatencyMs`
6. `stickyBonus`

### 默认权重
1. `priority = 0.30`
2. `load = 0.25`
3. `queue = 0.10`
4. `errorRate = 0.20`
5. `latency = 0.10`
6. `stickyBonus = 0.05`

### Failover
1. 单请求维护 `failedAccountIDs`
2. 若 forwarder 返回 `failoverable`，加入排除集并继续
3. 最多切换 `maxAccountSwitches`

### 熔断
1. 账号连续失败达到阈值后熔断
2. 熔断期内不再进入候选
3. 成功后清零失败计数

## Forwarder 设计
### 抽象
```swift
protocol CodexGatewayUpstreamAdapter {
    func supports(_ account: CodexPoolAccountSnapshot) -> Bool
    func forward(_ request: GatewayRequest, account: CodexPoolAccountSnapshot) async throws -> GatewayResponse
    func classify(_ error: Error) -> CodexGatewayErrorKind
}
```

### 三类实现
1. `OAuthForwarder`
2. `APIKeyForwarder`
3. `RelayForwarder`

### 错误分类
1. `unauthorized`
2. `quotaExceeded`
3. `upstreamRateLimited`
4. `upstreamOverloaded`
5. `networkFailure`
6. `invalidAccountConfig`
7. `terminalBadRequest`
8. `unknown`

## Config Patch / Restore
### 原则
1. 只 patch 受控键。
2. 保留未建模 TOML 内容。
3. 停止 gateway 时恢复旧值。

### 受控字段
实现中固定 patch 以下逻辑字段：
1. gateway `base_url`
2. gateway enabled marker
3. 兼容所需 provider / relay 基线配置

### 快照
在 `~/.nolon/codex/gateway/config.json` 中保存 patch 前的受控字段快照。

## 非网关自动切号
### 触发时机
1. 仅在 `gatewayEnabled == false`
2. 仅在 `autoSwitchEnabled == true`
3. 仅在 Codex usage 自动刷新完成后立即检查

### 触发条件
1. 当前活跃账号存在 quota window
2. 当前活跃账号 `primary.remainingPercent <= thresholdPercent`
3. 距离上次自动切号超过 `cooldownMinutes`

### 候选过滤
1. 排除当前账号
2. 排除无 quota 数据账号
3. 排除 quota 低于 `minimumCandidateRemainingPercent` 的账号
4. 排除 relay 账号（默认）
5. 排除当前不可调度账号

### 候选排序
1. quota 剩余比例更高优先
2. priority 更高优先
3. 最近更少被激活优先
4. accountID 稳定排序

### 执行动作
通过 `CodexAuthActivationCoordinator` 激活下一个账号。

### 事件记录
写入 `events.jsonl`：
1. `timestamp`
2. `fromAccountID`
3. `toAccountID`
4. `reason`
5. `currentRemainingPercent`
6. `targetRemainingPercent`
7. `triggerSource`

## App 编排边界
1. App 不直接读取 gateway JSONL 日志格式做业务判断。
2. App 只消费 typed snapshot：
   - `CodexGatewayStatusSnapshot`
   - `CodexGatewayMetricsSnapshot`
   - `CodexAutoSwitchEvent`
3. App 不直接实现调度、切号、转发。

## CLI 接入
新增命令组：
1. `nolon codex gateway ...`
2. `nolon codex autoswitch ...`

CLI 统一调用 `CodexGatewayControlService` 和 `CodexAutoSwitchCoordinator`，不复制业务逻辑。

## 测试矩阵
### 单元测试
1. scheduler
2. scoring model
3. sticky store
4. circuit breaker
5. metrics store
6. request log store
7. config patch/restore
8. auto-switch policy
9. auto-switch coordinator

### 集成测试
1. gateway start -> patch -> request -> stop -> restore
2. sticky hit
3. failover
4. 熔断冷却恢复
5. auto-refresh -> low quota -> auto-switch
6. cooldown 阻止重复切号

### 回归
1. `swift test --package-path libs/Providers`
2. `./build.sh`

## 实施顺序
1. 统一配置与账号池快照
2. Gateway scheduler / metrics / logs
3. Config patch / restore
4. HTTP gateway server 与三类 forwarder
5. Auto-switch policy 与 coordinator
6. CLI 接入
7. App 接入
8. 回归与 runbook

## 已完成（2026-03-14 第四轮）
### 自动切号可观测性
1. 新增 `CodexAutoSwitchEvent` 与 `CodexAutoSwitchStatusSnapshot`。
2. 新增 `CodexAutoSwitchEventStore`，把评估结果追加写入 `auto-switch/events.jsonl`。
3. 新增 `CodexAutoSwitchStatusStore`，把最近一次决策写入 `auto-switch/status.json`。
4. `CodexAutoSwitchService.evaluateAndSwitchIfNeeded` 现在会在决策完成后统一写入事件与最新状态。

### CLI 接入
1. 新增 `nolon codex autoswitch status`
2. 新增 `nolon codex autoswitch enable`
3. 新增 `nolon codex autoswitch disable`
4. `NolonLiveCodexCLIService` 新增自动切号状态读取与开关写入能力，复用 `CodexAutoSwitchSettingsStore` 和 `CodexAutoSwitchStatusStore`。

### 本轮测试
1. 新增 `libs/Providers/Tests/ProvidersTests/CodexTests/CodexAutoSwitchEventStoreTests.swift`
2. 更新 `libs/Providers/Tests/ProvidersTests/CodexTests/CodexAutoSwitchServiceTests.swift`
3. 更新 `libs/Providers/Tests/ProvidersTests/NolonCodexCLIEntrypointTests.swift`
4. 更新 `libs/Providers/Tests/ProvidersTests/NolonCodexCLIServiceTests.swift`，覆盖 `status/enable/disable` 的真实落盘与读取

### 验证命令
1. `swift test --package-path /Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers --filter CodexAutoSwitch`
2. `swift test --package-path /Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers --filter 'ProvidersTests.NolonCodexCLIEntrypointTests/(codexAutoSwitchHelpPrintsHelp|codexAutoSwitchStatusRoutesSuccessfully|codexAutoSwitchEnableRoutesSuccessfully|codexAutoSwitchDisableRoutesSuccessfully)'`
3. `swift test --package-path /Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers --filter 'ProvidersTests.NolonCodexCLIServiceTests/(autoSwitchEnablePersistsSettings|autoSwitchDisablePersistsSettings|autoSwitchStatusReadsPersistedSnapshot)'`

## 下一步
1. 给 `autoswitch status` 增加最近事件列表与更完整的文本渲染。
2. 开始 Gateway 最小闭环：本地 HTTP server、配置接管、基础转发。
3. 给 `autoswitch status` 增加最近事件列表，避免用户必须手读 JSONL。

## 已完成（2026-03-14 第五轮）
### Gateway 控制层
1. `CodexGatewayKit` 新增 `CodexGatewayStateStore`，把 gateway 运行状态持久化到 `~/.nolon/codex/gateway/state.json`。
2. `CodexGatewayKit` 新增 `CodexGatewayControlService`，当前提供最小控制面：
   - `status`
   - `start`
   - `stop`
3. `start/stop` 当前先落真实状态快照，不在这一轮直接托管长生命周期 listener；这一层为后续 Vapor daemon 生命周期接入提供稳定边界。

### CLI 接入
1. 新增 `nolon codex gateway status`
2. 新增 `nolon codex gateway start`
3. 新增 `nolon codex gateway stop`
4. `NolonLiveCodexCLIService` 已接入 `CodexGatewayControlService`，CLI 现在可以读取和修改 gateway 状态快照。

### Vapor 路由骨架
1. `CodexGatewayServer` 已用 Vapor 暴露：
   - `GET /healthz`
   - `GET /gateway/status`
2. 这保证了后续接入真正转发链路时，不需要再推翻当前 HTTP 骨架。

### 本轮测试
1. 更新 `libs/Providers/Tests/ProvidersTests/CodexTests/CodexGatewayKitTests.swift`
2. 更新 `libs/Providers/Tests/ProvidersTests/NolonCodexCLIEntrypointTests.swift`
3. 更新 `libs/Providers/Tests/ProvidersTests/NolonCodexCLIServiceTests.swift`

### 验证命令
1. `swift test --package-path /Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers --filter CodexGatewayKitTests`

## 已完成（2026-03-14 第八轮）
### Gateway Daemon 生命周期
1. 新增 `CodexGatewayPIDStore`，把 daemon pid 持久化到 `~/.nolon/codex/gateway/gateway.pid`。
2. `nolon codex gateway start` 现在不再只是 patch 配置和写状态，而是：
   - patch `config.toml`
   - 后台拉起 `nolon codex gateway serve`
   - 保存 pid
   - 轮询 `GET /healthz` 等待 gateway 变健康
3. `nolon codex gateway stop` 现在会：
   - 读取 pid
   - 先发 `SIGTERM`
   - 超时后升级为 `SIGKILL`
   - 清理 pid 文件
   - restore `config.toml`
4. `gateway status` 现在会对 pid 做存活校验；若 pid 已失效，会自动把状态回落为 `stopped`。

### Gateway Serve 行为
1. 新增内部子命令 `nolon codex gateway serve`。
2. `serve` 使用 Vapor 真正启动本地 listener，而不是只写状态快照。
3. 当前 `serve` 启动后会接入真实 live handler：
   - `CodexGatewayAccountSource`
   - `CodexGatewayResponsesRoutingService`
   - `CodexGatewayResponsesForwarder`
4. 因此当前最小闭环已经成立：
   - `start`
   - 后台启动 Vapor daemon
   - `/healthz`
   - `/gateway/status`
   - `/v1/responses`
   - `stop`

### 当前边界
1. daemon 生命周期已经落地。
2. sticky 与最小 failover 已接到 live routing path。
3. 目前仍未加入：
   - sticky TTL 持久化
   - 请求级 metrics
   - 动态评分
   - 账号级实时 in-flight 统计
4. 环境路径语义已明确：
   - gateway `config.toml` 跟随 `HOME`
   - gateway `state.json` / `gateway.pid` / auth snapshot 跟随 `NOLON_HOME`
   - 因此 CLI smoke / 集成测试必须同时设置 `HOME` 与 `NOLON_HOME`

### 本轮测试
1. 更新 `libs/Providers/Tests/ProvidersTests/NolonCodexCLIServiceTests.swift`
2. 更新 `libs/Providers/Tests/ProvidersTests/NolonCodexCLIEntrypointTests.swift`
3. 更新 `libs/Providers/Tests/ProvidersTests/CodexTests/CodexGatewayKitTests.swift`

### 验证命令
1. `swift test --package-path /Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers --filter NolonCodexCLIServiceTests`
2. `swift test --package-path /Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers --filter NolonCodexCLIEntrypointTests`
3. `swift test --package-path /Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers --filter CodexGateway`

## 已完成（2026-03-14 第八轮）
### Gateway 最小上游转发层
1. 新增 `CodexGatewayResponsesForwarder`
2. 新增 `CodexGatewayUpstreamTransporting`，把真实 HTTP 发送与请求构造解耦
3. 新增默认实现 `CodexGatewayURLSessionTransport`
4. 当前 forwarder 已覆盖：
   - 上游 URL 拼接
   - POST 方法
   - request body 透传
   - `session_id` / `conversation_id` header 透传
   - upstream status / response body / content-type 映射

### 当前边界
1. 现在已经有真正的“request context -> upstream HTTP request -> gateway response”最小转发层。
2. 还没有接账号池调度；当前 forwarder 仍是单上游目标。
3. 下一步只需要在 forwarder 前面加 selector，就能把单上游演进成账号池调度。

### 本轮测试
1. 更新 `libs/Providers/Tests/ProvidersTests/CodexTests/CodexGatewayKitTests.swift`
2. 新增 `CodexGatewayResponsesForwarder` 请求构造与响应映射测试

### 验证命令
1. `swift test --package-path /Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers --filter CodexGatewayKitTests`
2. `swift test --package-path /Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers --filter 'ProvidersTests.NolonCodexCLIEntrypointTests/(codexGatewayHelpPrintsHelp|codexGatewayStatusRoutesSuccessfully|codexGatewayStartRoutesSuccessfully|codexGatewayStopRoutesSuccessfully)'`
3. `swift test --package-path /Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers --filter 'ProvidersTests.NolonCodexCLIServiceTests/(gatewayStartPersistsStatus|gatewayStopReadsPersistedSnapshot|gatewayStatusReturnsDefaultSnapshot)'`

## 已完成（2026-03-14 第九轮）
### Gateway 调度内核
1. 新增 `CodexGatewayCandidate`
2. 新增 `CodexGatewayScheduler`
3. 当前首版调度规则固定为：
   - 先过滤 `isSchedulable == false`
   - 再过滤已打满并发的候选
   - 按 `priority` 升序
   - 同优先级按 `inFlightCount` 升序
   - 再按 `lastSelectedAt` 做 LRU
   - 最后按 `accountID` 做稳定 tie-break
4. 当前还没有接真实账号池指标写回，但调度行为已经被独立测试锁定。

### Gateway Handler 适配层
1. 新增 `CodexGatewayResponsesRoutingService`
2. 它把 `scheduler + candidate provider + forwarder` 组合成真正可注入的 `responsesHandler`
3. 当前能力：
   - 从候选集中选出上游账号
   - 将请求转发到被选中的 `upstreamBaseURL`
   - 没有可路由候选时返回 `503 service unavailable`
4. 这一步之后，gateway 已经从“固定单上游转发”演进为“可调度的多上游 handler 骨架”

### 当前边界
1. 调度器现在还是纯内核，尚未接 `CodexAuthManager` 和真实账号使用中指标。
2. 尚未实现 sticky session、failover、error classification。
3. 但 HTTP 入口、配置接管、最小上游转发、基础调度已经能拼成完整的数据面主干。

### 本轮测试
1. 新增 `libs/Providers/Tests/ProvidersTests/CodexTests/CodexGatewaySchedulerTests.swift`
2. 覆盖：
   - 无候选
   - 并发打满过滤
   - `priority` 选择
   - `inFlightCount` 选择
   - `lastSelectedAt` LRU
   - 稳定 tie-break
   - routing service 选择上游并转发
   - 无可路由候选返回 `503`

### 验证命令
1. `swift test --package-path /Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers --filter CodexGateway`

## 已完成（2026-03-14 第十轮）
### 基于 Codex 源码的一手上游映射
1. 直接参考 `references/codex` 中的 `responses-api-proxy`、`core/src/api_bridge.rs`、`core/src/model_provider_info.rs`
2. 确认了 gateway 需要遵循的真实行为：
   - API Key / proxy：`Authorization: Bearer <key>`
   - ChatGPT 账号：`Authorization: Bearer <access_token>` + `ChatGPT-Account-ID`
   - provider `base_url` 是模型提供方级配置，不是固定只认 `api.openai.com`
3. 因此 gateway 不再假设单一 OpenAI 上游，而是按账号类型解析真实上游 base URL 与固定 header

### Gateway 真实账号源
1. 新增 `CodexGatewayAccountSource`
2. 它直接从 `CodexAuthManager` 读取：
   - `~/.nolon/codex/auth/*.json`
   - `nolon.usage_cache`
   - relay metadata
3. 当前已能映射三类候选：
   - `officialAPIKey` -> `https://api.openai.com`
   - `relayProfile` -> `nolon.relay.base_url`
   - `chatgptAccount` -> `https://chatgpt.com/backend-api/codex`
4. 这一步让 gateway 从“测试假数据候选”进入“真实账号快照候选”

### Forwarder 语义修正
1. `CodexGatewayResponsesForwarder` 新增固定 `upstreamHeaders`
2. 新增 `/v1` path 归一化：
   - 若上游 `base_url` 已是 `/v1`
   - 当前请求又是 `/v1/responses`
   - 则转发时归一化为 `/responses`
3. 这个行为是为了对齐 Codex 自身 provider 的 `base_url + /responses` 组合方式，避免 `/v1/v1/responses`

### 当前边界
1. 账号源已经能解析真实上游和认证 header。
2. 但 routing service 还没有直接接 `CodexGatewayAccountSource`，当前只是具备可接入能力。
3. sticky / failover / error classification 仍未实现。

### 本轮测试
1. 更新 `libs/Providers/Tests/ProvidersTests/CodexTests/CodexGatewayKitTests.swift`
2. 新增覆盖：
   - `/v1` path 归一化
   - API Key 账号映射
   - Relay 账号映射
   - ChatGPT 账号映射

### 验证命令
1. `swift test --package-path /Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers --filter CodexGatewayKit`
2. `swift test --package-path /Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers --filter CodexGateway`

## 已完成（2026-03-14 第十二轮）
### Live Routing Sticky + Failover
1. `CodexGatewayResponsesRoutingService` 新增最小 `sticky session` 机制
2. sticky key 当前优先使用：
   - `session_id`
   - `conversation_id`
3. 当 sticky 已绑定且候选仍可调度时，会先尝试命中该账号，而不是重新走优先级排序

### Failover 规则
1. 当前把以下响应视为可切换错误：
   - `429`
   - `5xx`
   - transport error / throw
2. 若命中可切换错误且还有剩余候选：
   - 移除当前候选
   - 清理 sticky 旧绑定
   - 继续尝试下一个账号
3. 若后续候选成功：
   - 用成功账号重新绑定 sticky

### 当前边界
1. 这是最小 sticky/failover，不含 TTL 和持久化。
2. 还没有错误分类统计、请求级 metrics、并发占用回写。
3. 但 live handler 已经具备最核心的会话粘性和失败切换能力。

### 本轮测试
1. 更新 `libs/Providers/Tests/ProvidersTests/CodexTests/CodexGatewaySchedulerTests.swift`
2. 新增覆盖：
   - sticky 命中优先于更高排序候选
   - 5xx failover 到下一账号
   - failover 后重新绑定 sticky

### 验证命令
1. `swift test --package-path /Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers --filter CodexGatewayScheduler`
2. `swift test --package-path /Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers --filter CodexGateway`

## 已完成（2026-03-14 第十一轮）
### Live Routing 入口
1. `CodexGatewayResponsesRoutingService` 新增基于 `CodexGatewayAccountSource` 的初始化入口
2. 现在可以直接：
   - 从 `CodexAuthManager` 读取真实账号
   - 生成 gateway candidates
   - 经过 scheduler 选路
   - 进入 forwarder 发起真实上游请求
3. 这意味着 gateway 侧已经具备“真实账号池 -> 路由 handler”的闭环，不再要求上层自己手动组装 candidate closure

### 当前边界
1. 这一轮解决的是 live 组合问题，不是策略增强问题。
2. sticky session、failover、错误分类、请求级 metrics 仍未接入 live handler。
3. 但真实账号源、基础调度、真实 header 注入、真实上游路径已经连成一条链路。

### 本轮测试
1. 更新 `libs/Providers/Tests/ProvidersTests/CodexTests/CodexGatewayKitTests.swift`
2. 新增 `live account source -> routing service -> forwarder` 闭环测试

### 验证命令
1. `swift test --package-path /Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers --filter CodexGatewayKit`
2. `swift test --package-path /Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers --filter CodexGateway`

## 已完成（2026-03-14 第六轮）
### Gateway 配置接管
1. 新增 `CodexGatewayConfigManager`，负责对 `config.toml` 做受控 patch / restore。
2. 当前受控 key：
   - `base_url`
   - `model_provider`
   - `cli_auth_credentials_store`
3. patch 策略：
   - 只修改顶层受控 key
   - 保留非受控 key
   - 保留已有 section 内容
4. restore 策略：
   - 按保存的原值恢复受控 key
   - 若 `config.toml` 是 patch 临时创建且恢复后为空，则删除该文件

### Gateway CLI 行为变化
1. `nolon codex gateway start` 现在会先 patch `config.toml`，再写入 running 状态。
2. `nolon codex gateway stop` 现在会先 restore `config.toml`，再写入 stopped 状态。
3. 因此 gateway 控制面现在已经不是“仅状态模拟”，而是具备真实配置接管闭环。

### 本轮测试
1. 更新 `libs/Providers/Tests/ProvidersTests/CodexTests/CodexGatewayKitTests.swift`
2. 更新 `libs/Providers/Tests/ProvidersTests/NolonCodexCLIServiceTests.swift`

### 验证命令
1. `swift test --package-path /Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers --filter CodexGatewayKitTests`
2. `swift test --package-path /Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers --filter 'ProvidersTests.NolonCodexCLIServiceTests/(gatewayStartPersistsStatus|gatewayStopReadsPersistedSnapshot|gatewayStatusReturnsDefaultSnapshot)'`

## 已完成（2026-03-14 第七轮）
### Gateway HTTP 数据面入口
1. `CodexGatewayServer` 新增：
   - `POST /v1/responses`
   - `POST /responses`
2. 当前路由层会提取：
   - request path
   - request body
   - `session_id` header
   - `conversation_id` header
3. 路由层不直接写死上游转发逻辑，而是先通过可注入 `responsesHandler` 交给后续 forwarder / scheduler 层处理。

### 当前边界
1. HTTP 数据面入口已连通。
2. 真实账号池调度与上游转发还未接入。
3. 这一步的目标是先稳定路由边界与 request context 结构，避免后续 forwarder 落地时反复改 Vapor surface。

### 本轮测试
1. 更新 `libs/Providers/Tests/ProvidersTests/CodexTests/CodexGatewayKitTests.swift`
2. 新增 `/v1/responses` 与 `/responses` alias 的路由测试

### 验证命令
1. `swift test --package-path /Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers --filter CodexGatewayKitTests`

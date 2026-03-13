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

### 下一步
1. 把 `CodexAutoSwitchService` 接入实际 usage 自动刷新链路。
2. 增加配置存储与 CLI/App 开关入口。
3. 为自动切号补 `events.jsonl` 事件日志与 UI 展示。

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

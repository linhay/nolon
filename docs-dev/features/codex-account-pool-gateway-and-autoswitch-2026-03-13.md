# Codex 账号池统一网关与自动切号（2026-03-13）

## 背景
当前 Nolon 已经具备 Codex 多账号存储、手动激活、运行时切号和用量拉取能力，但还缺少两类自动调度能力：
1. 统一 HTTP 网关模式：把 Codex 请求统一转发到本地网关，再由网关从账号池中选择账号。
2. 非网关自动切号模式：不启用统一网关，但当当前活跃账号余量低到临界值时，自动切换到下一个仍有余量的账号。

## 目标
1. 为 Codex 账号池提供可配置的自动调度能力。
2. 支持两种互斥模式：
   - `gateway`：统一 HTTP 网关调度
   - `directAutoSwitch`：非网关自动切号
3. 统一使用 Nolon 管理的 Codex 账号库（`~/.nolon/codex/auth/*.json`）作为调度来源。
4. App 与 CLI 都能查看状态、控制启停和诊断结果。

## 范围
1. 统一 HTTP 网关：
   - 本地 HTTP gateway daemon
   - Codex 配置切到 gateway relay 模式
   - `POST /v1/responses` 与 `POST /responses`
   - `GET /healthz`、`GET /gateway/status`、`GET /gateway/metrics`
   - Sticky session
   - 负载均衡
   - Failover
   - 熔断
   - 动态评分
   - 最近错误与请求日志
2. 非网关自动切号：
   - 基于 usage 自动刷新后的 quota 结果判断
   - 直接自动切到下一个有余量账号
   - 记录自动切号事件
3. 控制面：
   - CLI：`nolon codex gateway ...` 与 `nolon codex autoswitch ...`
   - App：Codex Runtime/Usage 入口中的状态、配置和诊断区块

## 非目标
1. 不实现 RPC server。
2. 不实现 JSON-RPC 网络服务。
3. 不扫描任意外部 `CODEX_HOME` 或散落 `auth.json`。
4. 不做跨机器或远程部署。
5. 不自动漂移端口。

## 模式定义
### 模式 A：统一网关
1. 所有 Codex 流量先进入本地 HTTP gateway。
2. Gateway 从账号池中选择账号并转发。
3. Gateway 模式开启时，非网关自动切号逻辑不生效。

### 模式 B：非网关自动切号
1. 不启用统一网关。
2. 保持当前“直接使用已激活账号”的行为。
3. 在 usage 自动刷新完成后，若当前活跃账号 quota 剩余比例低于阈值，则自动切换到下一个符合条件的账号。

## 默认决策
1. 两种模式互斥。
2. Gateway 只监听 `127.0.0.1`。
3. 非网关自动切号的触发指标使用“额度窗口剩余比例”。
4. 非网关自动切号在“自动刷新完成后立即检查”。
5. 达到阈值时直接自动切号，不弹确认。
6. 只要当前存在 gateway 模式，自动切号禁用。

## 账号支持矩阵
1. OAuth：支持统一 HTTP 网关调度，也支持非网关自动切号。
2. Official API Key：支持统一 HTTP 网关调度；非网关自动切号是否可切，取决于该账号是否有 quota/credits 数据。
3. Relay：支持统一 HTTP 网关调度；默认不参与非网关自动切号候选，除非后续显式放开。

## 调度规则
### Gateway 模式
1. 候选过滤：
   - 凭证完整
   - 当前未熔断
   - 当前未超并发
   - 具备当前转发能力
2. 调度顺序：
   - Sticky hit
   - 评分排序
   - Top-K
   - 加权随机
   - Failover
3. 评分因子：
   - priority
   - in-flight
   - queue
   - error rate
   - latency
   - sticky bonus

### 非网关自动切号
1. 仅在 gateway 关闭时生效。
2. 当前活跃账号的 primary quota remaining percent 低于阈值时才触发。
3. 候选账号按以下顺序选择：
   - quota 剩余比例更高
   - priority 更高
   - 最近更少被激活
4. 若没有满足最低余量阈值的候选，则不切号，仅记录事件。

## BDD 验收
1. Given 至少存在一个可用 Codex 账号，When 启动 gateway，Then Codex 配置被切到本地 gateway endpoint，后续请求通过 gateway 转发。
2. Given gateway 已运行且存在多个候选账号，When 连续发送无会话锚点请求，Then 请求按评分和负载规则分散到多个账号，而不是固定命中同一账号。
3. Given 同一会话第一次命中账号 A，When 后续相同会话继续请求，Then 默认继续命中账号 A。
4. Given 首选账号失败且错误可 failover，When 仍有剩余候选，Then gateway 自动切到下一账号并继续请求。
5. Given 某账号连续失败达到熔断阈值，When 新请求到达，Then 该账号在冷却窗口内不再进入候选。
6. Given gateway 已接管配置，When 停止 gateway，Then daemon 停止且 Codex 配置恢复到接管前状态。
7. Given gateway 关闭且自动切号开启，When usage 自动刷新后当前活跃账号 quota 剩余比例低于阈值，Then 系统自动激活下一个有余量账号。
8. Given 自动切号 cooldown 未到，When 当前账号再次低于阈值，Then 不重复切号，并记录跳过原因。
9. Given 所有候选账号都没有足够余量，When 当前账号低于阈值，Then 不切号，仅写入“无可用候选”事件。
10. Given App 或 CLI 查询状态，When gateway 运行或发生自动切号，Then 返回一致的状态、指标和最近错误/事件摘要。

## CLI 命令面
1. Gateway：
   - `nolon codex gateway start`
   - `nolon codex gateway stop`
   - `nolon codex gateway status`
   - `nolon codex gateway logs`
   - `nolon codex gateway doctor`
2. Auto-switch：
   - `nolon codex autoswitch status`
   - `nolon codex autoswitch enable`
   - `nolon codex autoswitch disable`
   - `nolon codex autoswitch doctor`

## App 入口
1. 在 Codex Runtime 区新增 Gateway 管理区块。
2. 在 Codex Usage 或 Runtime 区新增 Auto-switch 管理区块。
3. 必须展示：
   - 当前模式
   - gateway host/port
   - 是否已接管配置
   - 活跃账号数
   - sticky session 数
   - 最近错误
   - 最近自动切号事件

## 测试要求
1. `swift test --package-path libs/Providers`
2. `./build.sh`
3. 定向测试至少覆盖：
   - gateway scheduler
   - gateway server
   - config patch/restore
   - auto-switch policy
   - auto-switch coordinator

## 完成定义
1. 文档、实现与运行时行为一致。
2. Gateway 与非网关自动切号两种模式均可独立验证。
3. 控制面与数据面状态一致。
4. 有意义的切换、失败和诊断信息可追踪。

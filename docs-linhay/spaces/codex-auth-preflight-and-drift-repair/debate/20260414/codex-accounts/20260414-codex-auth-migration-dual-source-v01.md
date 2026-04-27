# 争论背景

当前讨论的问题是：当用户在安装 Nolon 之前，已经在外部 Codex 环境中使用“自定义 `base_url` + API key”完成配置时，Nolon 安装后的首次接管/迁移，是否可以仅依赖 `auth.json` 自动生成正确的账号卡片。

现场约束已经明确：

- 不是环境变量场景。
- 凭据来源是 `auth.json`。
- 自定义 provider 配置来源是 `config.toml`。
- 目标不是单纯“把 API key 读出来”，而是要生成正确的账号类型与元数据：
  - `officialAPIKey`
  - 或 `relayProfile`

争论点在于：

1. 现有迁移链路是否已经覆盖“外部自定义 base URL + API key”。
2. 如果没有，缺口到底是在 `auth.json` 识别，还是在 `config.toml` 联动。
3. debate 阶段应先收敛出什么结论，才能指导后续实现。

# 参与者观点

## 第 1 轮

### 观点 A（TraceForge）：当前实现只解决了“凭据收编”，没有完整解决“自定义 provider 重建”

- 现有 `preflightManagedAuthIfNeeded(...)` 确实会接管 provider 下已有的 `auth.json`。
- 当 provider `auth.json` 不是软链时，会走 `reconcileProviderAuthWithSnapshotsIfNeeded(...)`，把现有认证写回 snapshot/SQLite，再重建软链。
- 但这条路径的主输入只有 provider `auth.json` 内容本身。

代码依据：

- `libs/Providers/Sources/ProviderUsage/CodexAuthManager.swift`
  - `preflightManagedAuthIfNeeded(...)`
- `libs/Providers/Sources/ProviderUsage/CodexAuthManager+ProviderSync.swift`
  - `reconcileProviderAuthWithSnapshotsIfNeeded(...)`
  - `upsertSnapshotFromProviderData(...)`

核心判断：

- 这条链路可以把“外部已有账号”收进来。
- 但如果外部账号是“自定义 base URL + API key”，只读 `auth.json` 并不能还原完整 provider 语义。

### 观点 B（用户侧主张）：这个场景本质上就是双源配置，必须同时读两份文件

- `auth.json` 负责凭据：
  - `OPENAI_API_KEY`
- `config.toml` 负责 provider 配置：
  - 顶层 `model_provider`
  - `[model_providers.<id>]`
  - `base_url`
  - 可能还包括 `http_headers` / `query_params`

如果只读 `auth.json`：

- 最多知道这是一个 `apikey`
- 不知道它是不是 relay/custom provider
- 也不知道它属于哪个 `model_provider`
- 更拿不到外部自定义 `base_url`

因此该场景下“生成账号”必须是：

- `auth.json` 提供凭据真值
- `config.toml` 提供 provider 真值

### 观点 C（TraceForge）：当前 `config.toml` 逻辑是“同步层”，不是“迁移输入层”

当前代码里，`config.toml` 相关逻辑主要用于：

- 当激活 relay API key 账号时，把配置 patch 到 `config.toml`
- 当切回 OAuth / 官方 API key 时，恢复原始 `config.toml`
- 当账号快照里已有 relay `base_url`，但缺少 `model_provider` 时，尝试从 `config.toml` 反推 provider id 并回写快照

代码依据：

- `libs/Providers/Sources/ProviderUsage/CodexAuthManager+ActiveProviderConfig.swift`
  - `syncActiveProviderConfig(...)`
  - `activeProviderConfigIntent(...)`
  - `relayConfig(...)`
  - `inferManagedProviderID(...)`

这说明：

- `config.toml` 已经被纳入“账号激活后的托管同步”链路
- 但还没有进入“首次接管外部账号时的原始资料拼装”链路

## 第 2 轮

### 观点 D（TraceForge）：当前自动收编会把该场景降级成普通 `apikey` 账号

`normalizeAccountPayloadData(...)` 的职责是：

- 给 payload 补 `nolon.account.id`
- 补 `createdAt/updatedAt`
- 根据已有 JSON 推导 `kind`

但它不会主动额外读取 `config.toml`。

代码依据：

- `libs/Providers/Sources/ProviderUsage/CodexAuthManager+SnapshotHelpers.swift`
  - `normalizeAccountPayloadData(...)`
  - `deriveAccountKind(from:)`

现有 `deriveAccountKind(from:)` 的前提是：

- payload 自己已经带着 `nolon.relay`
- 或 payload 自己已经带着 `base_url`

对于“外部已有 custom provider，但信息分散在两份文件里”的场景：

- `auth.json` 里往往只有 `OPENAI_API_KEY`
- `config.toml` 才有 `model_provider/base_url`

那么当前 preflight 收编后，大概率只会得到：

- `auth_mode = apikey`
- `kind = officialAPIKey`

而不是正确的：

- `kind = relayProfile`
- `nolon.relay.base_url = ...`
- `nolon.relay.model_provider = ...`

### 观点 E（用户侧主张）：这不是“增强体验”，而是“纠正迁移正确性”

这个点不应被描述成“后续可以优化”。

原因：

- 如果用户外部实际使用的是 custom relay provider
- Nolon 却把它导成 `officialAPIKey`

那后续一系列行为都会偏掉：

- 卡片类型错误
- 显示名错误
- `config.toml` patch / restore 语义错误
- 可能触发错误的 quota/usage 逻辑

所以这是“迁移输入不完整导致账号语义错误”，不是纯 UI 优化。

## 第 3 轮

### 对比结论：现有实现已经具备“单源 auth 接管”，但缺失“多源配置重建”

两边并不矛盾：

- 现有实现不是完全没有迁移逻辑
- 但也确实还没完整覆盖“外部 custom provider + API key”这个子场景

可以把问题拆成两层：

1. 已解决：
   - provider `auth.json` 的发现、收编、snapshot 化、SQLite 化、软链接管
2. 未解决：
   - 当 provider 语义分散在 `auth.json + config.toml` 时，首次接管阶段缺少双读拼装

### 最终判断：自定义 `base_url + API key` 的首次迁移必须双读

当前 debate 收口如下：

- 对于官方 API key：
  - 单读 `auth.json` 可以成立
- 对于外部 custom relay / 自定义 base URL：
  - 单读 `auth.json` 不足
  - 必须同时读取 `config.toml`

也就是说，迁移阶段的真实输入模型应是：

- `auth.json`：凭据层
- `config.toml`：provider 配置层
- 合成后的 payload：Nolon 内部账号层

# 代码依据

- 自动接管入口：
  - `libs/Providers/Sources/ProviderUsage/CodexAuthManager.swift`
  - `preflightManagedAuthIfNeeded(...)`

- detached auth 收编：
  - `libs/Providers/Sources/ProviderUsage/CodexAuthManager+ProviderSync.swift`
  - `reconcileProviderAuthWithSnapshotsIfNeeded(...)`
  - `upsertSnapshotFromProviderData(...)`

- payload 归一化：
  - `libs/Providers/Sources/ProviderUsage/CodexAuthManager+SnapshotHelpers.swift`
  - `normalizeAccountPayloadData(...)`
  - `deriveAccountKind(from:)`

- `config.toml` 同步与推断：
  - `libs/Providers/Sources/ProviderUsage/CodexAuthManager+ActiveProviderConfig.swift`
  - `syncActiveProviderConfig(...)`
  - `relayConfig(...)`
  - `inferManagedProviderID(...)`

# 结论与行动项

## 当前结论

1. 现有实现已经支持从外部 `auth.json` 自动接管账号。
2. 但当用户使用的是“自定义 `base_url + API key`”时，现有迁移链路缺少对 `config.toml` 的首次拼装读取。
3. 因此该场景下，当前行为存在把 relay/custom provider 误降级为普通 `officialAPIKey` 的风险。
4. 这个问题属于“迁移正确性缺口”，不是可有可无的体验优化。

## 建议行动项

1. 在首次接管/迁移路径中，为 `apikey` 场景补充双读逻辑：
   - 先读 provider `auth.json`
   - 再读同目录 `config.toml`
2. 当 `config.toml` 中存在：
   - 顶层 `model_provider`
   - 对应 `[model_providers.<id>]`
   - 以及有效 `base_url`
   时，合成 `nolon.relay` 元数据后再进入 `normalizeAccountPayloadData(...)`
3. 补两条回归测试：
   - Given 外部已有 `auth.json + config.toml` 的 custom relay API key，When 首次 preflight，Then 生成 `relayProfile`
   - Given 外部仅有官方 API key，When 首次 preflight，Then 仍生成 `officialAPIKey`

# 设计方案

## 设计目标

在不改变现有 OAuth / 官方 API key 正常路径的前提下，补齐“外部自定义 `base_url + API key`”首次接管时的账号重建能力。

目标结果：

1. 若外部 Codex 当前账号是官方 API key：
   - 继续按现状生成 `officialAPIKey`
2. 若外部 Codex 当前账号是 relay / custom provider API key：
   - 在首次 preflight 后直接生成 `relayProfile`
   - snapshot 中补齐：
     - `base_url`
     - `nolon.relay.base_url`
     - `nolon.relay.model_provider`
     - `nolon.relay.headers/query_params`（若能从 `config.toml` 稳定解析）

## 非目标

1. 不在本轮支持从“任意外部 `CODEX_HOME`”扫描散落配置。
2. 不在本轮把 `config.toml` 变成独立账号导入入口。
3. 不在本轮改造已有账号编辑器 UI。
4. 不在本轮处理 gateway 虚拟账号或多 provider 批量导入。

## 总体思路

把当前的“单读 provider `auth.json` 收编”升级为“有条件双读”：

1. 先读取 provider `auth.json`
2. 若判定是 OAuth：
   - 保持现状，不读取 `config.toml` 参与账号生成
3. 若判定是 `apikey`：
   - 再尝试读取同目录 `config.toml`
   - 从中解析当前激活的 provider 配置
4. 若 `config.toml` 能稳定证明这是 relay/custom provider：
   - 先把 relay 元数据合成进 payload
   - 再进入现有 `normalizeAccountPayloadData(...)`
5. 若 `config.toml` 不存在或无法稳定解析：
   - 保守回退为现有行为
   - 即仍按普通 `officialAPIKey` 收编

这样可以保证：

- 官方 API key 路径不受影响
- 只有在证据充分时，才把账号升级为 `relayProfile`

## 落点设计

### 1. 新增“外部 provider 配置解析结果”模型

建议在 `CodexAuthManager+ActiveProviderConfig.swift` 或同域 support 文件新增只读模型：

```swift
struct ExternalCodexProviderConfig {
    enum Kind {
        case official
        case relay
    }

    let kind: Kind
    let providerID: String?
    let baseURL: String?
    let queryParams: [String: String]
    let httpHeaders: [String: String]
}
```

用途：

- 只表达“从 `config.toml` 读取到的当前 provider 真相”
- 不直接承担 patch / restore 语义

### 2. 新增只读解析入口

建议新增方法：

```swift
func resolveExternalProviderConfig(for provider: Provider) -> ExternalCodexProviderConfig?
```

解析来源：

- `config.toml`

解析规则：

1. 读取顶层 `model_provider`
2. 若为空：
   - 视为官方 provider
3. 若存在：
   - 在 `[model_providers.<id>]` 中查找对应 section
   - 读取 `base_url`
   - 可选读取 `http_headers` / `query_params`
4. 只有当以下条件同时满足，才认定为 relay：
   - `model_provider` 非空
   - 匹配 section 存在
   - `base_url` 非空

否则回退为：

- `official`

### 3. 在 preflight 收编路径里插入“payload 合成层”

当前关键入口：

- `reconcileProviderAuthWithSnapshotsIfNeeded(...)`
- `upsertSnapshotFromProviderData(...)`

建议新增中间步骤：

```swift
func mergedProviderAuthPayload(
    authData: Data,
    provider: Provider
) throws -> Data
```

流程：

1. 先解析 `auth.json`
2. 若不是 `apikey`：
   - 直接返回原始 data
3. 若是 `apikey`：
   - 调用 `resolveExternalProviderConfig(for:)`
4. 如果返回 `.relay`：
   - 在内存中把以下字段写回 payload：
     - 顶层 `base_url`
     - `nolon.account.kind = relayProfile`
     - `nolon.relay.base_url`
     - `nolon.relay.model_provider`
     - `nolon.relay.query_params`
     - `nolon.relay.headers`
5. 如果返回 `.official` 或解析失败：
   - 不写 relay 元数据
   - 维持原样

然后把这个 merged payload 继续传给：

- `upsertSnapshotFromProviderData(...)`
- `normalizeAccountPayloadData(...)`

### 4. 复用现有 `config.toml` 解析能力，避免双套语义漂移

当前 `CodexAuthManager+ActiveProviderConfig.swift` 已有：

- `parseManagedProviderConfig(...)`
- `modelProviderSectionID(from:)`
- `quotedAssignmentValue(from:key:)`

建议：

1. 尽量复用这套字符串级 parser
2. 但把“用于激活同步”的 intent 判定，与“用于首次迁移识别”的只读解析拆开

原因：

- 激活同步关注“如何 patch / restore”
- 首次迁移关注“当前 provider 到底是什么”
- 两者读的是同一份文件，但职责不同

## 迁移判定规则

### Case 1: 官方 API key

输入：

- `auth.json` 有 `OPENAI_API_KEY`
- `config.toml` 不存在 relay provider section

输出：

- `officialAPIKey`

### Case 2: 自定义 relay API key

输入：

- `auth.json` 有 `OPENAI_API_KEY`
- `config.toml` 有：
  - `model_provider = "provider-relay"`
  - `[model_providers.provider-relay]`
  - `base_url = "..."`

输出：

- `relayProfile`
- 并把 relay 元数据补进 snapshot

### Case 3: `config.toml` 存在但信息不完整

输入：

- `auth.json` 有 `OPENAI_API_KEY`
- `config.toml` 有 `model_provider`
- 但 section 缺失或 `base_url` 缺失

输出：

- 保守回退 `officialAPIKey`

原因：

- 避免基于不完整证据误判 relay

### Case 4: OAuth / ChatGPT

输入：

- `auth.json` 有 token 对

输出：

- 完全沿用现有逻辑
- `config.toml` 不参与账号类型生成

## 为什么不反过来只信 `config.toml`

因为 `config.toml` 只表达“当前 CLI/provider 选择的模型 provider 配置”，不表达凭据本身：

- 没有 `OPENAI_API_KEY`
- 也不保证当前 provider 一定仍可用

所以账号迁移的真源必须是：

- 凭据从 `auth.json` 来
- provider 配置从 `config.toml` 来

而不是二选一。

## 风险与防御

### 风险 1：用户的 `config.toml` 已被污染

例如：

- 顶层 `model_provider` 指向 relay
- 但当前 `auth.json` 实际是官方 API key

防御：

- 仅在 `auth.json` 明确是 `apikey` 时才尝试结合 `config.toml`
- 即使如此，也必须要求 `base_url` 有效才判定 relay

### 风险 2：同一 `config.toml` 里存在多个 provider section

这本来就是正常情况。

真正要读的是：

- 顶层 `model_provider` 当前指向的那个 section

不是盲扫所有 section 并猜一个最像的。

### 风险 3：把历史官方账号误升级成 relay

防御：

- 没有 `base_url` 就绝不升级
- `model_provider` 存在但 section/base_url 缺失时，严格回退

## BDD 草案

1. Given provider 目录已有 `auth.json`，其中只有 `OPENAI_API_KEY`，且 `config.toml` 当前为 relay provider
   When 执行 `preflightManagedAuthIfNeeded(...)`
   Then 新生成的 snapshot 账号类型为 `relayProfile`

2. Given provider 目录已有 `auth.json`，其中只有 `OPENAI_API_KEY`，且 `config.toml` 当前为官方 provider
   When 执行 `preflightManagedAuthIfNeeded(...)`
   Then 新生成的 snapshot 账号类型为 `officialAPIKey`

3. Given provider 目录已有 `auth.json`，其中只有 `OPENAI_API_KEY`，且 `config.toml` 有 `model_provider` 但缺失对应 `base_url`
   When 执行 `preflightManagedAuthIfNeeded(...)`
   Then 新生成的 snapshot 账号类型仍为 `officialAPIKey`

4. Given provider 目录已有 OAuth `auth.json`
   When 执行 `preflightManagedAuthIfNeeded(...)`
   Then 账号生成逻辑不读取 `config.toml` 参与账号类型判断

## 实现顺序建议

1. 先补 debate/feature 结论，确认“迁移阶段必须双读”的产品语义
2. 在 `CodexAuthManager` 补只读 `config.toml` 解析模型
3. 在 detached auth 收编前补 merged payload 步骤
4. 先补 3 条最小回归测试：
   - relay apikey 双读成功
   - 官方 apikey 保持官方
   - 不完整 relay 配置回退官方
5. 最后再考虑是否把这套双读能力复用到“导入当前 auth.json”或“手动导入文件”路径

## 第 4 轮

### 多 Agent 第一轮交叉验证

本轮引入 3 个子代理并行审视同一问题，分别从“迁移正确性”“保守风控”“最小实现路径”三个维度交叉论证：

- `RelayPurist`
- `FallbackGuard`
- `MigrationPragmatist`

### RelayPurist：双读不是优化，是恢复 relay 语义的必要条件

- 论点：
  - 当前 `preflightManagedAuthIfNeeded(...) -> reconcileProviderAuthWithSnapshotsIfNeeded(...) -> upsertSnapshotFromProviderData(...) -> normalizeAccountPayloadData(...)` 这一整条首次接管链路只消费 `auth.json`
  - `normalizeAccountPayloadData(...)` 与 `deriveAccountKind(from:)` 只能基于 payload 现有字段推导账号类型
  - 若 payload 中没有 `nolon.relay`，最终只能收敛到 `officialAPIKey`
- 推导：
  - 外部 custom provider 的 `base_url/model_provider` 真值在 `config.toml`
  - 若首次迁移不双读，这些真值根本进不到 payload
  - 结果就是被错误降级成普通 `officialAPIKey`

### FallbackGuard：可以接受双读，但 `config.toml` 只能是只读证据源

- 论点：
  - 当前 `config.toml` 已经承担“激活后 patch/restore”的同步职责
  - 如果在迁移阶段把它升级成新的写入源，会污染现有 `CodexActiveProviderConfigManager` 的状态边界
- 主要风险：
  - 多个 `[model_providers.*]` 同时存在时误判
  - gateway / 手工修改 / 历史残留配置导致错误继承
  - 迁移误写 `config.toml` 破坏 restore 基线
- 可接受条件：
  - 迁移阶段只读 `config.toml`
  - 一旦不唯一或证据不足，立即回退 `auth-only`

### MigrationPragmatist：最小切入点应在 `reconcileProviderAuthWithSnapshotsIfNeeded(...)`

- 论点：
  - 不需要引入新持久化层
  - 不需要新异步任务
  - 最小增量是在 provider payload 进入 `resolvePreferredSourceCandidate(...)` 前，先做一次“只读拼装”
- 建议：
  - 在 `CodexAuthManager+ProviderSync.swift` 里新增 helper
  - 输入：
    - `auth.json` 原始 payload
    - 可选 `config.toml`
  - 输出：
    - 一个 merged payload
  - merged payload 之后继续复用现有 `normalize/upsert/SQLite` 链路

### 第一轮收敛结论

- 三方已经达成第一层共识：
  - 当前实现确实存在“外部 custom provider + API key 被误降级”的风险
  - 解决它需要双读
  - 但双读必须限定为“只读拼装”，不能顺手进入 `config.toml` 写入

## 第 5 轮

### 多 Agent 第二轮反驳与边界收紧

第二轮把两边约束互相施压，验证设计是否还能成立：

- 支持派必须回答：
  - 在接受严格 guardrails 后，是否仍坚持双读
- 保守派必须回答：
  - 在承认 `auth-only` 会误降级的前提下，最小可接受 dual-read 版本是什么
- 工程派必须回答：
  - 最终边界、helper 形态、payload 合成策略到底该怎么落

### RelayPurist 第二轮：仍坚持双读，但只接受“临时真值拼装”

- 立场收敛：
  - 仍坚持双读是必须的
  - 但只接受把 `config.toml` 作为一次性的 truth layer
  - 不接受迁移阶段写回 `config.toml`
- 提出的最小触发条件：
  - `auth.json` 为 `apikey`
  - 当前 payload 尚未包含 `nolon.relay`
  - `config.toml` 能唯一解析出 `model_provider + base_url`
- 提出的回退条件：
  - `config.toml` 不存在、不可读、为空
  - provider 不唯一
  - `base_url/model_provider` 非法或明显污染
  - 与现有 `nolon.relay` 冲突

### FallbackGuard 第二轮：承认双读必要，但要求“只读且带 relay 明确信号”

- 可接受的最小版本：
  - 只在有足够 relay 证据时读取 `config.toml`
  - 一旦不能证明是 relay，就必须回退 `auth-only`
- 绝对禁止项：
  - 在迁移阶段 patch/rewrite `config.toml`
  - 用迁移推断结果去污染 `CodexActiveProviderConfigManager` 的 state
- 最低测试门槛：
  - 唯一 relay 命中时成功生成 `relayProfile`
  - 多 provider 歧义时保持 `officialAPIKey`
  - 官方账号 + 残留 relay config 时不得误升级

### MigrationPragmatist 第二轮：helper 应输出 merged payload，不新增新状态机

- 最终边界：
  - 双读仅发生在 `reconcileProviderAuthWithSnapshotsIfNeeded(...)` 的 provider payload 处理点
  - `config.toml` 仅作只读证据源
  - 无法唯一确定 relay 时直接保持原 payload
- helper 设计建议：
  - 新增类似 `mergeProviderPayloadWithRelayConfig(...)`
  - 输入：
    - provider
    - `auth.json` `Data/String`
    - 可选 `config.toml`
  - 输出：
    - merged `Data/String`
- payload 方案选择：
  - 倾向复用 `makeConfiguredAccountPayload(...)`
  - 但它必须保证仅用于生成 merged payload，不意味着要进入“新建 configured account”那套外部语义

### 第二轮收敛结论

- 双读方案在严格边界下仍然成立
- 真正要避免的不是“双读本身”，而是：
  - 把 `config.toml` 从只读证据源变成写入源
  - 在歧义条件下强行推断 relay
- 因此最终可执行边界被收敛为：
  - 迁移阶段允许双读
  - 但只允许只读、唯一、可证明的 relay 证据参与 payload 合成
  - 任何不确定性都必须回退到现有 `auth-only` 路径

## 最终收口

经过两轮多 Agent 反复讨论，当前 debate 最终收口如下：

1. 业务结论：
   - “外部自定义 `base_url + API key` 首次迁移必须双读 `auth.json + config.toml`”成立
2. 安全边界：
   - `config.toml` 在迁移阶段只能是只读证据源，不能成为写入源
3. 触发条件：
   - 仅 `apikey` 场景允许尝试双读
   - 仅当 `model_provider + base_url` 唯一且可证明时才合成 relay payload
4. 回退策略：
   - 任何歧义、缺失、污染、冲突，全部回退 `auth-only`
5. 工程落点：
   - 最小实现应插在 `reconcileProviderAuthWithSnapshotsIfNeeded(...)` 的 provider payload 读取后
   - 通过 helper 生成 merged payload
   - 后续继续复用现有 `normalize -> upsert -> SQLite -> relink` 链路

## 第 6 轮

### 外部 CLI 评审加入

在内部两轮多 agent 讨论收敛后，继续引入外部 CLI 做独立评审：

- `gemini cli`
- `claude code`

目标不是让它们重新设计方案，而是验证当前收口是否还存在明显盲点。

### Gemini CLI：支持当前方向，但强调“只读无副作用”必须可验证

Gemini 的总体判断是：

- 当前 debate 结论逻辑成立
- “双读 + 只读证据源 + 歧义回退”是正确方向

Gemini 最认可的点是：

- 已经明确限制 `config.toml` 在首次迁移阶段只能是只读证据源
- 并且任何不确定性都回退 `auth-only`

Gemini 指出的最脆弱点是：

- 方案仍然隐含一个关键假设：
  - `config.toml` 当前的 `model_provider/base_url`
  - 与 `auth.json` 中这把 API key
  - 属于同一时刻、同一账号、同一 relay 语义
- 真实环境里可能出现：
  - `auth.json` 已经切成官方 key
  - `config.toml` 却残留旧 relay 配置

Gemini 额外建议补的测试包括：

1. 顶层 `model_provider` 与实际 section 断链时必须回退
2. `config.toml` 关键字段类型异常时必须安全回退，而不是崩溃
3. 双读成功场景下，要断言磁盘上的 `config.toml` 内容与修改时间都完全不变，验证“只读证据源”契约

### Claude Code：支持当前收口，但同样指出“配置残留误补”是最脆弱假设

Claude Code 的极简评审结论是：

1. `verdict: support`
2. 它最认可的点是：
   - 当前首次迁移链路只消费 `auth.json`
   - `deriveAccountKind` 只有在 payload 已带 `nolon.relay` 时才会生成 `relayProfile`
   - 因此 custom `base_url` 真值若只在 `config.toml`，`auth-only` 路径会系统性降级成 `officialAPIKey`
3. 它指出的最脆弱假设与 Gemini 一致：
   - 我们默认 `config.toml` 里当前的 `model_provider/base_url`
   - 可以可靠代表与这把 API key 同一时刻的 relay 语义
   - 但若配置是残留、手改或多 provider 并存，即使“唯一命中”也可能误补 `nolon.relay`

### 外部评审后的再收敛

引入外部 CLI 后，内部结论没有被推翻，反而被进一步收紧：

1. 双读方向成立
2. `config.toml` 在迁移阶段只能只读
3. 真正的脆弱点不在“是否双读”，而在：
   - 如何证明当前 `config.toml` 与当前 `auth.json` 的 API key 仍属于同一条真实 relay 语义
4. 因此最终边界需要再补一条明确约束：
   - 只有当 `config.toml` 提供的 relay 证据不仅“唯一”，而且“与当前 auth payload 不冲突”时，才允许补 `nolon.relay`
   - 否则一律回退 `auth-only`

### 第 6 轮结论

到这一轮为止，debate 已经完成三层校验：

1. 内部实现校验：
   - 当前链路确实只读 `auth.json`
2. 内部风控校验：
   - `config.toml` 不能进入写路径
3. 外部模型校验：
   - 方案方向成立，但必须继续强化“同一语义证明”与“只读无副作用”测试

因此当前最稳的产品/工程结论是：

- 首次迁移 custom `base_url + API key` 时，双读是必须的
- 但只能做只读拼装
- 且必须把“不冲突、可证明、可回退”作为上线门槛

## 第 7 轮

### 再次推演后的分歧升级

在继续推演时，阻塞性反对者提出了一个新的致命边界缺失：

- 即使 `config.toml` 中 relay provider 证据唯一
- 也不能证明它与当前 `auth.json` 中这把 API key 属于同一时刻、同一账号语义

典型反例：

1. 用户过去使用过 relay provider
2. `config.toml` 仍残留旧的：
   - `model_provider`
   - `base_url`
3. 但当前 `auth.json` 已经换成官方 API key
4. 如果迁移仍按“唯一命中 relay config”自动升级
5. 就会把一个真实的官方账号误判成 `relayProfile`

这一轮的关键变化是：

- 问题已经不再是“是否应该双读”
- 而是“在没有 provenance 的情况下，双读得到的 config 证据是否足以支持自动升级”

### 争论焦点

现在真正的分歧变成了二选一：

- A. 无 provenance 不自动升级
- B. 无 provenance 也允许自动升级，但要求更强 config 证据

## 第 8 轮

### 多 Agent 最终收口：统一选择 A

在第四轮收口问题中，三位代理都被要求在 A / B 中明确做选择，最终结果一致：

- `ConsensusSmith`：选择 A
- `BlockerHunter`：选择 A
- `ProofHarness`：选择 A

也就是说，经过再次推演后，原本“fresh install 也可凭双读自动升级 relay”的假设被推翻。

### ConsensusSmith：没有 provenance 时不允许自动升级

- 立场：
  - 不允许在缺乏 provenance 时自动升级为 `relayProfile`
- 理由：
  - 唯一命中的 `config.toml` 也可能只是残留旧配置
  - 如果自动升级，账号语义会被错误污染
- 替代收口：
  - 只有在存在可验证联结的情况下，才允许把 config 证据写入 merged payload
  - 否则一律走 `auth-only`

### ProofHarness：从可验证性角度，A 是唯一稳定边界

- 立场：
  - 选择 `A. 无 provenance 不自动升级`
- 理由：
  - 这是唯一能被最小测试集稳定证明的边界
- 它给出的最小证明方式：
  1. 只有旧 relay config、没有 provenance 时，preflight 结果仍是 `officialAPIKey`
  2. 只有当存在当前 API key 与 relay 的可证明联结时，才升级成 `relayProfile`
  3. 升级成功或失败都要证明 `config.toml` 从未被修改

### BlockerHunter：fresh install 下也坚持 A

- 立场：
  - 即使在 fresh install 场景下，也选择 A
- 理由：
  - 没有 state/provenance 时，无法证明 relay config 不是残留
  - 因此最小安全收口只能是：
    - 缺 provenance 时保持 `officialAPIKey`
    - 不允许自动升级
- 它要求新增的最小约束：
  - 在尝试利用 `config.toml` 前，必须先具备可信 provenance
  - 若 provenance 不存在，要明确记录：
    - `provenance missing`
    - `skipping relay upgrade`

## 第 9 轮

### 最终共识完成

经过再次多轮推演，代理们最终达成一致，不再存在阻塞性分歧。

最终共识如下：

1. `auth.json + config.toml` 双读能力仍然需要保留
   - 但它不再意味着“fresh install 下一定自动升级 relay”
2. `config.toml` 在迁移阶段只能作为只读证据源
3. 若缺少 provenance，禁止自动把 `apikey` 升级成 `relayProfile`
4. fresh install 场景下：
   - 如果没有可验证 provenance
   - 即使 `config.toml` 命中了唯一 relay 配置
   - 也必须回退为 `officialAPIKey`
5. 只有在存在“当前 auth.json 与 relay config 属于同一账号语义”的可证明联结时，才允许：
   - 合成 `nolon.relay`
   - 推导 `relayProfile`
6. 所有成功或失败路径都必须保证：
   - `config.toml` 字节级不变
   - 修改时间不变
   - 不污染 `CodexActiveProviderConfigManager` 的 patch/restore 状态机

### 最终收口后的设计结论

因此，最终设计边界已经从：

- “custom base URL + API key 首次迁移必须双读并尝试自动升级”

收紧为：

- “custom base URL + API key 首次迁移可以双读，但只有在存在 provenance 时才允许自动升级；否则必须安全回退为 `officialAPIKey`”

### 最终最小验证集

在最终共识下，最小验证集也同步收敛为 3 条：

1. Given `auth.json` 是 API key，`config.toml` 命中 relay，但没有 provenance
   When preflight
   Then 结果必须保持 `officialAPIKey`

2. Given `auth.json` 是 API key，`config.toml` 命中 relay，且存在可证明 provenance
   When preflight
   Then 才允许生成 `relayProfile`

3. Given 任意双读路径（成功或回退）
   When preflight 完成
   Then `config.toml` 在磁盘上必须保持字节级不变

## 执行验证（2026-04-14）

本轮已按上述最终共识完成最小实现与验证，且没有再引入新的阻塞性分歧。

### 实现落点

1. 在首次 preflight 的 provider payload 收编路径中新增“只读 relay 证据合成”：
   - 仍然先读 `auth.json`
   - 仅当 payload 为 `apikey` 且尚未携带 `nolon.relay` 时，才尝试读取 `config.toml`
2. `config.toml` 的 relay 证据只有在以下条件同时满足时才会生效：
   - 当前 payload 能匹配到现有 snapshot 账号
   - `active-provider-config` state 中的 `managedAccountID` 与该 snapshot 一致
   - state 中的 `managedProviderID` 与 `config.toml` 当前激活的 `model_provider` 一致
   - 当前 provider section 能稳定解析出 `base_url`
3. 一旦以上任一条件不成立：
   - 立即回退为 `auth-only`
   - 账号类型保持 `officialAPIKey`
4. 当本次 preflight 确实使用了“只读 relay 证据合成”时：
   - 本轮 reconcile 后会跳过 `syncActiveProviderConfig(...)`
   - 避免把迁移阶段的只读判断重新带回 patch/restore 写路径

### 本轮实际验证结果

新增并通过了 3 条最终最小验证集对应的回归测试：

1. `Given detached apikey auth plus relay config without provenance, when preflight runs then snapshot stays official api key`
2. `Given detached apikey auth plus relay config with matching managed provenance, when preflight runs then matched snapshot upgrades to relay profile`
3. `Given detached apikey auth plus relay config, when preflight dual-reads provider state then config toml stays byte-for-byte untouched`

同时补跑 guard：

1. `Given relay profile activation followed by oauth activation, when account switching syncs auth, then config.toml patches to relay provider and restores original config`

### 执行后再次确认的边界

1. fresh install / 无 provenance 场景，仍不会自动升级 relay
2. provenance 的当前落点不是“任意唯一 relay config”，而是：
   - 已有受管 snapshot 账号
   - 已有 `active-provider-config` managed state
   - 当前 detached auth 与该受管账号可匹配
3. `config.toml` 在迁移阶段继续保持只读证据源身份
4. 现有激活后的 patch/restore 机制未被移除，只是避免在“只读迁移命中”这一分支里产生副作用

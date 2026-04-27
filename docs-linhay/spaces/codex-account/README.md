# Codex - 账号

## 主题
- 本 space 当前聚焦：Codex 账号支持 iCloud 同步。

## 背景
1. 当前 Codex 账号由 `libs/Providers` 统一管理，账号快照存放在 Nolon 托管目录，激活时还会联动 provider `auth.json`、活跃账号 registry，以及 `config.toml` 的 relay 配置恢复/接管逻辑。
2. 现状是“单机本地管理”模型：用户在一台 Mac 上登录、导入、编辑或删除 Codex 账号后，另一台 Mac 仍需重复导入或重新登录。
3. 对多设备用户来说，真正需要同步的是“账号库本身”，而不是把运行时状态、会话文件或当前机器的激活副作用强行广播到其他设备。
4. iCloud 同步一旦设计边界不清，容易出现三类问题：
   - 把敏感 auth 快照和普通偏好设置混存，导致安全边界失真。
   - 把“账号库同步”和“当前激活态同步”混为一谈，造成另一台设备被远程切号。
   - 把 Cloud 失败处理做成阻塞写路径，导致用户离线时连本地账号也不能维护。

## 目标
1. 支持同一 Apple ID 下多台 Apple 设备之间同步 Nolon 托管的 Codex 账号库。
2. 保持本地优先：即使 iCloud 不可用、网络中断或账号未登录，本地账号读写、导入、登录、激活流程仍可正常使用。
3. 明确同步层级，只同步“账号库”，不同步运行时会话、`runtime-home`、历史 rollout、活跃终端进程和本地临时文件。
4. 给出可解释的冲突模型、失败模型和回滚模型，避免“静默丢账号”或“静默覆盖本地配置”。

## 非目标
1. 不同步 Codex 会话历史、生成文件、`runtime-home`、技能目录或任何 rollout 归档。
2. 不同步当前设备的活跃 app-server / runtime 状态。
3. `v1` 不做跨 Apple ID 共享，不做公共分享链接，不做团队协作账号池。
4. 不做 Windows / Linux / Android 端同步。
5. 不把 provider `config.toml`、本地 symlink、当前激活账号选择自动下发到其他设备。

## 官方方案比较
### 方案 A：`CKSyncEngine` + CloudKit Private Database（推荐）
- 一句话：使用 Apple 官方推荐的 CloudKit 同步引擎同步结构化账号记录，适合“多条记录 + 增量变更 + 冲突处理 + 本地优先”的账号库场景。
- 适配性：
  - CloudKit 适合多记录数据，不像 `NSUbiquitousKeyValueStore` 只适合轻量偏好。
  - `CKSyncEngine` 原生支持推拉变更、状态持久化和离线后恢复，更符合账号库同步而不是单键值覆盖。
  - 可将同步限制在用户私有数据库，不涉及公开共享。
- 成本：中。
- 风险：需要 iCloud / CloudKit / Remote Notifications entitlement，且需处理 record 冲突与同步状态落盘。

### 方案 B：`NSUbiquitousKeyValueStore`
- 一句话：把账号数据塞进 iCloud KVS，开发快，但容量、结构和敏感信息边界都不匹配。
- 不推荐原因：
  - Apple 官方明确说明它更适合设置、配置和轻量 app data。
  - 总量和键值数都有限，不适合账号库持续演进。
  - 官方文档明确不建议存放敏感信息。
- 成本：低。
- 风险：高。

### 方案 C：iCloud Drive / 导出文件同步
- 一句话：把账号导出为文件后靠 iCloud Drive 同步。
- 不推荐原因：
  - 只能做到“文件复制”，做不好冲突、删除、去重和部分记录恢复。
  - 用户感知重，接近“手动备份”，不是真正的账号库同步。
  - 很容易把本地管理目录与云端副本耦合成不可控文件状态机。
- 成本：低到中。
- 风险：高。

## 推荐方案
- `v1` 采用方案 A：`CKSyncEngine` + CloudKit Private Database。
- 推荐理由：
  1. 这是 Apple 官方面向结构化同步数据的正向方案，和本需求的“账号记录集合”形态一致。
  2. 能明确区分本地数据库、云端记录、同步状态，不必把同步逻辑塞进现有 `auth.json`/文件监听链路。
  3. 最容易做到“本地写成功后再异步上云”，即使云端失败也不阻塞本地账号管理。

## 核心需求定义
### 同步对象
1. 同步 Nolon 托管的 Codex 账号记录集合。
2. 每条账号记录至少包含：
   - 本地账号 ID
   - 稳定匹配身份：`accountID`、规范化 email、auth hash
   - 展示元数据：名称、卡片类型、plan、relay 标识
   - 规范化后的 auth payload
   - 记录更新时间、删除标记、最近同步状态
3. 同步结果落地后，仍由现有 `CodexAuthManager` 统一管理本地账号表与快照文件。

### 不同步对象
1. 当前 provider 的活跃账号选择。
2. provider `auth.json` symlink 结果。
3. `config.toml` 当前接管态。
4. 运行时会话、SQLite session、usage cache、token trend 缓存。

### 数据语义
1. “账号库同步”与“账号激活”分离。
2. 新设备同步到账号后，默认只进入本地账号列表，不自动激活。
3. 用户仍需在当前设备显式执行激活，才会触发本地 `auth.json` / `config.toml` 联动。

## 冲突与合并规则
### 自动合并
1. 若云端记录与本地记录存在相同 `accountID`，视为同一账号，自动合并。
2. 若 `accountID` 缺失但规范化 auth hash 相同，视为同一账号，自动合并。
3. 自动合并时，必须区分“凭据本体”和“展示/同步元数据”：
   - 凭据本体以较新 `recordUpdatedAt` 为准
   - 元数据不允许简单整条覆盖，需按字段合并
4. 对于 `accountID` 缺失但 auth hash 命中的“同凭据账号”，字段级合并规则固定为：
   - `lastLoginAt` 取较晚值
   - `lastSyncSucceededAt` 取较晚值
   - `lastSyncFailedAt` 取较晚值
   - `lastSyncFailureMessage` 跟随较新的 `lastSyncFailedAt`
   - 名称、plan、卡片展示等弱元数据以较新 `recordUpdatedAt` 为准
5. 任何自动合并都不得让本地同步时间元数据倒退。

### 需要人工决策
1. 若 email 相同但 `accountID` 与 auth hash 均不同，视为“同邮箱不同凭据”冲突，不自动覆盖。
2. 冲突时提供三种动作：
   - 保留本地并覆盖云端
   - 采用云端并覆盖本地
   - 两者都保留，并对导入侧自动重命名

### 删除语义
1. 开启同步后，删除账号默认写成“删除 tombstone”，并同步到同 Apple ID 下其他设备。
2. 删除传播只作用于“账号记录”，不主动删除其他设备当前已激活的 provider `auth.json`；其他设备收到删除后，若该账号正处于激活态，应进入“本地激活失效待处理”状态，而不是直接静默改写。
3. 若当前设备收到 tombstone 时，该账号未处于激活态，则必须删除本地账号记录、对应 snapshot 数据以及相关托管残留文件，避免形成脱离托管的孤儿 auth 文件。
4. 若当前设备收到 tombstone 时，该账号仍处于激活态：
   - 保留当前生效的 provider `auth.json` 与运行配置，避免打断当前工作现场
   - 但该账号必须进入“激活失效待处理”状态
   - 在用户明确选择“重新导入保留本地凭据”或“清理本地残留并退出激活态”前，不得重新进入托管同步闭环
5. 下一次托管自愈 / `preflightManagedAuthIfNeeded` 发现“云端已 tombstone + 本地仍有激活残留”时，不得静默自愈成新的托管账号，必须返回显式状态并要求用户决策。

## 失败与降级策略
1. 未登录 iCloud / iCloud 受限 / 网络不可用时：
   - 本地账号管理继续可用
   - 同步状态显示为 `paused` 或 `degraded`
   - 变更进入待同步队列
2. CloudKit 推拉失败时：
   - 不回滚本地已成功写入的账号修改
   - 记录最近失败时间与错误摘要
   - 允许用户手动点击“立即同步”
3. 用户关闭 iCloud 同步时：
   - 仅停止当前设备继续推拉云端变更
   - 默认不删除 iCloud 中已有云副本
   - 若用户明确执行“清空 iCloud 云副本”，再执行破坏性删除

## UI / 交互需求
1. 在 Codex 账号页新增 `iCloud 同步` 区块。
2. 至少展示：
   - 当前状态：未开启 / 同步中 / 已暂停 / 有冲突 / 失败
   - iCloud 账户可用性
   - 上次成功同步时间
   - 待同步变更数
   - 最近错误摘要
3. 至少提供动作：
   - 开启同步
   - 关闭本机同步
   - 立即同步
   - 查看冲突
   - 处理“激活失效待处理”
   - 清空 iCloud 云副本（危险操作，二次确认）
4. 每个账号卡片应能展示云同步状态徽标，例如：
   - 仅本地
   - 已同步
   - 待上传
   - 冲突
   - 激活失效待处理

## 平台与工程前提
1. 需要 Apple Developer iCloud 能力与 CloudKit 容器。
2. 需要 Remote Notifications entitlement，以满足 `CKSyncEngine` 的推送变更机制。
3. 需要把同步状态持久化到本地，以便跨进程/跨启动恢复。
4. 需要为非 iCloud 可用环境提供明确空状态和降级提示。

## BDD 验收标准
1. Given 用户在设备 A 已开启 iCloud 同步且存在本地 Codex 账号，When 首次完成云端初始化，Then 本地账号会被上传到用户私有 iCloud 数据库，且本地账号列表不受阻塞。
2. Given 设备 B 使用同一 Apple ID 并开启 iCloud 同步，When 首次拉取云端数据，Then 能看到来自设备 A 的账号记录，但这些账号默认不自动激活。
3. Given 用户在设备 A 新增或导入一个 Codex 账号，When 同步完成，Then 设备 B 最终能收到该账号记录并进入可激活状态。
4. Given 用户在设备 A 删除一个已同步账号，When 删除 tombstone 传播到设备 B，Then 设备 B 的账号列表移除该记录；若该账号在设备 B 当前正处于激活态，则标记为“激活失效待处理”而不是静默切到别的账号。
5. Given 两台设备分别修改了同一账号，When 两端存在相同 `accountID`，Then 系统自动合并为同一账号记录，并以较新 `recordUpdatedAt` 的 payload 为准。
6. Given 两台设备存在 `accountID` 缺失但 auth hash 相同的账号，When 同步引擎自动合并，Then 凭据本体只保留一份，且 `lastLoginAt`、`lastSyncSucceededAt`、`lastSyncFailedAt` 等时间元数据按较晚值逐字段合并，不得倒退。
7. Given 两台设备存在同邮箱但不同凭据的账号，When 同步引擎识别到 `accountID` 与 auth hash 都不一致，Then 系统进入冲突态并要求用户选择保留策略。
8. Given 用户未登录 iCloud 或网络离线，When 本地新增、编辑、删除 Codex 账号，Then 本地改动仍立即生效，并显示待同步状态。
9. Given CloudKit 暂时失败，When 用户继续使用本地账号管理，Then 不阻塞本地读写，并在 UI 中展示最近失败摘要与手动重试入口。
10. Given 用户在设备 A 激活某个同步下来的账号，When 设备 B 收到同步更新，Then 设备 B 不自动改变当前激活账号，也不自动改写本地 provider `auth.json` 与 `config.toml`。
11. Given 某账号在设备 B 处于激活态且同时收到云端 tombstone，When 当前设备执行下一次托管自愈，Then 系统返回“激活失效待处理”而不是静默重建托管账号或自动清理本地生效凭据。
12. Given 用户关闭本机 iCloud 同步，When 后续其他设备继续写入云端账号库，Then 当前设备不再自动拉取这些变更，且本地已有账号保持可用。

## 风险与边界
1. 账号同步包含认证快照，属于高敏感数据；`v1` 必须采用显式开关，默认关闭，并在开启前明确告知“将把 Nolon 托管的 Codex 账号副本同步到你个人 iCloud 容器”。
2. 若后续安全评审认为完整 auth payload 不适合进入 CloudKit，则降级方案是“只同步元数据，不同步凭据”，但那不满足本需求的核心目标，不能作为默认实现。
3. 设备之间同步的是“账号库”，不是“本地运行现场”；任何涉及进程、会话、symlink、配置接管的状态都保持设备本地化。

## 回滚策略
1. 功能开关可整体验证后再放量，支持仅开发环境 / 内测环境启用。
2. 若实现方向错误，可通过关闭 `iCloud sync` feature flag 回退到纯本地账号管理，不需要迁移或清洗现有本地账号数据。
3. 云端副本删除必须是独立危险操作，不能绑定在“关闭同步”按钮上。

## 实施拆分建议
1. Phase 1：CloudKit 容器、同步状态模型、手动开启/关闭、首轮全量上传下载。
2. Phase 2：增量同步、删除 tombstone、失败重试、手动立即同步。
3. Phase 3：冲突中心、账号卡片同步状态徽标、激活失效待处理提示。

## 关联文档
- [Codex 账号 iCloud 同步技术方案（2026-04-25）](/Users/linhey/Desktop/FlowUp-Libs/nolon/docs-linhay/dev/codex-account-icloud-sync-implementation-2026-04-25.md:1)
- [Codex Provider 编排接入指南](/Users/linhey/Desktop/FlowUp-Libs/nolon/docs-linhay/dev/codex-provider-orchestration-guide.md:1)
- [Codex API Key / OAuth `config.toml` 联动设计](/Users/linhey/Desktop/FlowUp-Libs/nolon/docs-linhay/dev/codex-active-provider-config-sync-2026-04-10.md:1)
- [Codex Auth JSON 导入格式（含批量数组）](/Users/linhey/Desktop/FlowUp-Libs/nolon/docs-linhay/spaces/codex-auth-import-json-formats/README.md:1)

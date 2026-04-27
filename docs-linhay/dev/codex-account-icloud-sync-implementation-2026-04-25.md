# Codex 账号 iCloud 同步技术方案（2026-04-25）

关联需求：
- [Codex - 账号](/Users/linhey/Desktop/FlowUp-Libs/nolon/docs-linhay/spaces/codex-account/README.md:1)

## 目标
将 `Codex 账号 iCloud 同步` 落为可实现、可测试、可回滚的技术设计，满足以下约束：
1. 只同步账号库，不同步当前激活态。
2. 继续以 `CodexAuthManager` 作为本地账号真值入口，不新起平行账号系统。
3. 同步失败不阻塞本地新增、编辑、导入、登录、激活。
4. tombstone 删除、字段级合并、relay 参数设备隔离在实现层有硬兜底。

## 官方依赖
1. `CKSyncEngine`
   - 官方说明其负责数据库与 record 的 push / pull，同步状态由引擎维护，适合本地记录集合与 CloudKit 之间的增量同步。
   - 来源：https://developer.apple.com/documentation/CloudKit/CKSyncEngine-5sie5
2. `CKContainer.privateCloudDatabase`
   - 本方案只使用用户 private database；数据属于用户个人 iCloud 配额，不做 public / shared database。
   - 来源：https://developer.apple.com/documentation/CloudKit/CKContainer/privateCloudDatabase
3. `CKAccountStatus`
   - 用于区分 `available / noAccount / restricted / temporarilyUnavailable / couldNotDetermine`，驱动 UI 状态与降级行为。
   - 来源：https://developer.apple.com/documentation/cloudkit/ckaccountstatus

## 现状代码事实
1. 本地账号真值已在 `libs/Providers`，不是 app 层。
   - `CodexAuthManager+SQLite.swift` 已将账号拆成：
     - `codex_accounts`
     - `codex_active_accounts`
     - `codex_account_credentials`
     - `codex_account_metadata`
2. 激活态不是单独布尔值，而是一组本地副作用。
   - [CodexAuthManager.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/ProviderUsage/CodexAuthManager.swift:1342)
   - 激活会联动 `activateAccount`、`setActiveAccount`、`syncActiveProviderConfig`。
3. `preflightManagedAuthIfNeeded` 是当前托管自愈与漂移恢复入口。
   - [CodexAuthManager.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/ProviderUsage/CodexAuthManager.swift:1257)
4. 只有当前账号处于 active 态时，才会刷新本地 provider-facing 文件与 `config.toml`。
   - [CodexAuthManager+ActiveProviderConfig.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/ProviderUsage/CodexAuthManager+ActiveProviderConfig.swift:118)
5. app 层职责已经被治理文档限定为“编排、状态展示、错误映射”，不应直接改写底层账号文件。
   - [codex-provider-orchestration-guide.md](/Users/linhey/Desktop/FlowUp-Libs/nolon/docs-linhay/dev/codex-provider-orchestration-guide.md:1)

## 设计结论
### 分层
1. `libs/Providers`
   - 负责本地账号数据库 schema、记录合并、tombstone 处理、Cloud record 编解码、同步状态持久化、托管自愈拦截。
   - 提供纯领域接口，不暴露 UI / App 生命周期语义。
2. `nolon` app
   - 负责启动 / 停止同步引擎、iCloud 账户状态探测、设置页入口、手动同步按钮、错误文案展示。
   - 不直接访问 SQLite，也不直接拼 `CKRecord` 业务字段。

### 为什么不是“CloudKit 全在 App 层”
1. 同步核心必须直接复用 `CodexAuthManager` 的 SQLite / preflight / active-config 逻辑。
2. 若 CloudKit 变更在 app 层直接改库，会绕过既有文件锁、漂移修复和激活隔离边界。
3. 因此采用“两层协作”：
   - engine bootstrap 在 app
   - 业务同步协调与落地在 `libs/Providers`

## 2026-04-25 实现进展
### 已落地
1. `libs/Providers`
   - 新增 `CodexAuthManager+CloudSync.swift`
   - 已补 `CodexCloudSyncStatus`、`CodexCloudSyncState`、`CodexCloudSyncPreflightBlock`
   - 已实现：
     - cloud sync state 读写接口
     - `pendingDelete` / tombstone 状态落库
     - 远端 tombstone 对未激活账号的本地删除
     - active 账号 tombstone 命中时的 `invalidPending` 拦截
     - `accountID` 缺失但 auth hash 命中时的字段级 merge policy
2. SQLite schema
   - `codex_accounts` 已增加：
     - `cloud_record_name`
     - `cloud_record_zone`
     - `record_updated_at`
     - `last_synced_at`
     - `sync_status`
     - `is_tombstone`
   - `codex_account_metadata` 已增加：
     - `cloud_last_error`
     - `cloud_last_error_at`
     - `cloud_device_id`
     - `cloud_conflict_payload_json`
3. `CodexAuthManager`
   - `preflightManagedAuthIfNeeded` 已接入 cloud tombstone / invalid pending 拦截
   - `activateAccountAndMarkActive` 已禁止激活 tombstone / invalid pending 账号
   - `managementStatus(for:)` 已聚合 cloud sync 摘要计数
   - `cloudSyncOverview()` 已统一输出：
     - 总记录数
     - 已同步 / 待处理 / 冲突 / 待修复
     - 最近成功同步时间
     - 最近错误摘要
   - `managementStatus(for:)` 现已按 overview 口径统计，避免漏掉已从列表隐藏的 `pendingDelete` tombstone
4. `nolon` app
   - `nolonApp.swift` 已把最小 bootstrap 升级为 `CodexiCloudSyncService`
   - 已接 `CKSyncEngine` 最小闭环：
     - 使用 `CloudKit Private Database` + 固定 zone `CodexAccounts`
     - 持久化 `CKSyncEngine.State.Serialization` 到本地 app support
     - 本地生成稳定 `device-id`
     - `syncNow()` 会执行：
       - 从 `CodexAuthManager.cloudSyncPendingChanges()` 收集待上传 / 待删除变更
       - 生成 `CKSyncEngine.PendingRecordZoneChange`
       - `sendChanges()` 推送本地改动
       - `fetchChanges()` 拉取远端 record / tombstone
     - `sentRecordZoneChanges` 成功 / 失败会回写 `synced / conflict / recentError`
     - `fetchedRecordZoneChanges` 会通过 `applyRemoteCloudRecord` / tombstone 路径回灌本地账号库
   - 当前职责：
     - 读取 `CodexAuthManager` 持久化开关，默认关闭
     - 探测 CloudKit 账户状态
     - 归约 UI 可直接消费的 snapshot：`disabled / syncing / synced / paused / conflict / failed`
     - 提供 `setEnabled(_:)`、`syncNow()`、`refresh()` 入口
   - 已补工程前提：
     - `nolon/nolon.entitlements`
     - app target `CODE_SIGN_ENTITLEMENTS`
     - CloudKit container entitlement
     - APS entitlement
5. `ProviderUsageEngine` / UI
   - engine 已在 reload 时加载每个账号的 cloud sync state
   - 管理摘要文案已显示：
     - 已同步数
     - 待处理数
     - 冲突数
     - 待修复数
   - Codex 账号页已新增 `iCloud 同步` 卡片，展示：
     - 当前状态
     - iCloud 可用性
     - 上次成功同步时间
     - 待同步变更数
     - 最近错误摘要
   - 已接动作：
     - 开启同步
     - 关闭本机同步
     - 立即同步
   - 账号卡片 footer 已展示单账号云状态：
     - 仅本地
     - 已同步
     - 待上传
     - 待删除
     - 冲突
     - 待修复

### 已验证
1. 定向测试通过：
   - `swift test --package-path libs/Providers --filter 'CodexAuthManagerTests/(sqliteSchemaIncludesCloudSyncColumns|loadCloudSyncStateDefaultsToLocalOnly|cloudSyncConfigurationDefaultsToDisabled|addAccountMarksPendingUploadWhenCloudSyncEnabled|updateAccountRefreshesPendingUploadStateWhenCloudSyncEnabled|markPendingCloudDeletionPersistsState|managementStatusAggregatesCloudSyncCounters|deleteAccountMarksPendingDeleteWhenCloudSyncEnabled|cloudSyncOverviewIncludesHiddenPendingDeleteAndLatestError|mergePolicyPreservesLatestSyncMetadataForHashMatchedAccounts|preflightThrowsForInvalidPendingCloudState|applyCloudTombstoneRemovesNonActiveAccount|enablingCloudSyncQueuesExistingAccountsForUpload|cloudSyncPendingChangesIncludesHiddenPendingDeletes|applyRemoteCloudRecordCreatesLocalAccountAndMarksSynced)'`
2. 主 app 编译通过：
   - `xcodebuild -project nolon.xcodeproj -scheme nolon-app -configuration Debug -sdk macosx build CODE_SIGNING_ALLOWED=NO`
3. app 定向测试通过：
   - `xcodebuild -project nolon.xcodeproj -scheme nolon-tests -configuration Debug -sdk macosx test CODE_SIGNING_ALLOWED=NO -only-testing:nolonTests/ProviderUsageAccountsViewModelParityTests -only-testing:nolonTests/CodexiCloudSyncPresentationTests`

### 当前未完成
1. 冲突处理 UI 仍未落地，当前只有汇总提示和账号级状态暴露；`serverRecordChanged` 只会把账号打到 `conflict`
2. “查看冲突”、“处理激活失效待处理”、“清空 iCloud 云副本” 三个 README 动作尚未提供专门入口
3. 已补 entitlement 且本地编译通过，但真实签名、容器权限、远端账号切换仍需在有效 Team/Profile 环境下做运行态验证
4. 当前闭环重点是手动 `syncNow()` + 启动时自动拉起引擎；远端推送触发与长期后台行为尚未做单独运行态验收

### 2026-04-25 第 4 批补完
1. `libs/Providers`
   - 已补 provider 侧恢复 / 清理 API：
     - `retryCloudSyncUpload(accountID:)`
     - `discardInvalidPendingManagedAccount(id:providers:)`
     - `resetCloudSyncMetadataAfterRemotePurge()`
     - `cloudAttentionItems()`
   - 覆盖三类 `v1` 尾部场景：
     - `invalidPending -> pendingUpload` 重试恢复
     - 激活失效待处理账号的本地托管残留清理
     - 云端副本被整体清空后的本地 metadata 回退为 `localOnly`
2. `ProviderUsageEngine` / root view model
   - 新增：
     - `retryCodexCloudAttentionAccount(id:)`
     - `discardCodexInvalidPendingAccount(id:)`
     - `clearCodexCloudData()`
   - `CodexState` 已新增 `cloudAttentionItems` 归约和对应动作透传，UI 不再直接拼装领域判断
3. `CodexiCloudSyncService`
   - 新增 `clearCloudData() async throws -> Int`
   - 清理路径为：
     - 暂停引擎
     - 查询当前 zone 全部 record
     - 删除 record
     - 删除 zone（zone 不存在时忽略）
     - 删除本地 `CKSyncEngine` state serialization
     - 调 provider 重置 cloud metadata 并关闭本机同步
4. Codex 账号页 UI
   - `iCloud 同步` 卡片已补 README 要求的剩余入口：
     - `查看冲突`
     - `清空 iCloud 云副本`
   - 新增 `CodexCloudAttentionSheet`
     - 展示 `conflict / invalidPending` 账号
     - 支持“保留本地并重试上传”
     - 对 `invalidPending` 额外支持“清理本地残留”
   - “处理激活失效待处理” 当前以 `invalidPending` 行动入口落地，而不是单独第二张中心页

### 第 4 批验证
1. `xcodebuild -project nolon.xcodeproj -scheme nolon-app -configuration Debug -sdk macosx build CODE_SIGNING_ALLOWED=NO -quiet` 通过
2. `swift test --package-path libs/Providers --filter 'CodexAuthManagerTests/(sqliteSchemaIncludesCloudSyncColumns|loadCloudSyncStateDefaultsToLocalOnly|cloudSyncConfigurationDefaultsToDisabled|addAccountMarksPendingUploadWhenCloudSyncEnabled|updateAccountRefreshesPendingUploadStateWhenCloudSyncEnabled|markPendingCloudDeletionPersistsState|managementStatusAggregatesCloudSyncCounters|deleteAccountMarksPendingDeleteWhenCloudSyncEnabled|cloudSyncOverviewIncludesHiddenPendingDeleteAndLatestError|mergePolicyPreservesLatestSyncMetadataForHashMatchedAccounts|preflightThrowsForInvalidPendingCloudState|applyCloudTombstoneRemovesNonActiveAccount|enablingCloudSyncQueuesExistingAccountsForUpload|cloudSyncPendingChangesIncludesHiddenPendingDeletes|applyRemoteCloudRecordCreatesLocalAccountAndMarksSynced)'` 通过
3. `swift test --package-path libs/Providers --filter 'CodexAuthManagerTests/(retryCloudSyncUploadResolvesInvalidPendingToPendingUpload|discardInvalidPendingManagedAccountRemovesLocalResidue|resetCloudSyncMetadataAfterRemotePurgeMakesAllRowsLocalOnly)'` 通过
4. `xcodebuild -project nolon.xcodeproj -scheme nolon-tests -configuration Debug -sdk macosx test CODE_SIGNING_ALLOWED=NO -only-testing:nolonTests/ProviderUsageAccountsViewModelParityTests -only-testing:nolonTests/CodexiCloudSyncPresentationTests -quiet` 通过

### 当前边界更新
1. README 中 `查看冲突 / 处理激活失效待处理 / 清空 iCloud 云副本` 的 `v1` 最小入口已补齐，但仍不是完整冲突中心
2. “采用云端并覆盖本地”与“两者都保留并自动重命名”仍未落地；当前仅支持：
   - 保留本地并重试上传
   - 对 `invalidPending` 清理本地残留
3. 真实跨设备联调、CloudKit 容器权限、远端推送触发与长期后台行为仍未做运行态验收

### 2026-04-25 第 5 批补完
1. CloudKit 冲突上下文持久化
   - `serverRecordChanged` 不再只把账号打成 `conflict`
   - app 侧会从 `CKError` 提取 `serverRecord`
   - 转成 `CodexCloudSyncRecordPayload`
   - 通过 `markCloudSyncFailed(..., conflictPayload:)` 落到本地 `cloud_conflict_payload_json`
2. `libs/Providers`
   - `CodexCloudSyncRecordPayload` 已补 `Codable` 与 JSON 编解码 helper
   - 新增 `adoptRemoteCloudConflict(accountID:providers:)`
   - 该路径会：
     - 用远端 payload 覆盖本地 snapshot
     - 将 cloud state 恢复为 `synced`
     - 清空 conflict payload / 最近错误
     - 若该账号当前处于激活态，则同步刷新 provider-facing `auth.json` / runtime config
3. Codex 冲突 sheet
   - 对 `conflict` 且本地已有远端 payload 的账号，新增：
     - `采用云端覆盖本地`
   - 因此当前 `v1` 冲突动作已覆盖两条：
     - 保留本地并重试上传
     - 采用云端覆盖本地

### 第 5 批验证
1. `swift test --package-path libs/Providers --filter 'CodexAuthManagerTests/(markCloudSyncFailedStoresConflictPayloadForLaterResolution|adoptRemoteCloudConflictOverwritesLocalSnapshotAndActiveAuthFile|retryCloudSyncUploadResolvesInvalidPendingToPendingUpload|discardInvalidPendingManagedAccountRemovesLocalResidue|resetCloudSyncMetadataAfterRemotePurgeMakesAllRowsLocalOnly)'` 通过
2. `swift test --package-path libs/Providers --filter 'CodexAuthManagerTests/(sqliteSchemaIncludesCloudSyncColumns|loadCloudSyncStateDefaultsToLocalOnly|cloudSyncConfigurationDefaultsToDisabled|addAccountMarksPendingUploadWhenCloudSyncEnabled|updateAccountRefreshesPendingUploadStateWhenCloudSyncEnabled|markPendingCloudDeletionPersistsState|managementStatusAggregatesCloudSyncCounters|deleteAccountMarksPendingDeleteWhenCloudSyncEnabled|cloudSyncOverviewIncludesHiddenPendingDeleteAndLatestError|mergePolicyPreservesLatestSyncMetadataForHashMatchedAccounts|preflightThrowsForInvalidPendingCloudState|applyCloudTombstoneRemovesNonActiveAccount|enablingCloudSyncQueuesExistingAccountsForUpload|cloudSyncPendingChangesIncludesHiddenPendingDeletes|applyRemoteCloudRecordCreatesLocalAccountAndMarksSynced|retryCloudSyncUploadResolvesInvalidPendingToPendingUpload|markCloudSyncFailedStoresConflictPayloadForLaterResolution|discardInvalidPendingManagedAccountRemovesLocalResidue|resetCloudSyncMetadataAfterRemotePurgeMakesAllRowsLocalOnly|adoptRemoteCloudConflictOverwritesLocalSnapshotAndActiveAuthFile)'` 通过
3. `xcodebuild -project nolon.xcodeproj -scheme nolon-tests -configuration Debug -sdk macosx test CODE_SIGNING_ALLOWED=NO -only-testing:nolonTests/CodexiCloudSyncPresentationTests -only-testing:nolonTests/ProviderUsageAccountsViewModelParityTests -quiet` 通过
4. `xcodebuild -project nolon.xcodeproj -scheme nolon-app -configuration Debug -sdk macosx build CODE_SIGNING_ALLOWED=NO -quiet` 通过

### 当前边界再更新
1. README 冲突三选项里，现已完成两项：
   - 保留本地并覆盖云端
   - 采用云端并覆盖本地
2. 仍未完成的只剩：
   - 两者都保留，并对导入侧自动重命名
3. 真实跨设备联调、CloudKit 容器权限、远端推送触发与长期后台行为仍未做运行态验收

### 2026-04-25 第 6 批补完
1. `libs/Providers`
   - 新增 `splitCloudConflictKeepingBoth(accountID:)`
   - 行为是：
     - 保留当前本地账号 A 不动
     - 使用远端 conflict payload 物化第二条账号 B
     - B 分配新的本地 `UUID` 与新的 `cloud_record_name`
     - B 自动命名为 `原名 (iCloud)`，如已存在则递增为 `原名 (iCloud 2)` ...
     - A/B 都切回 `pendingUpload`
     - 原 conflict metadata 清空
   - 本机当前激活态保持在 A，不自动切到 B
2. Codex 冲突 sheet
   - 已补第三个动作：
     - `两者都保留`
   - 至此 README 中的三条冲突策略在 `v1` 都已有最小入口：
     - 保留本地并重试上传
     - 采用云端覆盖本地
     - 两者都保留

### 第 6 批验证
1. `swift test --package-path libs/Providers --filter 'CodexAuthManagerTests/(splitCloudConflictKeepingBothCreatesDuplicatedPendingUploadAccount|splitCloudConflictKeepingBothUsesIncrementingSuffixWhenNeeded|markCloudSyncFailedStoresConflictPayloadForLaterResolution|adoptRemoteCloudConflictOverwritesLocalSnapshotAndActiveAuthFile)'` 通过
2. `swift test --package-path libs/Providers --filter 'CodexAuthManagerTests/(sqliteSchemaIncludesCloudSyncColumns|loadCloudSyncStateDefaultsToLocalOnly|cloudSyncConfigurationDefaultsToDisabled|addAccountMarksPendingUploadWhenCloudSyncEnabled|updateAccountRefreshesPendingUploadStateWhenCloudSyncEnabled|markPendingCloudDeletionPersistsState|managementStatusAggregatesCloudSyncCounters|deleteAccountMarksPendingDeleteWhenCloudSyncEnabled|cloudSyncOverviewIncludesHiddenPendingDeleteAndLatestError|mergePolicyPreservesLatestSyncMetadataForHashMatchedAccounts|preflightThrowsForInvalidPendingCloudState|applyCloudTombstoneRemovesNonActiveAccount|enablingCloudSyncQueuesExistingAccountsForUpload|cloudSyncPendingChangesIncludesHiddenPendingDeletes|applyRemoteCloudRecordCreatesLocalAccountAndMarksSynced|retryCloudSyncUploadResolvesInvalidPendingToPendingUpload|markCloudSyncFailedStoresConflictPayloadForLaterResolution|discardInvalidPendingManagedAccountRemovesLocalResidue|resetCloudSyncMetadataAfterRemotePurgeMakesAllRowsLocalOnly|adoptRemoteCloudConflictOverwritesLocalSnapshotAndActiveAuthFile|splitCloudConflictKeepingBothCreatesDuplicatedPendingUploadAccount|splitCloudConflictKeepingBothUsesIncrementingSuffixWhenNeeded)'` 通过
3. `xcodebuild -project nolon.xcodeproj -scheme nolon-tests -configuration Debug -sdk macosx test CODE_SIGNING_ALLOWED=NO -only-testing:nolonTests/CodexiCloudSyncPresentationTests -only-testing:nolonTests/ProviderUsageAccountsViewModelParityTests -quiet` 通过
4. `xcodebuild -project nolon.xcodeproj -scheme nolon-app -configuration Debug -sdk macosx build CODE_SIGNING_ALLOWED=NO -quiet` 通过

### 当前边界最终更新
1. README 中 `v1` 约定的三条冲突策略已全部落地为可操作入口
2. 当前仍未完成的是运行态验证，而不是业务分支缺口：
   - 真实跨设备联调
   - 真 CloudKit 容器权限 / 签名校验
   - 远端推送触发与长期后台行为验收
3. 仍不是“完整冲突中心产品化版本”，但 `v1` 所需的冲突动作已经齐备

## 模块拆分
### `libs/Providers` 新增模块
1. `CodexAccountCloudSyncCoordinator`
   - 同步总协调器。
   - 职责：
     - 提供本地待上传变更
     - 接收远端变更并事务落地
     - 驱动 tombstone / 合并 / 冲突决策
2. `CodexAccountCloudRecordCodec`
   - 本地账号 <-> CloudKit record 的双向映射。
3. `CodexAccountCloudStateStore`
   - 持久化同步状态：
     - `recordUpdatedAt`
     - `lastSyncedAt`
     - `syncStatus`
     - `cloudRecordID`
     - `isTombstone`
     - `lastSyncError`
4. `CodexAccountCloudMergePolicy`
   - 同账号覆盖、字段级合并、人工冲突判定。
5. `CodexAccountCloudSyncError`
   - 统一错误域：
     - `iCloudUnavailable`
     - `recordDecodeFailed`
     - `tombstoneWhileActive`
     - `mergeConflictRequiresUserDecision`
     - `cloudStateCorrupted`

### `nolon` app 新增模块
1. `CodexiCloudSyncService`
   - 持有 `CKSyncEngine`。
   - 将引擎 delegate 事件转发给 `CodexAccountCloudSyncCoordinator`。
2. `CodexiCloudSyncViewModel` 或并入现有 Provider Usage engine
   - 驱动 UI 状态：
     - 未开启
     - 初始化中
     - 同步中
     - 已暂停
     - 冲突
     - 激活失效待处理
     - 失败

## 本地数据模型
在现有 SQLite 体系上最小扩展，不改动“账号真值属于本地账号表”的前提。

### 扩展 `codex_accounts`
新增字段：
1. `cloud_record_name TEXT`
   - CloudKit record name
2. `cloud_record_zone TEXT`
   - 预留 zone 名
3. `record_updated_at TEXT`
   - 账号 payload 的业务更新时间
4. `last_synced_at TEXT`
   - 最近一次本地与云端成功对齐时间
5. `sync_status TEXT NOT NULL DEFAULT 'localOnly'`
   - `localOnly / pendingUpload / synced / pendingDelete / conflict / invalidPending`
6. `is_tombstone INTEGER NOT NULL DEFAULT 0`
   - 本地 tombstone 标记

### 扩展 `codex_account_metadata`
新增字段：
1. `cloud_last_error TEXT`
2. `cloud_last_error_at TEXT`
3. `cloud_device_id TEXT`
   - 最近写入该记录的设备标识
4. `cloud_conflict_payload_json TEXT`
   - 人工冲突时暂存远端候选

### 不新增远端同步到本地的表
1. 不同步 `codex_active_accounts`
2. 不新增“云端激活态表”
3. 激活态始终保持设备本地语义

## CloudKit record 模型
### Record type
`CodexAccount`

### Record key
1. `recordName`
   - 优先使用本地 `account.id.uuidString`
   - 不再为同一账号生成第二套云端 ID

### Fields
1. `identityKey: String`
   - 对齐本地唯一索引语义
2. `accountPayload: Data`
   - 规范化后的 auth payload
3. `metadataJSON: String`
   - 展示与同步元数据
4. `recordUpdatedAt: Date`
   - 业务更新时间，优先于 CloudKit server modified time
5. `isTombstone: Int64`
6. `originDeviceID: String`
7. `schemaVersion: Int64`

### 为什么不把所有字段拆成 CloudKit 原子列
1. 当前本地账号结构来自 auth JSON + metadata 混合解析，字段还在演进。
2. `v1` 优先保证迁移成本低、兼容旧账号、编解码路径单一。
3. 用 `payload + metadataJSON + business timestamp` 更容易复用现有 `CodexAuthManager` 读写链路。

## 同步状态机
### 本地修改
1. `addAccount` / `updateAccount` / `upsertAccountFromCLILogin`
   - 先正常写本地 SQLite + snapshot
   - 再把 `sync_status` 置为 `pendingUpload`
   - 更新 `record_updated_at`
2. `deleteAccount`
   - 不直接物理删除云同步记录
   - 对已开启云同步的账号改为：
     - `is_tombstone = 1`
     - `sync_status = pendingDelete`
   - 真正物理清理由同步协调器在“远端已确认 + 本地非激活”路径完成

### 远端拉取
1. `CKSyncEngine` 收到 record change
2. app 层转发给 `CodexAccountCloudSyncCoordinator`
3. 协调器做以下分支：
   - 本地不存在：新建本地账号记录，`sync_status = synced`
   - 本地存在且为 tombstone：按 tombstone 规则处理
   - 本地存在且非 tombstone：进入 merge policy

### merge policy
1. `accountID` 相同：
   - 视为同账号
   - 凭据本体按较新 `recordUpdatedAt` 覆盖
2. `accountID` 缺失但 auth hash 相同：
   - 视为同凭据账号
   - 凭据本体只保留一份
   - `lastLoginAt / lastSyncSucceededAt / lastSyncFailedAt` 按较晚值逐字段合并
   - `lastSyncFailureMessage` 跟随较新的失败时间
3. email 相同但 `accountID` 和 auth hash 都不同：
   - 标记 `sync_status = conflict`
   - 远端候选写入 `cloud_conflict_payload_json`
   - 不自动覆盖

### tombstone 处理
1. 若本地账号未激活：
   - 删除本地账号记录
   - 删除对应 snapshot / 托管残留文件
   - 清理 Cloud 状态字段
2. 若本地账号仍激活：
   - 保留当前 provider `auth.json` 与当前运行配置
   - 标记 `sync_status = invalidPending`
   - 增加领域态：`activationInvalidatedByCloudDeletion`
   - 阻止 `preflightManagedAuthIfNeeded` 静默把残留重新导入为新托管账号

## 与现有 `preflight` / 激活链路的衔接
### `preflightManagedAuthIfNeeded`
新增第一优先级检查：
1. 先读取当前 active account 对应的 cloud sync state
2. 若命中：
   - `is_tombstone = 1`
   - 且本地仍是 active
3. 则：
   - 直接返回显式状态，不进入普通 reconcile / drift repair
   - 不调用 `syncActiveProviderConfig`
   - 由 UI 呈现“激活失效待处理”

### `activateAccountAndMarkActive`
保持现有行为不变，但增加一条前置约束：
1. 若账号 `is_tombstone = 1` 或 `sync_status = invalidPending`
2. 禁止直接激活
3. 需要用户先做：
   - 重新导入保留本地凭据
   - 或清理残留退出激活态

### `refreshActiveProviderFilesIfNeeded`
不改“只有 active 才刷新本地配置”的现有边界。
这正是 relay 参数“同步入库但不自动落本地 `config.toml`”的实现兜底。

## 事务与并发
### 文件锁
继续复用现有 `.auth.lock` 语义。

### SQLite 事务
任何远端变更落地都必须包在单个事务中，至少覆盖：
1. `codex_accounts`
2. `codex_account_credentials`
3. `codex_account_metadata`

原因：
1. 当前账号数据分三表存储
2. 若只写其中一张表，会产生孤儿 credentials / metadata
3. CloudKit push / pull 中断时不能留下半条账号

## App 生命周期与引擎启动
### 启动时机
1. app launch 早期创建 `CodexiCloudSyncService`
2. 在 `nolonApp` 中与现有 `CodexAuthBackgroundPoller` 并列启动

### 运行策略
1. 仅当用户开启 `iCloud sync` 开关时创建 / 激活 `CKSyncEngine`
2. 账户状态非 `available` 时：
   - 不启动 engine
   - UI 显示 paused / degraded
3. 手动点击“立即同步”时：
   - 请求引擎立即调度 send / fetch

## 建议文件落点
### `libs/Providers`
1. `libs/Providers/Sources/ProviderUsage/CodexAccountCloudSyncCoordinator.swift`
2. `libs/Providers/Sources/ProviderUsage/CodexAccountCloudRecordCodec.swift`
3. `libs/Providers/Sources/ProviderUsage/CodexAccountCloudMergePolicy.swift`
4. `libs/Providers/Sources/ProviderUsage/CodexAuthManager+CloudSync.swift`

### `nolon`
1. `nolon/Skills/Infrastructure/CodexiCloudSyncService.swift`
2. `nolon/Skills/Domain/Providers/Usage/Engine/ProviderUsageEngine+CodexICloudSync.swift`
3. 现有账号页 / runtime 页对应状态区块接线文件

## BDD + TDD 拆分
### Phase 1：本地 schema 与状态模型
1. 红灯测试：
   - Given 开启云同步账号新增成功，Then 本地行写入 `pendingUpload`
   - Given 云同步账号删除，Then 本地改为 tombstone 而不是立即物理删除
2. 绿灯实现：
   - SQLite schema 扩展
   - `CodexAuthManager` 本地 sync state API

### Phase 2：merge policy
1. 红灯测试：
   - `accountID` 相同 -> 新 payload 覆盖旧 payload
   - hash 相同但 `accountID` 缺失 -> 时间字段逐项取较晚值
   - email 相同但凭据不同 -> `conflict`
2. 绿灯实现：
   - `CodexAccountCloudMergePolicy`

### Phase 3：tombstone 与 preflight 拦截
1. 红灯测试：
   - 未激活账号收到 tombstone -> 清理本地残留
   - 激活账号收到 tombstone -> `invalidPending`
   - `preflightManagedAuthIfNeeded` 遇到 `invalidPending` -> 不静默自愈
2. 绿灯实现：
   - `CodexAuthManager+CloudSync`
   - `preflight` 分支插入

### Phase 4：CKSyncEngine 接线
1. 红灯测试：
   - 模拟 remote save -> 本地落地成功
   - 模拟 remote delete -> tombstone 流程正确
   - iCloud 不可用 -> engine 不启动且 UI 为 paused
2. 绿灯实现：
   - `CodexiCloudSyncService`
   - app 层状态展示

## 测试分层
### `libs/Providers` 单元测试
1. `CodexAccountCloudMergePolicyTests`
2. `CodexAuthManagerCloudSyncStateTests`
3. `CodexAuthManagerTombstoneTests`

### `libs/Providers` 集成测试
1. SQLite 三表事务一致性
2. preflight 遇到 tombstone active 残留时返回显式状态

### `nolonTests`
1. `CodexiCloudSyncServiceTests`
2. `ProviderUsageEngineCodexICloudSyncTests`
3. UI 状态映射与错误提示测试

## 风险与实现提醒
1. 不要把 CloudKit server modified time 当成业务合并真值。
   - 业务合并应以显式 `recordUpdatedAt` 为准。
2. 不要让远端同步绕过 `CodexAuthManager` 直接改本地文件。
   - 所有 provider-facing 变更仍由激活链路触发。
3. tombstone active 残留不是普通错误，而是领域态。
   - 必须有显式状态和值守 UI，不能靠日志吞掉。

## 未决问题
1. `recordUpdatedAt` 是否单独存表还是复用 `codex_accounts.updated_at`
   - 推荐单独存，避免与本地 DB 行更新时间混淆。
2. `accountPayload` 是否再额外做一层应用级加密
   - 若安全评审要求高于 CloudKit private database 默认保护，再补应用层 envelope encryption。

## 2026-04-25 第 7 批补完：持久化 CloudKit record system fields，修正真实云端下的 change tag 风险
- 背景：
  - 这轮不是补新的 README 交互，而是针对真实 CloudKit 运行态补一条底层正确性缺口。
  - 按 Apple CloudKit 文档，`serverRecordChanged` 本质是 record change tag 冲突；`CKError` 只会把 `ancestorRecord / clientRecord / serverRecord` 暴露给业务层自行决策。
  - `CKSyncEngine.State` 负责 token / pending queue，不等于替业务本地存每条 `CKRecord` 的最新 system fields。
  - 如果本地每次上传都新造 `CKRecord(recordType:recordID:)`，又没有持久化上一次成功返回的 system fields，那么真实云端更新路径会持续缺少最新 change tag，容易反复打到 `serverRecordChanged`。
- 本轮实现：
  - provider cloud state 新增 `recordSystemFieldsBase64`
  - SQLite `codex_account_metadata` 新增 `cloud_record_system_fields_base64`
  - `markCloudSyncSent(...)` 现在会持久化成功返回 record 的 system fields
  - `applyRemoteCloudRecord(...)` 也会把 fetched server record 的 system fields 落回本地 state
  - `retryCloudSyncUpload(accountID:)` 在 conflict 之后重试时，会优先采用 `serverRecordChanged` 里保存下来的远端 system fields
  - `adoptRemoteCloudConflict(...)` / `splitCloudConflictKeepingBoth(...)` 也已改成消费 conflict payload 中的 system fields，避免冲突处理后下一次上传仍带旧 tag
  - app 侧 `CodexiCloudSyncCloudKitCodec` 新增：
    - `makeSystemFieldsData(from:)`
    - `makeRecord(fromSystemFieldsData:)`
  - outbound save 现在会优先从 `recordSystemFieldsBase64` 恢复 `CKRecord`，再覆写业务字段并发送
  - inbound fetched record / sent saved record 会把最新 system fields 编回 provider state
- 本轮新增测试：
  - `markCloudSyncSentPersistsRecordSystemFields`
  - `testBDD_GivenCloudKitSystemFields_WhenRoundTripping_ThenRecordCanBeRestored`
- 本轮验证结果：
  - `swift test --package-path libs/Providers --filter 'CodexAuthManagerTests/(sqliteSchemaIncludesCloudSyncColumns|loadCloudSyncStateDefaultsToLocalOnly|cloudSyncConfigurationDefaultsToDisabled|addAccountMarksPendingUploadWhenCloudSyncEnabled|updateAccountRefreshesPendingUploadStateWhenCloudSyncEnabled|markPendingCloudDeletionPersistsState|markCloudSyncSentPersistsRecordSystemFields|managementStatusAggregatesCloudSyncCounters|deleteAccountMarksPendingDeleteWhenCloudSyncEnabled|cloudSyncOverviewIncludesHiddenPendingDeleteAndLatestError|mergePolicyPreservesLatestSyncMetadataForHashMatchedAccounts|preflightThrowsForInvalidPendingCloudState|applyCloudTombstoneRemovesNonActiveAccount|enablingCloudSyncQueuesExistingAccountsForUpload|cloudSyncPendingChangesIncludesHiddenPendingDeletes|applyRemoteCloudRecordCreatesLocalAccountAndMarksSynced|retryCloudSyncUploadResolvesInvalidPendingToPendingUpload|markCloudSyncFailedStoresConflictPayloadForLaterResolution|discardInvalidPendingManagedAccountRemovesLocalResidue|resetCloudSyncMetadataAfterRemotePurgeMakesAllRowsLocalOnly|adoptRemoteCloudConflictOverwritesLocalSnapshotAndActiveAuthFile|splitCloudConflictKeepingBothCreatesDuplicatedPendingUploadAccount|splitCloudConflictKeepingBothUsesIncrementingSuffixWhenNeeded)'` 通过
  - `xcodebuild -project nolon.xcodeproj -scheme nolon-tests -configuration Debug -sdk macosx test CODE_SIGNING_ALLOWED=NO -only-testing:nolonTests/CodexiCloudSyncPresentationTests -only-testing:nolonTests/ProviderUsageAccountsViewModelParityTests -quiet` 通过
  - `xcodebuild -project nolon.xcodeproj -scheme nolon-app -configuration Debug -sdk macosx build CODE_SIGNING_ALLOWED=NO -quiet` 通过
- 当前边界更新：
  - 代码层现在已经不只是“业务分支齐”，还补上了真实 CloudKit record metadata 的持久化链路
  - 仍未完成的依旧是运行态联调：
    - 真实跨设备
    - 真容器 / 真签名权限
    - 推送触发与后台唤醒验收

## 2026-04-25 运行态预检补充：当前签名配置尚未具备真 CloudKit 联调条件
- 目标：
  - 在不改业务代码的前提下，做一次更接近真实环境的预检，确认当前工程是否已经具备带签名的 CloudKit 运行条件。
- 已完成检查：
  - `xcodebuild -project nolon.xcodeproj -scheme nolon-app -configuration Debug -sdk macosx -showBuildSettings`
  - `xcodebuild -project nolon.xcodeproj -scheme nolon-app -configuration Debug -sdk macosx build -quiet`
- 当前 build settings 关键信息：
  - `PRODUCT_BUNDLE_IDENTIFIER = nolon.overloaded.com`
  - `DEVELOPMENT_TEAM = 3L8RM3MDLS`
  - `CODE_SIGN_ENTITLEMENTS = nolon/nolon.entitlements`
  - entitlement 文件已声明：
    - `com.apple.developer.aps-environment = development`
    - `com.apple.developer.icloud-container-identifiers = [iCloud.nolon.overloaded.com]`
    - `com.apple.developer.icloud-services = [CloudKit]`
- 真实阻塞结论：
  - 带签名 macOS build 当前失败，不是代码失败，而是 provisioning profile 不具备 CloudKit / Push / container 权限。
  - 失败原文核心信息：
    - `Provisioning profile "Mac Team Provisioning Profile: *" doesn't include the Push Notifications capability.`
    - `... doesn't include the iCloud capability.`
    - `... doesn't support the iCloud.nolon.overloaded.com iCloud Container.`
    - `... doesn't include the com.apple.developer.aps-environment, com.apple.developer.icloud-container-identifiers, and com.apple.developer.icloud-services entitlements.`
- 语义判断：
  - 这说明当前 repo 的代码层、entitlements 声明层已经准备到位。
  - 但 Apple Developer / Certificates, Identifiers & Profiles 侧尚未把 `nolon.overloaded.com` 对应 App ID 和当前 macOS provisioning profile 配到支持：
    - iCloud
    - CloudKit
    - Push Notifications
    - `iCloud.nolon.overloaded.com` container
- 下一步外部动作：
  1. 在 Apple Developer 后台为 `nolon.overloaded.com` 开启 `iCloud` 与 `Push Notifications`
  2. 在 iCloud capability 里把 `iCloud.nolon.overloaded.com` 关联到该 App ID
  3. 重新生成或刷新 macOS Development provisioning profile
  4. 本机重新拉取 profile 后，再重跑带签名 build 和真容器联调
- 对 `v1` 状态的影响：
  - 代码实现层面：仍然完整
  - 真 CloudKit 运行态：当前被签名能力阻塞，尚不能宣称已完成跨设备 / 真容器验收

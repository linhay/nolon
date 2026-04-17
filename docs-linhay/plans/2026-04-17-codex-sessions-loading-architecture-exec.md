# 2026-04-17 Codex Sessions Loading Architecture Exec

## 背景
- `Codex Sessions` 在 3000+ 会话下的主要问题已经明确：Provider 侧累计全量 stream，ViewModel 侧每批全量替换 + 全量重建，导致 section 顺序在加载期间持续变化。
- 本计划基于 `docs-linhay/debate/20260417/codex-sessions/20260417-codex-sessions-loading-architecture-v01.md` 的共识结果编写。

## 目标
- 让项目列表在 3000+ 会话下稳定可滚动、可浏览。
- 保留 skeleton / 项目优先浏览体验，但不再出现 section 跳动。
- 把 `Codex Sessions` 的状态边界理清：轻量偏好独立持久化，高频交互态不跨重启恢复。
- 手动 refresh 走稳态单次重载，不追求流式实时感。

## 非目标
- 第一阶段不引入新 SQLite/FTS 索引层。
- 第一阶段不做跨重启的会话数据磁盘缓存。
- 第一阶段不持久化 `searchQuery` 和 `selectedSessionID`。

## BDD 验收场景

### 场景 1：大量会话首屏稳定
- Given provider 下存在 3000+ live / archived sessions
- When 用户首次进入 `Codex Sessions`
- Then 页面先看到 project skeleton
- And skeleton 顺序在流式填充完成前保持稳定
- And 用户可以连续滚动列表，不会因 section 重排而被打断

### 场景 2：增量填充不破坏选择态
- Given 用户已选中一个仍然存在的 session
- When 后续 delta batch 到达并更新相邻 section
- Then `selectedSessionID` 保持不变
- And 不会因为折叠态或临时不可见而自动跳回第一条

### 场景 3：搜索不再每击键全量重建
- Given 用户在搜索框持续输入
- When 查询内容快速变化
- Then ViewModel 只在 debounce 后触发查询刷新
- And 不会因为每个字符输入都重建全量 section

### 场景 4：轻量偏好跨重启恢复
- Given 用户将分组模式切换为 `provider`
- When 退出并重新打开应用
- Then `Codex Sessions` 恢复为 `provider` 分组
- And `searchQuery` 与 `selectedSessionID` 不自动恢复

### 场景 5：手动刷新稳态优先
- Given 用户已经在 `Codex Sessions` 浏览列表
- When 用户主动点击刷新
- Then 当前列表保持可浏览
- And refresh 不再重新进入实时 delta stream
- And 新 snapshot 准备完成后再一次性替换为最新结果

## TDD 计划

### 红灯测试
1. `CodexSessionStoreTests`
   - 新增 delta stream 契约测试：每批只输出增量，不重复发送旧 rows
   - 新增 completion event 测试：最后一批后能正确结束
   - 新增 3000+ 样本测试：累计输出条数应等于 session 总数，而不是倍增
2. `CodexSessionsTabViewModelTests`
   - skeleton 锁定顺序测试：流式阶段 section 顺序稳定，结束后才允许最终重排
   - selection 稳定性测试：session 仍存在时不回退第一条
   - debounce 查询测试：快速输入时重建次数受控
   - groupingMode 恢复测试：从 `CodexSessionsPreferencesStore` 正确恢复
3. 视需要新增轻量 store 测试
   - `CodexSessionsPreferencesStoreTests`：provider-scoped key、默认值、脏 key 清理

### 绿灯实现
1. Provider
   - 定义 `CodexSessionSnapshotDelta` 或等效增量事件结构
   - 保留现有 `loadProjectSkeletonSnapshot`
   - `snapshotStream` 改为增量 upsert 流
2. ViewModel
   - 引入 `rowsByID`
   - 引入 project/provider buckets 或等效 query state
   - 引入 `lockedSectionOrder`
   - `refresh` 改为 snapshot reload，而不是复用 stream reload
   - 搜索路径加 debounce
   - 改造 `repairSelection()`，避免“暂时不可见即回退”
3. 持久化
   - 新增 `CodexSessionsPreferencesStore`
   - phase 1 仅落 `groupingMode`

## 实施顺序

### Phase 1
- 先补 delta stream 与 ViewModel 稳定性测试，确认红灯
- 重构 Provider delta stream
- 重构 ViewModel 增量索引与 locked section order
- 新增 `CodexSessionsPreferencesStore`
- 只持久化 `groupingMode`

### Phase 1.5
- 评估 `expandedSectionIDs` 是否值得持久化
- 若加入，限制数量并在 provider 变化或 key 失效时清理

### Phase 2
- 根据首阶段真实启动耗时和用户体感，再决定是否增加可丢弃磁盘缓存
- 若加入缓存，放 `Application Support`，不得进入 `UserDefaults`

## 风险
- delta stream 改造会影响当前 `CodexSessionStoreTests` 的既有假设，需要同步改测试夹具。
- ViewModel 从全量数组改到增量索引后，usage 预取和 rewrite 范围计算可能受到影响，需要回归。
- skeleton 双扫描是否仍然值得保留，需要在首阶段完成后用日志复盘真实耗时。

## 验证
- 优先运行：
  - `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexSessionsTabViewModelTests`
  - `swift test --package-path libs/Providers --filter CodexSessionStoreTests`
- 实现完成后补一轮手工验证：
  - 3000+ 会话下首屏是否先出项目
  - 列表是否仍然跳动
  - 搜索和切组是否稳定

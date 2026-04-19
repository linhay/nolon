# Codex Sessions 首屏 Usage 排序修复设计（2026-04-19）

## 背景
- 用户已经把会话页排序偏好切到 `usage`。
- 当前首屏命中 cached snapshot 时，列表会先按时间顺序显示，随后 usage 异步回填后才重新按用量改序。
- 用户感知为“排序偏好恢复了，但首屏没有按指定排序方式工作”。

## 根因
- `CodexSessionsTabViewModel` 初始化时会正确恢复 `sortMode = .usage`。
- 但 `reload(mode: .initial)` 命中 cached snapshot 后，直接 `apply(snapshotPresentation:)`。
- `apply(snapshotPresentation:)` 之前没有同步装载 usage 索引。
- 排序函数 `usageOrderingValue(for:)` 对未加载 usage 的会话统一返回占位值：
  - `totalTokens = 0`
  - `availabilityRank = 1`
- 在所有项的 usage 排序键都相同时，`sortSessionRows` / `sortSections` 会回退到 `updatedAt`。

## 目标
1. 当排序偏好为 `usage` 且首屏命中 cached snapshot 时，首屏第一次展示就按 usage 排序。
2. 不改变现有 usage 回填链路，仍允许后台继续补全缺失 usage。
3. 不引入新的持久化结构，优先复用现有 `CodexSessionUsageIndex`。

## 非目标
1. 本轮不改 recent 排序语义。
2. 本轮不改会话详情 UI。
3. 本轮不引入新的 SQLite 表或 projection schema 变更。

## 方案

### 决策 1：增加 usage index 读取协议
- 为 `CodexSessionsTabViewModel` 增加专用协议：
  - `loadUsageIndexEntry(codexHome:rolloutPath:)`
- `CodexSessionStore` 直接复用已有 `loadUsageIndexEntry(...)` 实现。
- mock service 同步支持该入口，便于测试首屏行为。

### 决策 2：cached snapshot 应用前同步预热 usage 排序键
- 当满足以下条件时执行预热：
  - `mode == .initial`
  - 命中 `cached snapshot`
  - `sortMode == .usage`
  - `service` 支持 usage index 读取
- 针对 cached snapshot 的 rows 批量读取 usage index entry：
  - 成功命中 totals：写入 `usageBySessionID[sessionID] = .loaded(...)`
  - entry 存在但 totals 缺失，或明确不可用：写入 `.failed`
  - 读取失败：忽略，继续沿用后续异步 usage 回填链路

### 决策 3：只补首屏输入，不改排序主逻辑
- `sortSessionRows` / `sortSections` 保持不变。
- `primeVisibleSessionUsages()` / `drainUsageQueueIfNeeded()` 保持不变。
- 这样风险最小，且 recent/usage 的既有行为不会被重写。

## BDD 验收场景

### 场景 1：cached snapshot 首屏按 usage 排序
- Given 用户偏好排序方式为 `usage`
- And 首屏命中 cached snapshot
- And usage index 已经有对应会话的 totals
- When 会话页首次加载
- Then 首次展示的 section 顺序按聚合 usage 从高到低
- And 组内会话顺序按 usage 从高到低

### 场景 2：缺失 usage index 时保持可降级
- Given 用户偏好排序方式为 `usage`
- And 部分会话没有 usage index
- When 会话页首次加载
- Then 缺失项仍可按既有回退逻辑展示
- And 后续异步 usage 回填仍然生效

## 测试策略
1. 在 `CodexSessionsTabViewModelTests` 新增 cached snapshot + usage index 预热测试。
2. 回归已有测试：
   - `GivenLoadedSessions_WhenSortingByUsage_ThenRowsReorderByDescendingUsage`
   - `GivenLoadedSections_WhenSortingByUsage_ThenGroupsReorderByAggregatedUsageDescending`
   - `GivenRecentSortMode_WhenUsageBackfillCompletes_ThenSectionAndRowOrderStayRecent`

## 风险
- 如果同步读取 usage index 时把“暂未命中”错误地写成 `.failed`，可能降低后续排序稳定性，需要只在明确无 totals 时才记失败。
- cached snapshot rows 较多时，同步预热会增加一点首屏 CPU，但仍远低于重新扫描全量会话。

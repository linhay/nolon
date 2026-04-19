# Codex Sessions 排序链路优化设计（2026-04-19）

## 背景
- 当前 `Codex Sessions` 的 projection cache 已经让首屏列表能很快出现。
- 但用户感知仍然存在明显卡顿：列表先出现，排序规则随后较慢地稳定下来。
- 这类卡顿主要发生在 `CodexSessionsTabViewModel` 的内存侧分组与排序阶段，而不是磁盘扫描阶段。

## 问题定位

### 热点 1：`upsert` 阶段重复排序
- 当前 `upsert(row:)` 每插入一条会话：
  - 都会更新 project bucket
  - 都会更新 provider bucket
  - 且 `insert(...)` 会对整个 bucket 的 `rowIDs` 立即重新排序
- 结果是一次完整 snapshot 应用时，会产生大量 O(n log n) 级重复排序。

### 热点 2：section 构建阶段再次重复排序
- 当前 `makeProjectSectionStates()` / `makeProviderSectionStates()` 会从 bucket 取出 rows。
- `makeSectionState(...)` 内又会执行一次 `sessions.sorted(by:)`。
- 搜索路径 `makeSectionStates(from:groupingMode:)` 也存在类似重复排序。
- 结果是同一批 rows 在一次 rebuild 中被重复排序两到三次。

### 热点 3：排序职责分散
- bucket 写入阶段排序一次
- section 构建阶段排序一次
- usage 回填后 rebuild 时又重跑整个链路
- 排序职责没有收敛到单一层级，导致成本高且难以保证首屏稳定。

## 目标
1. 同一批 session rows 在一次 section rebuild 中只排序一次。
2. `snapshot/cached snapshot` 应用阶段不再在 `upsert` 时做 bucket 全量排序。
3. 保持现有排序语义不变：
   - `recent` 按最近时间
   - `usage` 按 token usage，回退到最近时间
4. 减少首屏 rows hydrate 后的排序延迟与主线程抖动。

## 非目标
1. 本轮不引入新的 SQLite usage/search 独立索引。
2. 本轮不调整会话详情 UI。
3. 本轮不改变会话分组语义。

## 方案

### 决策 1：bucket 只保存成员，不负责排序
- `projectRowIDsBySectionID` / `providerRowIDsBySectionID` 只做 membership index。
- `insert(...)` 改为：
  - 去重
  - append
  - 不排序

### 决策 2：section rows 只在 `makeSectionState(...)` 排序一次
- `makeProjectSectionStates()` / `makeProviderSectionStates()` 只负责取出 rows 和组装元信息。
- `makeSectionState(...)` 统一负责：
  - 按当前 sort mode 排 rows
  - 计算 `latestUpdatedAt`
  - 计算 `usageTotalTokens`
  - 计算 `editableThreadIDs`

### 决策 3：搜索路径复用同一排序职责
- `makeSectionStates(from:groupingMode:)` 不再预排序后再传给 `makeSectionState(...)`。
- 保证搜索路径与常规路径共享同一排序逻辑。

## BDD 验收场景

### 场景 1：recent 首屏顺序稳定
- Given cached snapshot 已经命中
- When 首屏 hydrate rows
- Then section 顺序一次生成
- And usage 异步回填不会改变 `recent` 排序结果

### 场景 2：usage 排序仍按 usage 语义工作
- Given 用户当前排序模式为 `usage`
- When usage 数据回填完成
- Then section 与 rows 仍按 usage 从高到低排序

### 场景 3：大批量 rows hydrate 不再在 bucket 写入阶段重复排序
- Given snapshot 含大量会话
- When 应用 snapshot
- Then bucket 仅做 membership 更新
- And 排序成本集中在 section rebuild

## 测试策略
1. `CodexSessionsTabViewModelTests`
   - 新增 `recent` 模式下 usage 回填不改序测试
   - 保留并通过现有 `usage` 行/组排序测试
2. 定向回归
   - `cached snapshot` 直出测试
   - `project skeleton` 占位与稳定顺序测试

## 风险
- 如果 bucket 不排序但某些路径隐含依赖 bucket 顺序，可能导致 section rows 顺序回归；需要测试兜住。
- `usage` 排序仍然依赖异步 usage 回填，本轮主要降低构建成本，不彻底解决 usage 首次无索引时的等待问题。

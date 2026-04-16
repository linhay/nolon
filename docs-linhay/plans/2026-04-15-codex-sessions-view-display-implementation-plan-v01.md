# Codex Sessions View Display Implementation Plan

**日期**：2026-04-15  
**状态**：可执行
**范围**：`Codex Sessions` 视图展示裁定落地  
**来源**：`debate` 纪要  
对应纪要：
[20260415-codex-sessions-view-display-v01.md](/Users/linhey/Desktop/FlowUp-Libs/nolon/docs-linhay/debate/20260415/codex-sessions/20260415-codex-sessions-view-display-v01.md)  
[20260415-codex-sessions-view-display-implementation-v01.md](/Users/linhey/Desktop/FlowUp-Libs/nolon/docs-linhay/debate/20260415/codex-sessions/20260415-codex-sessions-view-display-implementation-v01.md)

## 背景

本计划承接两轮 `debate` 共识，目标是把 `Codex Sessions` 当前“信息过多、层级分散、状态重复、主次不清”的问题，稳定收敛成一套可回归、可维护的展示实现。

已经确认的业务裁定如下：

1. 主视图优先显示 `ReadOnly` 与 `Live`
2. `Archived` 默认下沉到折叠区或次级信息区
3. `subagent` 默认下沉到折叠区或次级信息区
4. `source / originator / forked_from` 默认进入次级信息或 menu
5. `regular / medium` 隐藏 `summary`，`compact` 保留 1-2 行
6. `provider` 分组下弱化或隐藏 row 的 `Provider` 列
7. 移除 `Showing x / y`，保留 `Expand / Collapse`

## 目标

1. 让主视图只承载“浏览决策所需的最小信息集”
2. 保持 `project-first` 浏览优先，不破坏现有迁移与诊断能力
3. 先以最小改动完成裁定落地，再决定是否要扩展模型
4. 以测试先行为前提，确保本轮改动可回归

## 非目标

1. 不在本轮引入新的 provider usage / intraday 逻辑
2. 不在本轮改写底层 session 扫描协议
3. 不在本轮新增持久化字段
4. 不在本轮改动 rewrite 业务流程与确认弹窗统计逻辑

## 当前约束

1. 默认分组仍是 `.project`，并允许切换到 `.provider`
2. 现有 Section 卡片仍以固定六列表格为主，窄屏降级到 compact
3. 快照测试已经锁定了 regular / medium / narrow 三类断点
4. `CodexSessionsSectionDataBuilder` 已承接多数展示语义转换
5. `CodexSessionsModels` 目前已足够表达大部分裁定；模型扩展不是默认路径

## 关键代码事实

1. `groupingMode` 默认是 `.project`，且可切换 `.provider`
   - [CodexSessionsTabViewModel.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift#L223)
   - [CodexSessionsTabViewModel.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift#L475)
2. Section 视图当前是六列表头，并在中/窄宽度自动降级
   - [UnifiedCodexSessionViews.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexSessionViews.swift#L343)
   - [UnifiedCodexSessionViews.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexSessionViews.swift#L396)
3. `Showing x / y` 由 builder 生成，不是底层数据事实
   - [CodexSessionsSectionDataBuilder.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsSectionDataBuilder.swift#L120)
4. `source / originator` 当前进了 row 主 metadata，同时又进 menu metadata
   - [CodexSessionsSectionDataBuilder.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsSectionDataBuilder.swift#L201)
   - [CodexSessionsSectionDataBuilder.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsSectionDataBuilder.swift#L243)
5. `ReadOnly` 直接来源于 `editable == false`，属于可操作性状态
   - [CodexSessionsSectionDataBuilder.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsSectionDataBuilder.swift#L188)
6. `Live / Archived` 是生命周期状态，来自 `archived`
   - [CodexSessionsSectionDataBuilder.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsSectionDataBuilder.swift#L174)
7. `archived` 的底层来源是 rollout 文件是否位于 `archived_sessions`
   - [CodexSessionScanner.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionScanner.swift#L115)
8. `editable` 的底层来源是 `threadID` 是否存在
   - [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift#L679)

## 数据与展示定义

### 状态来源

1. `ReadOnly`
   - 来源：`editable == false`
   - 含义：不可执行 rewrite / 不可参与可编辑动作
2. `Live`
   - 来源：`archived == false`
   - 含义：生命周期默认态
3. `Archived`
   - 来源：`archived == true`
   - 含义：生命周期归档态
4. `subagent`
   - 本轮视为来源/来源标签的一种，默认不进主视图首屏

### 主视图信息最小集

1. section：
   - 标题
   - 路径/分组上下文
   - 能力类型
   - `Live`
   - `Archived` 聚合统计
2. row：
   - `title`
   - `ID`
   - `time`
   - `usage`
   - 主状态：`ReadOnly`、`Live`

### 默认折叠信息

1. `Archived`
2. `subagent`
3. `source`
4. `originator`
5. `forked_from`
6. `rolloutPath`
7. `DB rows`
8. `regular / medium` 下的 `summary`

## BDD 验收场景

1. Given 当前分组为 `project`
   When section 被渲染
   Then 主视图不显示 `Showing x / y`

2. Given 当前分组为 `provider`
   When row 被渲染
   Then `Provider` 列被隐藏或弱化，不再与 section 标题重复争夺注意力

3. Given row 处于 `ReadOnly`
   When 主视图渲染状态标签
   Then `ReadOnly` 成为第一状态标签

4. Given row 处于 `Archived`
   When 主视图渲染
   Then `Archived` 不占据首屏主标签位，进入折叠区或次级信息区

5. Given row 来源是 `subagent`
   When 主视图渲染
   Then `subagent` 不占据首屏主标签位，进入折叠区或次级信息区

6. Given 当前断点是 `regular` 或 `medium`
   When row 渲染 `name` 区域
   Then `summary` 默认不显示

7. Given 当前断点是 `compact`
   When row 渲染 `name` 区域
   Then `summary` 显示且限制为 1-2 行

8. Given row 存在 `source / originator / forked_from`
   When 主视图渲染
   Then 这些信息不作为主 metadata 重复展示，而在 menu 或次级信息区可达

9. Given 当前 section 超过默认可见条数
   When section 首次渲染
   Then 使用 `Expand / Collapse` 控制溢出，而不是 `Showing x / y`

## 代码边界

### 只动渲染层即可完成

1. row / section 的视觉排列
2. `summary` 在不同断点的显示策略
3. compact / table 下状态标签顺序
4. 某些列的隐藏或弱化

主文件：

1. [UnifiedCodexSessionViews.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexSessionViews.swift)

### 需要动 builder / viewmodel 才能完成

1. `Showing x / y` 的移除
2. `source / originator / forked_from` 的主次级信息分层
3. `Archived / subagent` 的默认下沉策略
4. `provider` 分组下的列语义

主文件：

1. [CodexSessionsSectionDataBuilder.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsSectionDataBuilder.swift)
2. [CodexSessionsTabViewModel.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift)

### 非必要不动的层

1. [CodexSessionsModels.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/NolonUIFoundation/Sources/NolonUIFoundation/CodexSessionsModels.swift)
2. [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift)
3. [CodexSessionScanner.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionScanner.swift)

## Phase 0：测试先行

### 目标

先把新展示契约写成失败测试，锁定边界。

### 进入条件

1. 本计划确认
2. 不直接改实现文件

### 文件清单

1. [CodexSessionsSectionDataBuilderTests.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolonTests/CodexSessionsSectionDataBuilderTests.swift)
2. [CodexSessionsCardSnapshotTests.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolonTests/CodexSessionsCardSnapshotTests.swift)

### 任务拆解

1. Builder 测试新增/收紧断言：
   - 不再要求 `visible` badge
   - `nameMetadataItems` 不再默认包含 `source / originator`
   - `forked_from` 不再作为主视图重点断言
   - mixed-provider 项目继续保持 row-scoped rewrite
2. Snapshot 测试更新优先级：
   - `project-first-overview-table`
   - `provider-secondary-section`
   - `medium-width-project-section`
   - `narrow-width-project-section`
   - `expanded-project-section`

### 退出条件

1. 至少 1 个 builder 测试红灯
2. 至少 1 个 snapshot 用例需要更新基线

### 验证命令

1. `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexSessionsSectionDataBuilderTests`
2. `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexSessionsCardSnapshotTests`

### 风险

1. 当前快照测试存在录制倾向，红绿灯信号可能被弱化

### 回滚点

1. 恢复当前 snapshot baseline 与旧断言

## Phase 1：渲染层与 Builder 落地

### 目标

在不动数据模型的前提下，把裁定尽可能全部落到 UI 与 builder。

### 进入条件

1. `Phase 0` 测试红灯已确认

### 文件清单

1. [UnifiedCodexSessionViews.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexSessionViews.swift)
2. [CodexSessionsSectionDataBuilder.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsSectionDataBuilder.swift)

### 任务拆解

1. 移除 `Showing x / y`
2. `regular / medium` 隐藏 `summary`
3. `compact` 将 `summary` 限制为 1-2 行
4. `ReadOnly` 成为 row 主状态标签
5. `Archived` 下沉到折叠区或次级信息
6. `subagent` 下沉到折叠区或次级信息
7. `source / originator / forked_from` 下沉到 menu 或次级信息
8. `provider` 分组下隐藏或弱化 row `Provider` 列

### 实现顺序

1. 先改 builder 输出
2. 再改 `UnifiedCodexSessionViews` 渲染
3. 最后更新 snapshot baseline

### 退出条件

1. `Phase 0` 测试全部转绿
2. 不引入模型字段变更

### 验证命令

1. 通过 `Phase 0` 全部命令
2. 可选全量回归：
   - `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS'`

### 风险

1. 过度下沉元数据后，同名 session 的辨识成本上升
2. provider 分组下列隐藏可能导致布局波动

### 回滚点

1. 仅回退 `UnifiedCodexSessionViews` 与 `CodexSessionsSectionDataBuilder`

## Phase 2：ViewModel / 模型可选增强

### 目标

仅在 `Phase 1` 的表达力不足时，再进入跨层扩展。

### 触发条件

满足任一条件才进入：

1. `subagent` 无法仅凭 builder / 视图层稳定表达
2. provider 分组上下文在现有 row / section 数据模型中不够清晰
3. 需要新增“折叠标签”或“次级来源”的显式模型字段

### 候选文件

1. [CodexSessionsTabViewModel.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift)
2. [CodexSessionsModels.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/NolonUIFoundation/Sources/NolonUIFoundation/CodexSessionsModels.swift)

### 候选任务

1. 为 row / section 显式补充“折叠标签”表达
2. 增加 provider 分组上下文字段
3. 为 `subagent` 增加稳定判定与显式消费点

### 退出条件

1. 新字段与新语义都有单元测试覆盖
2. 所有现有快照回归通过

### 风险

1. 把本轮本可在渲染层解决的问题，上升成跨层重构

### 回滚点

1. 回退到 `Phase 1`，维持现有模型结构

## 文件级任务矩阵

### 必改

1. [CodexSessionsSectionDataBuilder.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsSectionDataBuilder.swift)
2. [UnifiedCodexSessionViews.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexSessionViews.swift)
3. [CodexSessionsSectionDataBuilderTests.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolonTests/CodexSessionsSectionDataBuilderTests.swift)
4. [CodexSessionsCardSnapshotTests.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolonTests/CodexSessionsCardSnapshotTests.swift)

### 条件触发后再改

1. [CodexSessionsTabViewModel.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift)
2. [CodexSessionsModels.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/NolonUIFoundation/Sources/NolonUIFoundation/CodexSessionsModels.swift)

### 本轮明确不改

1. [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift)
2. [CodexSessionScanner.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionScanner.swift)

## 测试矩阵

### App 层

1. `CodexSessionsSectionDataBuilderTests`
   - badges
   - metadata 分层
   - mixed-provider 行级 rewrite
   - usage placeholder / loaded / failed
2. `CodexSessionsCardSnapshotTests`
   - regular
   - medium
   - narrow / compact
   - provider-secondary

### 条件触发后增加

1. `CodexSessionsTabViewModelTests`
   - 如果 `Phase 2` 改到分组与展示状态映射

## 执行顺序

1. 更新 `Phase 0` 测试
2. 跑失败测试，确认红灯
3. 实现 `Phase 1`
4. 跑 builder + snapshot，确认绿灯
5. 仅在必要时进入 `Phase 2`
6. 更新文档与记忆

## 文档联动

### 必须同步

1. `debate` 纪要
   - 记录裁定与计划收敛过程
2. `plans` 主文档
   - 记录 phases、门禁、回滚点
3. `memory`
   - 记录计划完成与实际进入的 phase

### 条件触发后同步

1. `features`
   - 若验收口径被进一步改写，再回写 feature 文档
2. `screenshots`
   - 若需要 before / after 视觉对比，再补截图归档

## 测试门禁

1. builder 测试必须先红灯，再转绿灯
2. snapshot 必须覆盖 regular / medium / narrow / provider-secondary
3. 未跑测试，不得宣布阶段完成

## 回滚矩阵

1. 仅视觉出问题：
   - 回退 [UnifiedCodexSessionViews.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexSessionViews.swift)
2. 语义映射出问题：
   - 回退 [CodexSessionsSectionDataBuilder.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsSectionDataBuilder.swift)
3. 跨层表达出问题：
   - 回退 `Phase 2` 引入的 `ViewModel / Models` 改动，保留 `Phase 1`

## 完成定义（DoD）

1. 主视图不再让 `Archived` 与 `subagent` 抢占首屏标签
2. `ReadOnly` 与 `Live` 的主视图优先级稳定
3. `source / originator / forked_from` 不再在主视图和 menu 双重抢占
4. `regular / medium / narrow` 三个断点下布局与快照稳定
5. builder 与 snapshot 测试全部通过
6. `debate`、`plans`、`memory` 三类文档同步完成

## 执行结果

### 2026-04-15 Phase 0 - 2 完成情况

1. `Phase 0` 已完成
   - `CodexSessionsSectionDataBuilderTests` 先改测试并确认红灯
   - 红灯失败点与计划一致：
     - `visible` badge 仍存在
     - `source / originator` 仍出现在主 metadata
2. `Phase 1` 已完成
   - [CodexSessionsSectionDataBuilder.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsSectionDataBuilder.swift)
     - 移除 `Showing x / y` badge
     - `nameMetadataItems` 默认清空
     - `forked_from / source / originator` 统一下沉到 `menuMetadataItems`
   - [UnifiedCodexSessionViews.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexSessionViews.swift)
     - `regular / medium` 不再显示 `summary`
     - `compact` 将 `summary` 收敛到 `2` 行
     - row 主状态调整为 `ReadOnly -> Live`
     - `Archived` 从首屏主标签移除，改为 menu 折叠信息
     - provider 分组在冗余场景下隐藏 `Provider` 列和 compact provider 卡片
3. `Phase 2` 未触发
   - 本轮无需改 [CodexSessionsTabViewModel.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift)
   - 本轮无需改 [CodexSessionsModels.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/NolonUIFoundation/Sources/NolonUIFoundation/CodexSessionsModels.swift)
   - 结论：当前 builder + 视图层已经足以稳定表达新展示契约

### 验证结果

1. `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexSessionsSectionDataBuilderTests`
   - 结果：`3` 个测试通过，`0` 失败
2. `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexSessionsCardSnapshotTests`
   - 结果：`5` 个测试通过，`0` 失败

### 残余风险

1. [CodexSessionsSectionDataBuilder.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsSectionDataBuilder.swift) 仍有既有 Swift 并发 warning：
   - `defaultVisibleSessionCountPerSection` 从 `nonisolated` 上下文读取
   - 本轮未扩大改动范围处理

# Codex Sessions View Display Implementation Plan

**日期**：2026-04-15  
**范围**：`Codex Sessions` 视图展示裁定落地  
**来源**：`debate` 纪要  
对应纪要：
[20260415-codex-sessions-view-display-v01.md](/Users/linhey/Desktop/FlowUp-Libs/nolon/docs-linhay/debate/20260415/codex-sessions-view-display/20260415-codex-sessions-view-display-v01.md)  
[20260415-codex-sessions-view-display-implementation-v01.md](/Users/linhey/Desktop/FlowUp-Libs/nolon/docs-linhay/debate/20260415/codex-sessions-view-display/20260415-codex-sessions-view-display-implementation-v01.md)

## 目标

把已经确认的展示裁定稳定落地到 `Codex Sessions`：

1. 主视图优先显示 `ReadOnly` 与 `Live`
2. `Archived` 与 `subagent` 默认下沉到折叠区或次级信息区
3. `source / originator / forked_from` 不再抢占主视图
4. `regular / medium` 隐藏 `summary`，`compact` 保留 1-2 行
5. `provider` 分组下弱化或隐藏 row 的 `Provider` 列
6. 移除 `Showing x / y`，保留 `Expand / Collapse`

## 非目标

1. 不在本轮引入新的 provider usage / intraday 逻辑
2. 不在本轮改写底层 session 扫描协议
3. 不把“来源排序”扩展成新的底层持久字段

## 代码边界

### 只动渲染层即可完成

1. row / section 的视觉排列
2. `summary` 在不同断点的显示策略
3. compact / table 下状态标签显示顺序
4. 某些列的隐藏或弱化

主文件：

1. [UnifiedCodexSessionViews.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexSessionViews.swift)

### 需要动 builder / viewmodel 才能完成

1. `Showing x / y` 的移除
2. `source / originator / forked_from` 的主次级信息分层
3. `Archived` / `subagent` 的默认下沉策略
4. `provider` 分组下的列语义

主文件：

1. [CodexSessionsSectionDataBuilder.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsSectionDataBuilder.swift)
2. [CodexSessionsTabViewModel.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift)

### 非必要不动的层

1. [CodexSessionsModels.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/NolonUIFoundation/Sources/NolonUIFoundation/CodexSessionsModels.swift)
2. [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift)
3. [CodexSessionScanner.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionScanner.swift)

说明：

- 只有当 `Phase 1` 无法表达裁定时，才进入模型扩展或底层契约调整

## Phase 0：测试先行

### 目标

先把新展示契约固化成失败测试，避免后续实现偏航。

### 改动文件

1. [CodexSessionsSectionDataBuilderTests.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolonTests/CodexSessionsSectionDataBuilderTests.swift)
2. [CodexSessionsCardSnapshotTests.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolonTests/CodexSessionsCardSnapshotTests.swift)

### 新/改断言

1. builder 断言
   - 不再要求 `Showing x / y`
   - `source / originator` 默认不出现在 row 主 metadata
   - `forked_from` 默认不再作为主视图重点字段
   - mixed-provider 项目仍保持 row-scoped rewrite
2. snapshot 断言
   - `project-first-overview-table`
   - `provider-secondary-section`
   - `medium-width-project-section`
   - `narrow-width-project-section`
   - `expanded-project-section`

### 验证

1. `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexSessionsSectionDataBuilderTests`
2. `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexSessionsCardSnapshotTests`

### 风险

1. 现有快照测试带录制倾向，可能掩盖真实回归

### 回滚点

1. 回到当前 snapshot baseline 与现有 builder 断言

## Phase 1：渲染层与 Builder 落地

### 目标

在不动数据模型的前提下，把主要展示裁定落到 UI 与 builder。

### 改动文件

1. [UnifiedCodexSessionViews.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexSessionViews.swift)
2. [CodexSessionsSectionDataBuilder.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsSectionDataBuilder.swift)

### 具体任务

1. 移除 `Showing x / y`
2. `regular / medium` 隐藏 `summary`
3. `compact` 把 `summary` 限制为 1-2 行
4. `ReadOnly` 成为 row 主状态标签
5. `Archived` 下沉到折叠区或次级信息
6. `subagent` 下沉到折叠区或次级信息
7. `source / originator / forked_from` 下沉到 menu 或次级信息
8. `provider` 分组下隐藏或弱化 row `Provider` 列

### 验证

1. 通过 `Phase 0` 的全部测试
2. 手动检查三种断点下的状态密度

### 风险

1. 过度下沉元数据后，同名 session 的辨识成本上升
2. provider 分组下列隐藏可能导致布局波动

### 回滚点

1. 保留 `CodexSessionsModels` 不变，只回退 `UnifiedCodexSessionViews` 与 `SectionDataBuilder`

## Phase 2：ViewModel / 模型可选增强

### 触发条件

仅当 `Phase 1` 无法稳定表达裁定时再做。

### 可能改动

1. [CodexSessionsTabViewModel.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift)
2. [CodexSessionsModels.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/NolonUIFoundation/Sources/NolonUIFoundation/CodexSessionsModels.swift)

### 候选任务

1. 为 row / section 显式补充“折叠标签”或“次级来源”表达
2. 为 provider 分组下的列策略提供更清晰的上下文字段
3. 若后续必须稳定识别 `subagent`，再补 builder / viewmodel 层的显式判定逻辑

### 验证

1. 重新跑 `nolon-tests`
2. 补新增字段的单元测试

### 风险

1. 过早扩展模型会把本轮本可在渲染层解决的问题，提升成跨层重构

### 回滚点

1. 回退到 `Phase 1`，维持现有模型结构

## 文件级任务清单

### 必改

1. [CodexSessionsSectionDataBuilder.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsSectionDataBuilder.swift)
2. [UnifiedCodexSessionViews.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexSessionViews.swift)
3. [CodexSessionsSectionDataBuilderTests.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolonTests/CodexSessionsSectionDataBuilderTests.swift)
4. [CodexSessionsCardSnapshotTests.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolonTests/CodexSessionsCardSnapshotTests.swift)

### 条件触发后再改

1. [CodexSessionsTabViewModel.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift)
2. [CodexSessionsModels.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/NolonUIFoundation/Sources/NolonUIFoundation/CodexSessionsModels.swift)

## 测试门禁

1. builder 测试先红灯，再转绿灯
2. snapshot 测试至少覆盖 regular / medium / narrow / provider-secondary
3. 未跑测试不得进入下一 phase

## 执行顺序

1. 更新 `Phase 0` 测试
2. 跑失败测试确认红灯
3. 实现 `Phase 1`
4. 跑测试转绿
5. 若仍表达不了裁定，再评估是否进入 `Phase 2`

## 完成定义

1. 主视图不再让 `Archived` 与 `subagent` 抢占首屏标签
2. `ReadOnly` 与 `Live` 的主视图优先级稳定
3. 三个断点下的布局与快照稳定
4. builder 与 snapshot 测试均通过

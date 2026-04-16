# Codex Sessions Overview 4 -> 1 执行计划

**日期**：2026-04-16  
**状态**：已完成  
**范围**：`Codex Sessions` overview 状态矩阵测试与 `Compact / Diagnostic` 双态密度  
**来源**：
- [20260416-codex-sessions-implementation-feasibility-v01.md](/Users/linhey/Desktop/FlowUp-Libs/nolon/docs-linhay/debate/20260416/codex-sessions/20260416-codex-sessions-implementation-feasibility-v01.md)
- [codex-sessions-overview-density-and-state-matrix-implementation-2026-04-16.md](/Users/linhey/Desktop/FlowUp-Libs/nolon/docs-linhay/dev/codex-sessions-overview-density-and-state-matrix-implementation-2026-04-16.md)

## 背景

本计划把已裁定的优先级真正落地：

1. 先做 `4`：补 overview 状态矩阵测试与可测试 mapper
2. 再做 `1`：在测试护栏下实现 `Compact / Diagnostic`

## 目标

1. overview 状态组合脱离 `CodexSessionsTabView` 内联条件，转成可测试 mapper
2. 用单元测试锁定 overview 的模式切换、状态输出和 refresh 禁用契约
3. 在不引入状态中心和后台任务模型的前提下实现双态密度

## 非目标

1. 不实现 `2. 状态中心`
2. 不实现 `3. 后台同步任务模型`
3. 不修改底层扫描、rewrite、分页协议

## BDD 场景

1. Given project grouping 且页面处于 idle
   When 构建 overview mapper 输出
   Then 输出 `Compact` 模式、短版 subtitle 和紧凑 metrics。

2. Given provider grouping 且页面处于 idle
   When 构建 overview mapper 输出
   Then 仍输出 `Compact` 模式，但文案切到 provider 视角。

3. Given 页面正在后台扫描且已存在 section
   When 构建 overview mapper 输出
   Then 输出 `Diagnostic` 模式，并保留 scanning message。

4. Given 页面正在 preparing rewrite 或 applying rewrite
   When 构建 overview mapper 输出
   Then refresh disabled 为 `true`，并输出 `Diagnostic` 模式。

5. Given `Compact` 与 `Diagnostic` overview 分别渲染
   When 运行快照验证
   Then 卡片层级和信息密度符合双态契约。

## 执行顺序

### Phase 0：红灯测试

1. 新增 overview mapper 测试文件
2. 写出至少 4 个状态矩阵用例，并确认当前代码无法直接通过
3. 先不改 overview card 视图实现

### Phase 1：最小实现

1. 抽出 overview mapper / builder
2. `CodexSessionsTabView` 改为消费 mapper 输出
3. 扩展 `CodexSessionsOverviewData`，增加模式字段或等价展示语义

### Phase 2：双态 UI

1. `Compact` 默认隐藏非关键诊断信息
2. `Diagnostic` 保留完整 subtitle 和完整 metrics
3. 更新 overview 快照夹具，覆盖两种模式

### Phase 3：回归验证

1. 跑 overview mapper 单测
2. 跑 `CodexSessionsCardSnapshotTests`
3. 跑 `CodexSessionsTabViewModelTests`，确认未破坏已有链路

## 文件清单

1. `nolon/Skills/Domain/Providers/Views/CodexSessionsTabView.swift`
2. `nolon/Skills/Domain/Providers/Views/` 下新增 overview mapper / builder
3. `libs/NolonUIFoundation/Sources/NolonUIFoundation/CodexSessionsModels.swift`
4. `libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexSessionViews.swift`
5. `nolonTests/` 下新增 overview mapper 测试
6. `nolonTests/CodexSessionsCardSnapshotTests.swift`

## 验证命令

1. `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexSessionsOverviewDataBuilderTests`
2. `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexSessionsCardSnapshotTests`
3. `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexSessionsTabViewModelTests`

## 完成定义

1. overview mapper 状态矩阵测试通过
2. overview 双态快照通过或完成基线更新
3. `CodexSessionsTabViewModelTests` 无回归
4. memory 已同步，且执行 `qmd update && qmd embed`

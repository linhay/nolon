# Codex Sessions Overview 状态矩阵与双态密度实现说明（2026-04-16）

## 背景

`Codex Sessions` 当前 overview card 的问题不在于单个常量，而在于它只有一套固定输出路径：

1. `CodexSessionsTabView` 直接在视图里拼 `CodexSessionsOverviewData`
2. `CodexSessionsOverviewData` 只有平铺字段
3. `CodexSessionsOverviewCardView` 固定按 `header -> statusBanners -> metrics` 渲染

这导致两个问题：

1. overview 没有独立的可测试映射层，状态组合只能在视图快照里间接验证
2. 无法在不扩展底层状态模型的前提下，为 overview 增加“默认紧凑、诊断按需展开”的展示密度

## 本轮目标

1. 先抽出 overview mapper / builder，把视图内的状态拼装逻辑迁到可测试层
2. 先补 overview 状态矩阵测试，锁定 `Compact / Diagnostic` 的切换契约
3. 再在 mapper 输出上增加双态密度字段与紧凑指标策略

## 非目标

1. 不实现状态中心
2. 不实现后台同步任务模型
3. 不引入新的持久化状态
4. 不调整 rewrite 业务流程

## 关键代码事实

1. `CodexSessionsTabView` 当前直接内联构建 `CodexSessionsOverviewData`
   - [CodexSessionsTabView.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsTabView.swift#L197)
2. `CodexSessionsOverviewData` 当前只有平铺字段，没有密度语义
   - [CodexSessionsModels.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/NolonUIFoundation/Sources/NolonUIFoundation/CodexSessionsModels.swift#L87)
3. `CodexSessionsOverviewCardView` 已具备 header 自适应和状态/指标分区，但没有模式切换
   - [UnifiedCodexSessionViews.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexSessionViews.swift#L20)
4. `CodexSessionsTabViewModel` 当前只有 `isLoading / isPreparingRewrite / isApplyingRewrite / statusMessage`
   - [CodexSessionsTabViewModel.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift#L238)

## 设计裁定

### 1. 先抽 mapper，不直接在 View 里写条件

原因：

1. 这样可以把 `overview` 的状态组合从 SwiftUI 视图中剥离出来
2. 可以用普通单测覆盖状态矩阵，不需要每次都靠 snapshot 断言
3. 后续如果真的要做 `状态中心`，也能在 mapper 层平滑演进

### 2. 双态密度只解决“展示密度”，不扩大状态语义

本轮 `Compact / Diagnostic` 只是渲染模式，不新增后台任务或优先级队列。也就是说：

1. 输入仍然来自现有的 `isLoading / isPreparingRewrite / isApplyingRewrite / statusMessage`
2. `Compact` 和 `Diagnostic` 只决定：
   - subtitle 用短版还是长版
   - metrics 用紧凑集还是完整集
   - 是否暴露诊断提示区

### 3. `Compact` 为默认，`Diagnostic` 由运行态触发

本轮不额外引入手动切换控件。先采用最小契约：

1. idle 浏览态默认 `Compact`
2. scanning / preparing rewrite / applying rewrite 时切到 `Diagnostic`

这样做的原因是：

1. 不需要新增交互或持久化
2. 符合“项目浏览优先、诊断可达”的页面定位
3. 可以先验证双态结构是否足够稳定

## 测试策略

### 单元测试

新增 overview mapper 测试，覆盖至少这些组合：

1. project + idle -> `Compact`
2. provider + idle -> `Compact`
3. loading with existing content -> `Diagnostic`
4. preparing rewrite -> `Diagnostic`
5. applying rewrite -> `Diagnostic`
6. status message + scanning 并存 -> 断言双状态输出与 refresh disabled 契约

### 快照测试

保留现有 overview 快照，并新增或更新：

1. `Compact` 模式快照
2. `Diagnostic` 模式快照

目的不是替代单测，而是确保双态视觉层级不回退。

## 实现落点

1. `nolon/Skills/Domain/Providers/Views/`
   - 新增 overview mapper / builder
   - `CodexSessionsTabView` 改为消费 mapper 输出
2. `libs/NolonUIFoundation/`
   - `CodexSessionsOverviewData` 增加密度字段或等价展示语义
3. `libs/NolonUI/`
   - `CodexSessionsOverviewCardView` 根据模式切换 subtitle / metrics / 诊断区域展示
4. `nolonTests/`
   - 新增 overview mapper 状态矩阵测试
   - 更新 overview snapshot

## 风险与控制

1. 风险：把 `Compact / Diagnostic` 直接做成新的复杂状态机
   - 控制：本轮只接受双态展示契约，不引入第三种模式
2. 风险：为了测试方便把 viewModel 逻辑拆得过深
   - 控制：只抽 overview mapper，不重写 session list 逻辑
3. 风险：snapshot 过多导致维护成本高
   - 控制：状态组合以单测为主，快照只保留代表性模式

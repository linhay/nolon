# codex-sessions-implementation-feasibility

**日期**：20260416
**模式**：合作型
**参与者**：Gemini CLI / Claude Code / Codex subagent（阻塞）/ 主持人 Codex
**总轮次**：1 / 60
**结束原因**：已完成“先实现什么”的裁定；Claude Code 与 Codex subagent 工具阻塞，不影响最终排序

## 辩论背景
用户追问上一轮引申出来的 4 个候选方向，到底哪些“能实现”，以及哪些适合“先实现”：

1. `overview card` 做成 `Compact / Diagnostic` 两档模式
2. 状态区升级为“状态中心”，不再只是多字符串 banner
3. 刷新能力拆成后台同步任务模型，不只是 disabled refresh 按钮
4. 测试补成 `overview` 状态矩阵，不只靠 snapshot

本轮目标不是继续发散产品建议，而是基于当前代码状态裁定：
- 哪些现在就能低风险落地
- 哪些虽然能做，但不适合排在最前
- 哪些需要单独设计，不应混进本轮实现

## 代码范围
- `nolon/Skills/Domain/Providers/Views/CodexSessionsTabView.swift`
- `nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift`
- `libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexSessionViews.swift`
- `libs/NolonUIFoundation/Sources/NolonUIFoundation/CodexSessionsModels.swift`
- `nolonTests/CodexSessionsCardSnapshotTests.swift`

## 各方观点

### [Gemini CLI]
- 论点：`4` 应该最先做。  
  引用：`nolonTests/CodexSessionsCardSnapshotTests.swift:23-171`  
  代码事实：当前测试主要围绕 `makeOverviewCard()` 的固定夹具做 snapshot 验证，没有系统覆盖 `statusMessage`、`backgroundScanningMessage`、`isRefreshDisabled` 等组合状态。  
  结论：应优先补状态矩阵测试，先建立回归护栏。

- 论点：`2` 具备一定可实现性，但优先级判断偏乐观。  
  引用：`libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexSessionViews.swift:136-164`; `libs/NolonUIFoundation/Sources/NolonUIFoundation/CodexSessionsModels.swift:87-124`  
  代码事实：UI 层已经有 `statusBanners` 容器，但 `CodexSessionsOverviewData` 仍只有 `statusMessage/backgroundScanningMessage/paginationMessage` 这类平铺字段。  
  结论：`2` 能做，但它不是纯 UI 重排，仍需要先扩状态模型。

### [Claude Code]
- 未形成有效观点。  
  工具事实：`claude -p` 返回 `There's an issue with the selected model (claude-opus-4-6[1m])`。  
  结论：记为工具阻塞，不纳入有效票。

### [Codex subagent]
- 未形成有效观点。  
  工具事实：子代理返回 `503 Service Unavailable: auth_unavailable`。  
  结论：记为工具阻塞，不纳入有效票。

## 主持人裁定

- 论点：`1` 现在可以先做，而且是最适合先做的 UI 方案。  
  引用：`libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexSessionViews.swift:20-35`; `libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexSessionViews.swift:46-101`; `nolon/Skills/Domain/Providers/Views/CodexSessionsTabView.swift:197-248`  
  代码事实：当前 overview card 已经固定为 `header -> statusBanners -> metrics` 三段结构，header 已具备横竖切换能力，subtitle 只是 `.lineLimit(2)`，因此增加 `Compact / Diagnostic` 本质上是展示密度分层，不需要先重做数据层。  
  结论：`1` 能实现，且改动主要集中在 `CodexSessionsOverviewData` 展示策略和 `CodexSessionsOverviewCardView`，风险最低。

- 论点：`4` 应与 `1` 一起优先，而不是等到后面再补。  
  引用：`nolonTests/CodexSessionsCardSnapshotTests.swift:23-171`; `nolon/Skills/Domain/Providers/Views/CodexSessionsTabView.swift:239-272`  
  代码事实：运行时代码至少存在 `groupingMode`、`statusMessage`、`backgroundScanningMessage`、`isRefreshDisabled` 等状态维度，但当前测试几乎都停留在视觉快照和固定夹具。  
  结论：`4` 不但能实现，而且应先于 `2/3` 落地，作为后续状态重构护栏。

- 论点：`2` 能实现，但不建议现在先做。  
  引用：`libs/NolonUIFoundation/Sources/NolonUIFoundation/CodexSessionsModels.swift:87-124`; `nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift:238-258`; `nolon/Skills/Domain/Providers/Views/CodexSessionsTabView.swift:240-248`  
  代码事实：当前 overview 输入模型仍是若干平铺字段，ViewModel 公开状态也只有 `isLoading/isPreparingRewrite/isApplyingRewrite/statusMessage` 等散装布尔值和单字符串；`paginationMessage` 虽预留但没有真实状态来源。  
  结论：`2` 不是“不能做”，但它已经跨入状态建模问题，不适合作为当前第一优先级。

- 论点：`3` 能实现，但实现成本最高，必须单列设计。  
  引用：`libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexSessionViews.swift:127-134`; `nolon/Skills/Domain/Providers/Views/CodexSessionsTabView.swift:24-35`; `nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift:241-246`; `nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift:302-330`  
  代码事实：当前 UI 只有一个 `Refresh` 按钮；disabled 条件只绑定几个布尔值；ViewModel 没有后台任务实体、取消/重试能力、分页能力，甚至 `remainingSessionCount` 和 `canLoadMore` 仍是常量值。  
  结论：`3` 需要单独设计刷新/扫描任务模型，不能作为“顺手先做”的项塞进当前实现轮。

## 最终结论与行动项

### 裁定结论
- 可以先做：`1`、`4`
- 能做但不建议现在先做：`2`
- 能做但需要单独设计，暂不建议先做：`3`

### 推荐顺序
1. 先补 `overview` 状态矩阵测试，建立 builder / mapper 护栏
2. 在测试护栏下实现 `Compact / Diagnostic` 两档 overview
3. 等状态矩阵和 UI 密度模型稳定后，再讨论 `2`
4. `3` 单列成“后台同步任务模型”专题，不混进当前轮次

### 一句总裁定
`1` 和 `4` 是当前代码结构下最容易落地、风险最低、收益最确定的先手；`2` 和 `3` 都不是做不到，而是它们已经进入“先补状态模型再谈 UI”的层级。

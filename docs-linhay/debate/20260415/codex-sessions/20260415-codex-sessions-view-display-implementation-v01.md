# Codex Sessions View Display Implementation

**日期**：20260415  
**模式**：合作型  
**参与者**：Gemini CLI / Codex-Godel / Codex-Aristotle  
**计划参与但未接入**：Claude Code（本机 CLI 鉴权失败，401 Invalid API key）  
**总轮次**：1 / 60  
**结束原因**：实现计划层达成足够共识，可转入执行计划文档

## 辩论背景

前一轮会议已经收敛了展示裁定：

1. 主视图优先显示 `ReadOnly` 与 `Live`
2. `Archived` 默认下沉到折叠区
3. `subagent` 默认下沉到折叠区
4. `source / originator / forked_from` 默认进入次级信息或 menu
5. `regular / medium` 隐藏 `summary`，`compact` 保留 1-2 行
6. `provider` 分组下弱化或隐藏 row 的 `Provider` 列
7. 移除 `Showing x / y`，保留 `Expand / Collapse`

本轮目标不再讨论“是否这么做”，而是回答：

1. 实现应该拆几个 phase
2. 哪些改动只动渲染层，哪些必须动 builder / viewmodel / model
3. 测试应该先改什么
4. 正式执行计划应该落在哪类文档

## 已确认的代码事实

| # | 事实 | 来源 |
|---|------|------|
| 1 | 当前默认分组是 `.project`，同时支持切换到 `.provider` | `CodexSessionsTabViewModel.swift:223`、`CodexSessionsTabViewModel.swift:475` |
| 2 | Section 视图当前是固定六列表头，并在中/窄宽度自动降级为 medium / compact | `UnifiedCodexSessionViews.swift:343-350`、`UnifiedCodexSessionViews.swift:396-449` |
| 3 | `CodexSessionsSectionDataBuilder` 已经承载 section badges、subtitle、row metadata、usage 展示等语义映射 | `CodexSessionsSectionDataBuilder.swift:16-73`、`CodexSessionsSectionDataBuilder.swift:76-138`、`CodexSessionsSectionDataBuilder.swift:140-198` |
| 4 | UI 数据模型已经稳定承载 `presentationKind`、`nameMetadataItems`、`menuMetadataItems`、`usage` 等展示字段 | `CodexSessionsModels.swift:3-7`、`CodexSessionsModels.swift:133-236` |
| 5 | 底层 Store / Scanner 已提供 `archived`、`editable`、`source`、`originator`、`forkedFromID` 等来源字段 | `CodexSessionStore.swift:6-20`、`CodexSessionStore.swift:650-680`、`CodexSessionScanner.swift:108-118` |
| 6 | 快照测试已锁定 regular / medium / narrow 三个断点，以及 provider 次级分组场景 | `CodexSessionsCardSnapshotTests.swift:22-24`、`CodexSessionsCardSnapshotTests.swift:104-109`、`CodexSessionsCardSnapshotTests.swift:133-164`、`CodexSessionsCardSnapshotTests.swift:191-255` |
| 7 | Builder 测试已锁定 `actionMenuTitle`、`expansionTitle`、`providerText`、`usage` 与 mixed-provider 项目的 row-scoped rewrite | `CodexSessionsSectionDataBuilderTests.swift:28-99`、`CodexSessionsSectionDataBuilderTests.swift:102-176` |

## 各方观点摘要

### [Gemini]

- 论点：应先做“展示层逻辑收敛”，再做排序与结构治理，避免一上来改动过大。
  - 引用：`CodexSessionsSectionDataBuilder.swift:120-134`、`UnifiedCodexSessionViews.swift:520-525`
- 结论：建议拆成 `P0（视觉降噪）`、`P1（状态排序与下沉策略）` 两阶段。

### [Codex-Godel]

- 论点：当前快照与 builder 测试已经把项目优先分组、六列布局、多 provider 仅行级改写等行为锁死，所以计划主文档应当落在 `plans`，并且先补红灯再改实现。
  - 引用：`CodexSessionsCardSnapshotTests.swift:22-24`、`CodexSessionsCardSnapshotTests.swift:191-255`、`CodexSessionsSectionDataBuilderTests.swift:102-176`
- 结论：应以 `P0（测试先行）`、`P1（实现落地）` 的顺序推进。

### [Codex-Aristotle]

- 论点：最稳的拆法是把“只动渲染层”和“需要动 builder/viewmodel/model”的边界先写死，否则 phase 会互相污染。
  - 引用：`UnifiedCodexSessionViews.swift:216-760`、`CodexSessionsModels.swift:133-236`、`CodexSessionsSectionDataBuilder.swift:399-409`
- 结论：建议拆为 `Phase 0（先改测试）`、`Phase 1（仅渲染层）`、`Phase 2（映射语义）`、`Phase 3（模型扩展，可选）`。

## 达成共识的实现计划原则

1. **先红灯，再改实现**
   - 先把新增/收紧的断言写出来，再动实现。
2. **优先做渲染层闭环**
   - 能只改 `UnifiedCodexSessionViews` 和 `SectionDataBuilder` 的，不先动模型。
3. **模型扩展是最后手段**
   - 只有当前 `CodexSessionsRowData / SectionData` 表达不了裁定，才改 `NolonUIFoundation`。
4. **主计划文档放到 `docs-linhay/plans/`**
   - `debate` 负责保留决策脉络，`plans` 负责执行 phases、测试门禁、回滚点。

## 主持人裁定

采用四阶段拆分，但对外呈现压缩为三层：

1. `Phase 0`：测试先行，锁定新契约
2. `Phase 1`：渲染层与 builder 落地
3. `Phase 2`：必要时再进入 viewmodel / model 扩展

其中：

- `Phase 3（模型扩展）` 不单列为默认阶段，而是作为 `Phase 2` 的可选分支

## 输出文档落位

1. 本辩论纪要：
   - `docs-linhay/debate/20260415/codex-sessions/20260415-codex-sessions-view-display-implementation-v01.md`
2. 主执行计划：
   - `docs-linhay/plans/2026-04-15-codex-sessions-view-display-implementation-plan-v01.md`

## 后续行动项

| # | 行动 | 负责方 |
|---|------|--------|
| 1 | 产出主执行计划文档（含 phases、文件清单、测试门禁、回滚点） | Codex |
| 2 | 计划确认后进入 `Phase 0` 测试先行 | Codex / 用户 |

# codex-sessions-search-usage

**日期**：20260416
**模式**：合作型
**参与者**：Gemini（信息架构） / Copilot（增量落地） / Claude（首轮淘汰）
**总轮次**：1 / 60
**结束原因**：第 1 轮达成有效共识

## 执行元数据
- 候选参与者：Gemini CLI / Claude Code / Copilot CLI
- 首轮实际启用：Gemini CLI / Claude Code / Copilot CLI
- 后续 active participants：Gemini CLI / Copilot CLI
- 淘汰参与者：Claude Code
- 不可用原因：
  - Claude Code：首轮执行失败，报错 `There's an issue with the selected model (claude-opus-4-6[1m]). It may not exist or you may not have access to it.`

## 辩论背景
> 用户要求针对当前 `Codex Sessions` 页面讨论如何新增“会话搜索”和“用量展示”。本轮讨论不直接实现代码，而是基于现有视图、ViewModel 和 UI 组件的真实结构，收敛一条不破坏现有性能边界的 MVP 路线。

## 确认的代码事实

| # | 事实 | 来源 |
|---|------|------|
| 1 | 页面入口只有 overview card 和 sessionsContent，没有 search UI；overview card 当前只承接 grouping picker 和 refresh | `nolon/Skills/Domain/Providers/Views/CodexSessionsTabView.swift:22-42`、`nolon/Skills/Domain/Providers/Views/CodexSessionsTabView.swift:197-212` |
| 2 | ViewModel 当前只有 `allRows`、`allSectionStates`、`sections`、`groupingMode`、`selectedSessionID`、`usageBySessionID`、`usageTasks`，没有搜索状态 | `nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift:240-258` |
| 3 | 数据变换链路是 `apply(presentation)` 写入 `allRows` 后，再进入 `rebuildSectionStates()` 和 `rebuildVisibleSections()` | `nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift:717-765` |
| 4 | 分组逻辑发生在 `makeSectionStates(from:rows, groupingMode:)`，按 project 或 provider 从 rows 分组并排序 | `nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift:780-888` |
| 5 | 折叠态 section 只显示前 5 条 live sessions；如果没有 live 才 fallback 到全量前 5 条 | `nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift:767-778` |
| 6 | usage 只对当前可见 rows 懒加载：`primeVisibleSessionUsages()` 遍历 `sections.flatMap(\.sessions)` | `nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift:945-978` |
| 7 | row data 已经有 usage 三态映射，但 loaded 只显示 total 和 `in/out` 轻量文案 | `nolon/Skills/Domain/Providers/Views/CodexSessionsSectionDataBuilder.swift:123-180`、`nolon/Skills/Domain/Providers/Views/CodexSessionsSectionDataBuilder.swift:331-357` |
| 8 | table row 有独立 usage 列，但 compact row 没有渲染 usage；`compactUsageItem(_:)` helper 已存在却未被使用 | `libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexSessionViews.swift:534-535`、`libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexSessionViews.swift:550-599`、`libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexSessionViews.swift:705-713` |
| 9 | 详情面板会把 row usage 拼成 `usageText` 展示，所以 usage 当前不是完全缺失，而是“详情有、紧凑列表无” | `nolon/Skills/Domain/Providers/Views/CodexSessionsTabView.swift:224-285` |

## 各轮观点记录

### 第 1 轮

**[Gemini - 信息架构]**
- 论点 → 引用:`nolon/Skills/Domain/Providers/Views/CodexSessionsTabView.swift:22-42` → 代码事实：当前 overview card 只承担 grouping / refresh，全局控制已存在但没有搜索入口 → 结论：搜索入口应放在 overview card 下、list 上方的全局层，不建议塞进 card 内部破坏现有布局边界。
- 论点 → 引用:`nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift:717-765` → 代码事实：`allRows -> rebuildSectionStates -> rebuildVisibleSections` 是当前唯一稳定数据管道 → 结论：搜索应该在 `allRows` 与 `makeSectionStates(...)` 之间做 filter，而不是在 section / row UI 层打补丁。
- 论点 → 引用:`nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift:767-778` → 代码事实：折叠态强制 `prefix(5)` → 结论：搜索激活时必须绕过折叠截断，否则匹配结果天然不完整。
- 论点 → 引用:`nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift:945-978` → 代码事实：usage 只按可见 row 懒加载 → 结论：不应现在做 section / overview 聚合 usage，应保持 row 级展示。

**[Copilot - 增量落地]**
- 论点 → 引用:`nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift:725-726` → 代码事实：`rebuildSectionStates()` 直接把 `allRows` 送进 `makeSectionStates(...)` → 结论：首版在这里加 `searchQuery` 过滤是最小侵入点。
- 论点 → 引用:`nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift:767-778` → 代码事实：`visibleSessions(...)` 的 `prefix(5)` 仅发生在非展开路径 → 结论：搜索时可以直接返回 `section.sessions`，同时不改写 `expandedSectionIDs`，避免污染用户原有折叠状态。
- 论点 → 引用:`nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift:946` → 代码事实：usage prime 以可见 sessions 为边界 → 结论：搜索结果集缩小时，usage 负载会自然下降，不需要额外改 usage 加载链路。
- 论点 → 引用:`libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexSessionViews.swift:550-599`、`libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexSessionViews.swift:705-713` → 代码事实：compact row 未使用 `compactUsageItem(_:)`，但 helper 已准备好 → 结论：usage 首版最适合补到 compact row，而不是重新设计新的容器层。

### 第 1 轮共识检测
- Gemini：`已共识`
- Copilot：`已共识`

## 最终结论与行动项

### 达成共识 / 裁定结论
- 搜索应该是 **全局 filter**，挂在 `CodexSessionsTabViewModel` 的 `allRows -> makeSectionStates(...)` 之间，不应直接在 section / row 视图层做搜索。
- 搜索激活时，当前折叠态的 `prefix(5)` 预览逻辑必须失效，匹配 section 应临时展示全量匹配 rows，但 **不能污染** `expandedSectionIDs` 的原始折叠状态。
- usage 展示首版应继续保持 **row 级**，不做 section 或 overview 聚合，因为当前 usage 的懒加载边界明确只覆盖可见 rows。
- 用量展示的最小增量不是新增数据源，而是把已有的 `compactUsageItem(_:)` 真正接到 compact row 上，让紧凑列表首屏可见 usage。

### 推荐 MVP
1. 在 `CodexSessionsTabViewModel` 新增 `searchQuery`
2. 在 `rebuildSectionStates()` 中基于 `searchQuery` 过滤 `allRows` 后再进入 `makeSectionStates(...)`
3. 在 `visibleSessions(...)` 中为“搜索激活”增加全量返回分支
4. 在 `CodexSessionsTabView` 的 overview card 下方增加全局搜索输入
5. 在 compact row 中接入 `compactUsageItem(_:)`

### 当前不建议做
- 在 overview card 上做全量 usage 汇总
- 在 section header 上做 usage 总计
- 首版引入 usage 排序 / usage 筛选 / usage 聚合缓存重构

### 行动项
| # | 行动 | 负责方 | 截止 |
|---|------|--------|------|
| 1 | 为 `CodexSessionsTabViewModel` 设计 `searchQuery + matchesSearch + 搜索态 visibleSessions` 方案 | Codex | 下一轮实现前 |
| 2 | 为 compact row 接入 usage 展示并验证窄宽布局是否仍稳定 | Codex | 下一轮实现前 |
| 3 | 补 `ViewModel` 级测试：搜索结果、折叠态恢复、usage 只对可见项懒加载 | Codex | 下一轮实现时 |

### 未解问题
- 搜索字段首版是否只覆盖 `title / summary / cwd`，还是要纳入 `threadID / provider / forkedFromID`
- 搜索输入更适合用 `.searchable` 还是显式 `TextField`，要不要做 debounce
- compact row 的 usage 是否要在窄宽下退化成仅 total，不显示 `in/out`

# Codex Sessions View Display

**日期**：20260415
**模式**：合作型
**参与者**：Gemini CLI（福尔摩斯）/ Codex-Hilbert（法医）/ Codex-Locke（细节审查补位）
**计划参与但未接入**：Claude Code（本机 CLI 鉴权失败，401 Invalid API key）
**总轮次**：3 / 60
**结束原因**：Gemini 与两名 Codex 代理在展示规则层达成共识

## 辩论背景

用户希望评估 `Codex Sessions` 当前视图展示是否还有优化空间，重点聚焦四个问题：

1. 哪些类型/信息必须展示
2. 哪些类型/信息应该折叠
3. 标签如何排列
4. 整体 UI 信息层级如何收敛

本轮讨论先读取实现与测试，再进行多 agent 交叉推演。核心代码入口包括：

- `nolon/Skills/Domain/Providers/Views/CodexSessionsTabView.swift`
- `nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift`
- `nolon/Skills/Domain/Providers/Views/CodexSessionsSectionDataBuilder.swift`
- `libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexSessionViews.swift`
- `libs/NolonUIFoundation/Sources/NolonUIFoundation/CodexSessionsModels.swift`
- `nolonTests/CodexSessionsCardSnapshotTests.swift`
- `nolonTests/CodexSessionsSectionDataBuilderTests.swift`

## 已确认的代码事实

| # | 事实 | 来源 |
|---|------|------|
| 1 | section 默认只展示 5 条，超出依赖 `Expand/Collapse` 展开 | `CodexSessionsTabViewModel.swift:42`、`CodexSessionsSectionDataBuilder.swift:328-349` |
| 2 | 分组模式只有 `project` / `provider` 两种 | `CodexSessionsTabViewModel.swift:44-49` |
| 3 | section badge 当前固定先显示 `Live` / `Archived`，再按条件追加 `Providers`、`Showing x / y` | `CodexSessionsSectionDataBuilder.swift:76-138` |
| 4 | row 内当前把 `source` / `originator` 放在标题下 pills，把 `forked_from` 放在 ID 次级文本，同时 menu 又重复显示同批 metadata | `CodexSessionsSectionDataBuilder.swift:165-198`、`CodexSessionsSectionDataBuilder.swift:201-268` |
| 5 | 大屏/中屏是固定六列表格：`Name / ID / Time / Provider / Usage / Menu`；窄屏降级为 compact 卡片 | `UnifiedCodexSessionViews.swift:343-350`、`UnifiedCodexSessionViews.swift:396-449`、`UnifiedCodexSessionViews.swift:451-500` |
| 6 | `Live/Archived` 与 `ReadOnly` 在 ID 列、时间列、compact 标签等多个位置重复曝光 | `UnifiedCodexSessionViews.swift:459-469`、`UnifiedCodexSessionViews.swift:529-569` |
| 7 | `singleSessionOnly` / `readOnly` 这类能力状态当前主要靠 subtitle banner 传达 | `CodexSessionsSectionDataBuilder.swift:299-325`、`UnifiedCodexSessionViews.swift:321-340` |
| 8 | 快照测试已锁定 regular / medium / narrow 三个断点，以及固定六列表格布局 | `CodexSessionsCardSnapshotTests.swift:22-24`、`CodexSessionsCardSnapshotTests.swift:104-109`、`CodexSessionsCardSnapshotTests.swift:133-164` |

## 各轮观点记录

### 第 1 轮

**[Gemini - 福尔摩斯]**

- 论点：当前“类型信息”分散在 section badge、能力 banner、ID 列、name pills、menu 中，语义过于分裂。
  - 引用：`CodexSessionsSectionDataBuilder.swift:76-138`、`CodexSessionsSectionDataBuilder.swift:201-268`、`UnifiedCodexSessionViews.swift:529-559`
- 结论：`source/originator/forked_from` 应整体下沉，row 常显应只保留主任务字段。

**[Codex-Hilbert - 法医]**

- 论点：`Showing x / y` 与 `Expand n More` 在表达同一件事。
  - 引用：`CodexSessionsSectionDataBuilder.swift:120-134`、`CodexSessionsSectionDataBuilder.swift:331-348`、`UnifiedCodexSessionViews.swift:293-303`
- 结论：保留 `Expand/Collapse` 即可，`Showing x / y` 应删除。

**[Codex-Locke - 细节审查补位]**

- 论点：`ReadOnly`、`Live/Archived` 在不同列反复出现，造成视觉噪音。
  - 引用：`UnifiedCodexSessionViews.swift:459-469`、`UnifiedCodexSessionViews.swift:542-567`
- 结论：状态语义应收敛到单一位置，避免跨列重复。

### 第 2 轮

第二轮只讨论三个剩余歧义：

1. `provider` 分组下是否保留 row 的 `Provider` 列
2. 是否移除 `Showing x / y`
3. `summary` 在大屏表格里是否默认常显

**收敛结果**

- A. `provider` 分组下，row 的 `Provider` 列应隐藏或弱化；`project` 分组下保留。
  - 引用：`CodexSessionsTabViewModel.swift:156`、`UnifiedCodexSessionViews.swift:404-405`、`UnifiedCodexSessionViews.swift:429-433`
- B. `Showing x / y` 与 `Expand n More` 语义重复，应移除 `Showing x / y`。
  - 引用：`CodexSessionsSectionDataBuilder.swift:120-134`、`CodexSessionsSectionDataBuilder.swift:341-348`
- C. 仍有分歧：Gemini 倾向“严格限行常显 summary”，两名 Codex 代理倾向“大屏折叠、compact 保留”。

### 第 3 轮

第三轮只处理 `summary` 的展示策略。

**最终共识**

- `regular / medium` 表格默认隐藏 `summary`
- `compact` 模式保留 `summary`，限制为 1-2 行

依据：

- 大屏/中屏固定六列表格已经信息很满：`UnifiedCodexSessionViews.swift:396-449`
- `summary` 当前挂在 `nameColumnView` 中，会与 title 和 pills 叠加抬高行高：`UnifiedCodexSessionViews.swift:503-527`
- 窄屏 compact 已把 ID/Time/Provider 拆到详情卡片，更适合保留 `summary` 补语义：`UnifiedCodexSessionViews.swift:451-500`

## 最终共识

### 哪些信息必须常显

1. section 标题与路径/分组上下文
2. section 的能力类型
   - 可整组改写
   - 仅支持单条改写
   - 只读
3. section 的 `Live` / `Archived`
4. row 的 `title`
5. row 的 `ID`
6. row 的 `time`
7. row 的 `usage`
8. row 的状态语义，但只保留一个主展示位置

### 哪些信息应该折叠

1. `source`
2. `originator`
3. `forked_from`
4. `rolloutPath`
5. `DB rows`
6. 大屏/中屏表格中的 `summary`

说明：

- 以上信息默认进入 menu 或次级详情区
- `compact` 模式是例外，可以保留 1-2 行 `summary`

### 标签与信息层级

建议按以下顺序组织：

1. section 层：
   - 能力提示
   - `Live`
   - `Archived`
   - `Providers`（仅 `providerCount > 1` 时显示）
2. row 层：
   - 状态标签：`Live/Archived`、`ReadOnly` 二选一收敛，不跨列重复
   - 来源标签：默认不常显；若必须显示，只保留一项最关键标签

不再保留：

- `Showing x / y`

原因：

- 同一语义已由 `Expand n More` / `Collapse` 提供：`CodexSessionsSectionDataBuilder.swift:328-349`

### UI 展示规则

1. `project` 分组：
   - row 保留 `Provider` 列
2. `provider` 分组：
   - row 隐藏或弱化 `Provider` 列
3. `regular / medium`：
   - 不显示 `summary`
4. `compact`：
   - 保留 1-2 行 `summary`
5. `ReadOnly`：
   - 只在一个位置显示
6. `source/originator/forked_from`：
   - 不在 row 与 menu 双重出现

## 开始执行前的准备结论

### P0：只调展示策略，不动模型

1. 移除 `Showing x / y`
2. `provider` 分组下隐藏或弱化 row `Provider` 列
3. `regular / medium` 隐藏 `summary`
4. `compact` 保留 `summary`，降为 1-2 行
5. 收敛 `ReadOnly` 与 `Live/Archived` 的重复展示
6. 将 `source/originator/forked_from` 默认下沉到 menu

### P1：若要进一步彻底收敛

1. 给 metadata 增加展示层级策略
   - 主显
   - 次显
   - menu only
2. 让 `CodexSessionsSectionData` / `CodexSessionsRowData` 显式表达“当前分组上下文”

## 测试与变更影响

以下测试预期会受影响，需要同步更新：

1. `nolonTests/CodexSessionsCardSnapshotTests.swift`
2. `nolonTests/CodexSessionsSectionDataBuilderTests.swift`

重点断点：

1. regular
2. medium
3. narrow / compact

## 未解问题

1. `source` 是否完全不常显，还是仅在 row 间存在差异时显示一项
2. section 的能力提示是否继续使用 banner，还是未来收敛为更轻量的标签体系
3. 若后续引入更多会话类型，是否需要把“能力类型”从 subtitle 提升为显式 chip

## 主持人裁定

本轮已经形成可直接执行的展示规则：

1. 先做 P0，不改模型，只收敛信息层级
2. 明确 row 常显只保留主任务字段
3. 把冗余 metadata 与重复状态展示移出主视图
4. 保持 `project` 与 `provider` 两种分组在信息密度上的差异化展示

补充说明：

- 本轮尝试接入 Claude Code，但本机 `claude` CLI 返回 `401 Invalid API key`，因此未纳入正式共识投票。
- 可用参与者范围内，Gemini 与两名 Codex 代理已在第 3 轮达成一致。

## 追加议题：ReadOnly / Live / Archived 排序优先级

### 追加背景

用户进一步加入会议，要求单独讨论 `ReadOnly`、`Live`、`Archived` 三类状态的展示优先级。

用户给出的候选顺序是：

- `ReadOnly > Archived > Live`

### 追加轮次结果

本轮参与者：

1. Gemini CLI
2. Codex-Carson
3. Codex-Lagrange

#### 已达成共识

1. 必须显式定义优先级
2. `ReadOnly` 必须排第一

依据：

- `readOnlyText` 只在不可编辑时生成，并且 row `actions` 在不可编辑时清空，说明它直接决定“能不能操作”，不是普通展示状态：`CodexSessionsSectionDataBuilder.swift:188-196`
- section 层的 `presentationKind` 也是先判断 `!hasEditableSessions` 再落为 `.readOnly`，说明“能力语义”高于生命周期语义：`CodexSessionsSectionDataBuilder.swift:399-408`

#### 未达成全员一致的点

- 生命周期层里，`Live` 与 `Archived` 谁排前

各方立场：

1. Gemini：`Archived > Live`
   - 理由：`Archived` 是非默认态，并且当前使用 warning 色，视觉上更需要提醒
2. Codex-Carson：`Live > Archived`
   - 理由：现有 section badge 的显式顺序就是先 `Live` 再 `Archived`
3. Codex-Lagrange：`Live > Archived`
   - 理由：当前代码里唯一明确写死的展示顺序意图是 `Live` 在前、`Archived` 在后

### 主持人裁定

用户在会后追加了明确裁定：

1. `subagent` 默认放到折叠区
2. `Archived` 默认放到折叠区
3. 主视图优先显示 `Live`

因此本议题采用更直接的展示规则，而不再沿用“`Archived` 视觉强调高于 `Live`”的折中方案。

当前生效规则：

1. **展示优先级**：`ReadOnly > Live`
2. **折叠信息**：`Archived`、`subagent`

说明：

1. `ReadOnly` 仍是可操作性约束，必须第一位
2. 生命周期在主视图只优先呈现 `Live`
3. `Archived` 不再争夺主视图优先位，默认进入折叠区或次级信息区
4. `subagent` 作为来源/来源标签的一种，也进入折叠区，不在主视图抢占首屏注意力

### 最终落地规则

1. section 层：
   - 先表达能力状态
   - 主视图优先表达 `Live`
   - `Archived` 进入折叠区或次级统计
2. row 层：
   - 若存在 `ReadOnly`，它必须是第一状态标签
   - 生命周期主标签优先显示 `Live`
   - `Archived` 默认折叠，不占据主标签位
   - `subagent` 默认折叠，不占据主标签位
3. compact 模式：
   - 当前是先 `Archived/Live` 再 `ReadOnly`
   - 若执行本裁定，应改成先 `ReadOnly`，再 `Live`
   - `Archived` 与 `subagent` 下沉到折叠区或 menu
4. table 模式：
   - 保证用户第一眼能感知 `ReadOnly` 与 `Live`
   - `Archived` 与 `subagent` 不作为首屏主标签

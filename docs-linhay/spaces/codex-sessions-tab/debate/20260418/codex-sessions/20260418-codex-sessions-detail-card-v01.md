# codex-sessions-detail-card

**日期**：20260418
**模式**：合作型
**参与者**：Codex 主持 / Explorer Volta / Explorer Feynman
**总轮次**：2 / 60
**结束原因**：基于代码证据已达成共识

## 执行元数据
- 候选参与者：Codex explorer x2
- 首轮实际启用：Volta / Feynman
- 后续 active participants：Volta / Feynman
- 淘汰参与者：无
- 不可用原因：无

## 辩论背景
用户要求重新设计会话详情卡片，并明确提出：
- 需要显示用量信息
- 需要支持复制会话 ID
- 需要展示起止时间
- 同时发起 `$debate`，要求讨论还应补哪些信息和操作

本轮限定代码范围：
- `nolon/Skills/Domain/Providers/Views/CodexSessionsTabView.swift`
- `nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift`
- `nolon/Skills/Domain/Providers/Views/CodexSessionsSectionDataBuilder.swift`
- `libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift`
- `libs/Providers/Sources/Providers/Codex/CodexSessionScanner.swift`
- `libs/Providers/Sources/Providers/Codex/CodexSessionEventParser.swift`

## 各轮观点记录

### 第 1 轮
**[Volta]**
- 论点：当前详情面板是纵向堆叠过多，不适合大规模会话浏览。  
  引用：`CodexSessionsTabView.swift:399-425`  
  代码事实：当前布局依次堆叠 `header / summary / facts / command / path rows / metadata cloud`。  
  结论：必须分成主信息区和次信息区，不能继续“平铺所有信息”。
- 论点：用量应该上升为第一优先级，不应与 DB Rows 和 Status 同权。  
  引用：`CodexSessionsTabView.swift:546-592`  
  代码事实：`detailFacts` 当前把 usage / DB Rows / Status 放在同级 chip。  
  结论：视觉上应突出 usage，把状态和 DB rows 降级。
- 论点：复制入口应该收敛成统一的次级操作，而不是散落在多个小区域。  
  引用：`CodexSessionsTabView.swift:602-640`, `CodexSessionsTabView.swift:664-782`  
  代码事实：命令、项目路径、rollout 路径的复制能力分散在不同条目里。  
  结论：需要统一操作区。

**[Feynman]**
- 论点：会话 ID 已经有可靠来源，应该显式展示并可复制。  
  引用：`CodexSessionsTabViewModel.swift:97-148`, `CodexSessionsTabView.swift:267-280`  
  代码事实：`SessionRow` 已有 `threadID` 与 `displayID`，但 `CodexSessionsDetailPanelData` 没有显式暴露 ID。  
  结论：详情卡必须新增 `Session ID / Thread ID`。
- 论点：当前代码事实下没有完整的 `startedAt / endedAt` 模型。  
  引用：`CodexSessionStore.swift:744-781`, `CodexSessionScanner.swift:55-79`  
  代码事实：主模型只保留单个 `timestamp` 并折算为 `updatedAt`。  
  结论：不能凭空把 `updatedAt` 伪装成“结束时间”。
- 论点：底层 token totals 已包含 cached input，详情卡可以比当前字符串展示更细。  
  引用：`CodexSessionEventParser.swift:19-28`, `CodexSessionsSectionDataBuilder.swift:411-429`  
  代码事实：`CodexSessionTokenTotals` 有 `inputTokens / cachedInputTokens / outputTokens`，但详情层只拿到字符串化 `usageText`。  
  结论：详情卡应直接使用结构化 usage，而不是拆字符串。

### 第 2 轮
**[主持人交叉质疑]**
- 质疑点 1：既然没有 `startedAt / endedAt`，是否完全不做时间边界？
- 质疑点 2：结构化 usage 是否会把详情卡继续撑高？

**[Volta]**
- 论点：时间边界仍可按需读取 rollout 首尾时间戳，但不应污染主列表。  
  引用：`CodexGeneratedFiles.swift:675`, `CodexGeneratedFiles.swift:1166-1169`  
  代码事实：rollout line 自身带 `timestamp`，事件里还区分 `turnStarted / turnComplete`。  
  结论：详情展开时可按需读取 `Started / Last activity`，不必在列表快照阶段预加载。
- 论点：诊断信息不应占据第一屏。  
  引用：`CodexSessionsTabView.swift:710-807`  
  代码事实：metadata 目前全部以 chip 直接展开。  
  结论：diagnostics 应降级到底部区域。

**[Feynman]**
- 论点：`Started / Last activity` 是当前代码事实下最准确的时间命名。  
  引用：`CodexSessionStore.swift:764`, `CodexSessionStore.swift:1402-1407`  
  代码事实：现有 `updatedAt` 只是最后活跃时间；ISO8601 解析能力已存在。  
  结论：可以实现时间边界，但 UI 文案必须准确，不应写成精确“起止完成时间”。
- 论点：usage 结构化后应压成紧凑指标组，而不是新的大卡片。  
  引用：`CodexSessionEventParser.swift:19-49`  
  代码事实：已有三项核心指标，足够压成 `total / in / out / cached`。  
  结论：以小型指标组呈现，而不是继续增加垂直区块。

### 第 3 轮
**[Mendel]**
- 论点：首屏还应明确展示“会话归属上下文”，至少是 `Provider + Group/Project`，但不要把完整路径堆进首屏。  
  引用：`CodexSessionsTabView.swift:611-618`, `CodexSessionsTabView.swift:919-927`, `CodexSessionsTabViewModel.swift:1437-1444`  
  代码事实：当前 `providerText`、`groupTitle` 已存在，`projectPath/groupSecondaryText` 也已存在，但完整路径放在 diagnostics 更合适。  
  结论：首屏保留 provider 与 group 的短上下文，完整路径继续放到底部 diagnostics。
- 论点：状态语义必须留在标题区，因为它直接决定下一步动作。  
  引用：`CodexSessionsTabView.swift:291-311`, `CodexSessionsTabView.swift:595-606`, `CodexSessionsSectionDataBuilder.swift:227-246`  
  代码事实：`Live / Archived / Read Only` 已能稳定生成。  
  结论：状态 pill 留在 hero，优先级高于 DB rows、rollout path。
- 论点：摘要应该保留，但只能是短摘要。  
  引用：`CodexSessionsTabView.swift:520-524`, `CodexSessionsTabViewModel.swift:1102-1116`  
  代码事实：ViewModel 已把摘要压缩到短文本范围。  
  结论：摘要保留为 1 到 2 行，不恢复成长文本块。
- 论点：首屏应保留动作，不应默认展示完整命令字符串。  
  引用：`CodexSessionsTabView.swift:769-790`, `CodexSessionsTabView.swift:843-878`  
  代码事实：当前动作入口和完整命令条同时存在，完整命令本质是执行细节。  
  结论：保留 `Resume / Copy Command / Show in Finder` 动作，完整命令字符串降级或移除默认展示。
- 论点：`DB Rows / rollout path / forked-from / source / originator` 不应进入首屏。  
  引用：`CodexSessionsTabView.swift:824-927`, `CodexSessionsSectionDataBuilder.swift:260-282`  
  代码事实：这些信息都属于诊断和谱系信息。  
  结论：统一收敛到底部 diagnostics。

**[Socrates]**
- 论点：`Started / Last activity` 的准确口径只能是 rollout 时间线的首尾事件，不应包装成“结束时间”。  
  引用：`CodexSessionStore.swift:294-325`  
  代码事实：`loadSessionTimeline` 逐行解析 rollout timestamp，`startedAt` 取首条，`lastActivityAt` 取末条；无可解析事件时只回退 `lastActivityAt`。  
  结论：详情卡只能写 `Started / Last activity`，且 `Started` 允许为空。
- 论点：timeline 是详情按需加载数据，UI 必须接受加载中与失败态。  
  引用：`CodexSessionsTabViewModel.swift:101-104`, `CodexSessionsTabViewModel.swift:1618-1650`  
  代码事实：当前只有 `.placeholder / .loaded / .failed` 三态，且只在选中会话时触发。  
  结论：默认先展示稳定字段，再异步补时间线；失败时保留快照级 `Updated` 兜底。
- 论点：`Session ID` 和 `Thread ID` 必须分开，不应复制 `displayID`。  
  引用：`CodexSessionsTabViewModel.swift:155-161`, `CodexSessionStore.swift:812-848`  
  代码事实：`displayID` 是 `threadID ?? id` 的展示别名；而 resume / rewrite 依赖的是 `threadID`。  
  结论：详情卡至少提供两个明确字段：`Session ID`、`Thread ID`，复制值不能串位。
- 论点：有一批稳定快照字段无需额外 IO，可直接展示。  
  引用：`CodexSessionsTabViewModel.swift:107-148`, `CodexSessionsTabViewModel.swift:1096-1108`, `CodexSessionStore.swift:797-858`  
  代码事实：`threadID / forkedFromID / originator / source / modelProvider / archived / cwd / updatedAt / stateRowCount / editable` 已是快照字段。  
  结论：详情卡可稳定展示 provider、状态、working directory、state rows、forked from、originator、source、updated。
- 论点：测试最低门槛还缺 timeline contract 和复制语义护栏。  
  引用：`CodexSessionsTabViewModel.swift:10-16`, `CodexSessionsTabViewModelTests.swift:1242-1348`  
  代码事实：协议已有 `loadSessionTimeline`，但 mock 和测试尚未覆盖。  
  结论：至少补 timeline lazy-load、timeline fallback、Session ID / Thread ID 复制值的测试。

## 最终结论与行动项

### 达成共识 / 裁定结论
- 会话详情卡应采用五段式结构：
  - `Hero`：标题 + 主用量 + 状态
  - `Identity`：Session ID、Thread ID、Started、Last activity
  - `Context`：provider/group 的短上下文
  - `Summary`
  - `Actions`
  - `Diagnostics`
- `Session ID / Thread ID` 必须显式展示并分别复制，不能复用 `displayID`。
- 用量必须从“普通 chip”升级为详情卡的一等信息，并直接使用结构化 totals。
- 当前主模型没有现成 `startedAt / endedAt`，但 rollout line 有 `timestamp`，因此可以在详情展开时按需读取：
  - `Started` = rollout 首个可解析时间戳
  - `Last activity` = rollout 最后一个可解析时间戳
- `Updated` 属于快照级近似时间，只能作为 diagnostics / fallback，不与 `Last activity` 混用。
- 首屏应额外保留：provider/group 短上下文、短摘要、高频动作。
- 暂不做“每个 metadata chip 都可独立复制”的重操作设计，也不再增加新的高卡片区域。

### 行动项
| # | 行动 | 负责方 | 截止 |
|---|------|--------|------|
| 1 | 为详情卡补 `Session ID / Thread ID` 和分离复制入口 | Codex | 本轮实现 |
| 2 | 新增按需读取的 session timeline，提供 `Started / Last activity` | Codex | 本轮实现 |
| 3 | 将详情卡改为五段式分区，移除默认完整命令展示，重排用量层级 | Codex | 本轮实现 |
| 4 | 在 diagnostics 中明确保留 `Updated / Working Directory / DB Rows / metadata` | Codex | 本轮实现 |
| 5 | 补快照测试、ViewModel timeline 测试、Store timeline 测试 | Codex | 本轮实现 |

### 第 4 轮（review 收口）
**[Volta]**
- 论点：`Last activity` 不能在 loading / failed 态借用 `Updated`，否则会把快照时间伪装成时间线时间。  
  结论：未加载时显示 `Loading…`，失败时显示 `Unknown`，复制入口一并禁用。
- 论点：首屏动作区不能重复渲染 `Show in Finder`。  
  结论：主按钮区保留 `Resume / Show in Finder`，下方 actions 只保留复制类动作。

**[Feynman]**
- 论点：timeline 失败后需要具备可恢复路径，否则详情卡会长期停在 `Unknown`。  
  结论：再次点击同一会话时允许对 `.failed` 状态重新发起 timeline 加载，先不新增独立 retry 按钮。
- 论点：Store 边界要把空白 `threadID` 归一化为 `nil`，避免出现“空白但可复制/可 rewrite”的脏状态。  
  结论：在 `CodexSessionStore` 统一做 `trim + nilIfEmpty`，让展示与行为共享同一语义。

### 未解问题
- 是否需要进一步区分“最后事件时间”和“最后 agent 响应时间”，当前没有足够需求支撑。
- 是否要在后续把 `forkedFromID / source / originator` 收拢进二级菜单，而不是底部 diagnostics，留待下一轮交互优化再评估。

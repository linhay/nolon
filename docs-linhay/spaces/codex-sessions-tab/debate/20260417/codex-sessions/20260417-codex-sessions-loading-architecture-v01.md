# codex-sessions-loading-architecture

**日期**：20260417  
**模式**：合作型  
**参与者**：Gemini（福尔摩斯） / Copilot（外援） / Goodall（内审） / Codex（主持）  
**总轮次**：3 / 60  
**结束原因**：第 3 轮达成共识

## 执行元数据
- 候选参与者：Gemini CLI / Claude Code / Copilot CLI
- 首轮实际启用：Gemini CLI / Claude Code / Copilot CLI
- 后续 active participants：Gemini CLI / Copilot CLI / Goodall（内部评审）
- 淘汰参与者：Claude Code
- 不可用原因：本机默认模型不可访问，首轮返回 `selected model ... may not exist or you may not have access`

## 辩论背景
> `Codex Sessions` 在 3000+ 会话下已经出现明显的浏览退化：项目列表持续跳动，滚动与浏览都被打断。用户明确接受“直接推倒重来”，但要求先讨论出最优方案，并把持久化边界一起定清楚，再进入实现。

## 确认的代码事实
- `CodexSessionStore.snapshotStream` 每个 batch 都把“当前累计的全量 sessions”重新 `yield` 出去，而不是输出增量。引用：`libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift:303-368`
- `CodexSessionsTabViewModel.load()` 会先做 project skeleton，再逐批消费 stream，并且每批都 `apply(presentation:)`。引用：`nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift:467-500`
- `apply(presentation:)` 每次都会全量替换 `allRows`，然后立即 `rebuildSectionStates()`。引用：`nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift:747-752`
- `rebuildSectionStates()` 和 `rebuildVisibleSections()` 当前都走全量路径：搜索过滤、分组、merge skeleton、重建 visible sections。引用：`nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift:761-824`
- project / provider section 排序依赖 `latestUpdatedAt`，而该值会随着后续 batch 到达继续变化，因此 section 会在加载过程中反复换位。引用：`nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift:868-910`、`nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift:993-1000`
- skeleton 预扫描已经能一次性拿到 `projectPath/liveCount/archivedCount/latestUpdatedAt`，具备作为“稳定项目顺序锚点”的基础。引用：`libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift:435-483`
- `CodexSessionsTabView` 只是复用 `CodexSessionsTabViewModelStore.shared.viewModel(for:)` 的内存单例，没有任何磁盘态恢复。引用：`nolon/Skills/Domain/Providers/Views/CodexSessionsTabView.swift:15-19`
- 当前工程已有“轻量 UI 偏好进 UserDefaults”的范式，但 `AppSettingsStore` 只管全局应用设置，没有 `Codex Sessions` 专用状态。引用：`nolon/Skills/Domain/App/Core/MainSplitView.swift:19-22`、`nolon/Skills/Domain/MenuBar/Views/CodexQuickSwitchMenuBarView.swift:173-229`、`nolon/Skills/Domain/App/Infrastructure/AppSettingsStore.swift:15-20`

## 各轮观点记录

### 第 1 轮
**[Gemini - 福尔摩斯]**  
论点：应该引入 Session Data Layer，并优先考虑 SQLite/GRDB。  
引用：`CodexSessionStore.swift:303-368`、`CodexSessionsTabViewModel.swift:747-824`  
代码事实：Provider 在流式阶段不断输出累计全量 snapshot，ViewModel 在主线程上持续全量替换和全量重建。  
结论：如果继续把 3000+ 会话都压在当前 ViewModel 内存结构上，后续搜索、过滤、增量更新都会持续退化，因此一开始倾向把数据层独立出来。

**[Copilot - 外援]**  
论点：第一阶段不该直接上数据库，根因更靠前，应该先改流协议和重建策略。  
引用：`CodexSessionStore.swift:303-368`、`CodexSessionsTabViewModel.swift:747-824`、`CodexSessionsTabViewModel.swift:993-1000`  
代码事实：根因链条是“累计全量 stream -> 全量 apply -> 全量 rebuild -> latestUpdatedAt 导致重排”。  
结论：Provider 改 delta stream、ViewModel 改增量 merge、skeleton 锁定顺序，先把 O(n^2) 传输和 section 抖动消掉，再决定是否需要更重的持久化层。

**[Goodall - 内审]**  
论点：当前设计已经直接读写 Codex 自带 sqlite 和 rollout 文件，再叠一层新数据库会把一致性复杂度提前。  
引用：`libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift:904`、`libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift:1044`、`libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift:1255`  
代码事实：Store 已经在同时处理 Codex 状态库与 rollout jsonl。  
结论：现阶段更合理的是先把协议和 ViewModel 分层做好，而不是马上引入新的磁盘真源。

### 第 2 轮
**[Gemini - 福尔摩斯]**  
论点：接受“数据库不必第一阶段引入”，先做最小共识方案。  
引用：`CodexSessionStore.swift:303-368`、`CodexSessionsTabViewModel.swift:747-824`、`CodexSessionStore.swift:435-483`  
代码事实：根因确实集中在全量 stream 和全量 rebuild；skeleton 已具备稳定顺序信息。  
结论：第一阶段的最优方案应改为 `delta stream + ViewModel 增量索引 + skeleton 锚定顺序 + 独立偏好存储`；数据库下沉到第二阶段，再视收益决定。

**[Copilot - 外援]**  
论点：坚持不新增独立 index service，直接在现有 ViewModel 内引入增量索引即可。  
引用：`CodexSessionsTabViewModel.swift:761-824`  
代码事实：现有 `SessionSectionState` 已经具备 section 表达能力，问题不在于“没有索引抽象”，而在于“每批都重建”。  
结论：用 `rowsByID + project/provider buckets + query state` 重构当前 ViewModel 即可，不需要再加一层 service。

### 第 3 轮（共识检测）
**[Gemini - 福尔摩斯]**  
结论：`已共识`。  
引用：`CodexSessionStore.swift:303-368`、`CodexSessionsTabViewModel.swift:747-824`  
代码事实：累计全量 stream 和全量重建是核心根因。  
结论：认同第一阶段不引入数据库，先做 delta + 增量索引 + 稳定 section 顺序。

**[Copilot - 外援]**  
结论：`已共识`。  
引用：`CodexSessionStore.swift:359`、`CodexSessionsTabViewModel.swift:749`、`CodexSessionsTabViewModel.swift:752`  
代码事实：每批累计 merge、全量替换、立刻重建，已经足够解释当前问题。  
结论：认同 Provider delta、ViewModel 增量索引、独立 `CodexSessionsPreferencesStore`、第一阶段不上数据库。

## 最终结论与行动项

### 达成共识 / 主持人裁定
- 第一阶段最优方案不是“继续补丁”，也不是“直接上新数据库”，而是先把数据流改正确。
- 第一阶段的目标架构：
  - Provider：把 `snapshotStream` 改成 `delta stream + completion event`，不再每批输出累计全量 snapshot。
  - ViewModel：从“全量 rows + 全量 rebuild”改成“增量索引 + query state + 局部刷新”。建议最小结构是 `rowsByID`、project/provider buckets、`lockedSectionOrder`、debounced search state。
  - UI：保留 skeleton，但 skeleton 只负责建立稳定的项目顺序；在流式完成前不允许 section 因 `latestUpdatedAt` 变化而重排。
  - 选择态：会话仍存在时，不能因为 section 折叠、增量填充或暂时不可见就回退到第一条。
- 持久化裁定：
  - 不把 `Codex Sessions` 状态并入全局 `AppSettingsStore`。
  - 新增 provider-scoped `CodexSessionsPreferencesStore`，底层使用 `UserDefaults`。
  - v1 只持久化 `groupingMode`。
  - `expandedSectionIDs` 作为 phase 1.5/2 可选项，必须带上限和失效清理。
  - `searchQuery`、`selectedSessionID` 不跨重启持久化。
  - 可丢弃磁盘缓存放到第二阶段，再根据首阶段收益和真实启动耗时决定是否做。
- 明确不做：
  - 只靠 debounce/throttle 的补丁式修复
  - 继续保留“每批累计全量 snapshot + 每批全量 rebuild”
  - 第一阶段就引入新的 SQLite/FTS 索引层
  - 把会话列表数据写进 `UserDefaults`

### 行动项
| # | 行动 | 负责方 | 截止 |
|---|------|--------|------|
| 1 | 先补 `CodexSessionStore` delta stream 失败测试与大样本契约测试 | Codex | 实施前 |
| 2 | 重构 `CodexSessionsTabViewModel` 为增量索引 + query state | Codex | phase 1 |
| 3 | 固化 skeleton 锚定顺序与 selection 稳定性测试 | Codex | phase 1 |
| 4 | 新增 `CodexSessionsPreferencesStore`，仅持久化 `groupingMode` | Codex | phase 1 |
| 5 | 视首阶段真实收益决定是否追加磁盘缓存 | Codex | phase 2 评估 |

### 未解问题
- `expandedSectionIDs` 是否值得在第二阶段持久化，需要看真实使用频率和 section 数量分布。
- 可丢弃磁盘缓存的失效策略应使用 `codexHome` mtime 还是更可靠的状态版本号，需要实现阶段补证。

# codex-sessions-independent-index-eval

**日期**：20260417  
**模式**：合作型  
**参与者**：Atlas（state projection） / Curie（usage） / Turing（search）  
**总轮次**：1 / 60  
**结束原因**：首轮达成共识

## 辩论背景
> 用户要求直接评估 `state projection / usage / search` 三类独立索引是否值得做，并补充约束：排序与搜索都是高频常用功能，因此评估不能只看首屏，还要看交互期的稳定性与后台成本。

## 确认的代码事实
- `snapshotStream` 在真正扫描 rollout 前，先同步执行 `loadStateIndex(in:)`；而 `loadStateIndex(in:)` 会遍历全部 `state*.sqlite`，并对每个库执行 `SELECT id, title, model_provider, updated_at, archived FROM threads;`。引用：
  - [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift#L316)
  - [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift#L854)
  - [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift#L906)
- `loadSessionUsage(...)` 当前会把整份 rollout 文件一次性读入内存，再逐行调用 `reduceUsageLine(...)` 聚合 totals。引用：
  - [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift#L272)
  - [CodexSessionEventParser.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionEventParser.swift#L100)
  - [CodexSessionEventParser.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionEventParser.swift#L125)
- `sortMode == .usage` 时，ViewModel 会把 `allSectionStates.flatMap(\\.sessions)` 整批送入 usage 预取队列；usage 回填后再节流触发 `rebuildSectionStates()`。这意味着“按用量排序”不是只算可见项，而是会逐步推动全量 usage 读取与重排。引用：
  - [CodexSessionsTabViewModel.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift#L1473)
  - [CodexSessionsTabViewModel.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift#L1504)
  - [CodexSessionsTabViewModel.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift#L1562)
- 搜索当前是 `250ms debounce + 内存过滤`。它只在 `rowsByID.values` 上匹配 `title / displayID / modelProvider / friendly provider label / summary / cwd`，没有独立搜索索引。引用：
  - [CodexSessionsTabViewModel.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift#L292)
  - [CodexSessionsTabViewModel.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift#L1355)
  - [CodexSessionsTabViewModel.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift#L1404)
- 已有加载架构路线已经明确：专门化独立索引不应早于 `Phase 0 共享扫描复用 / Phase 1 L0 热缓存 / Phase 1.5 最近优先历史后补`。引用：
  - [20260417-codex-sessions-cache-next-optimizations-v01.md](/Users/linhey/Desktop/FlowUp-Libs/nolon/docs-linhay/debate/20260417/codex-sessions/20260417-codex-sessions-cache-next-optimizations-v01.md)
  - [2026-04-17-codex-sessions-loading-architecture-exec.md](/Users/linhey/Desktop/FlowUp-Libs/nolon/docs-linhay/plans/2026-04-17-codex-sessions-loading-architecture-exec.md)

## 第 1 轮观点

**[Atlas - state projection]**  
论点：`state projection` 独立索引“能做，但不该先做”。  
引用：
- [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift#L316)
- [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift#L854)
- [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift#L921)
代码事实：它确实在冷路径上，而且每次都重新遍历所有 `state*.sqlite`。  
结论：如果只看“进入会话页”的关键路径，它是有收益的；但它本质上是“SQLite 镜像 SQLite”，失效与一致性风险最大。优先应该先用共享扫描、L0 热缓存、最近优先窗口，把这条链路的触发频率压下去；确认它仍然占主耗时，再做可丢弃 projection index。

论点：如果做，必须保持独立，不要和 rollout header / usage / search 混表。  
引用：
- [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift#L883)
- [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift#L906)
代码事实：`state*.sqlite` 与 `session_index.jsonl` 已经是另一条元数据来源，语义和 rollout 文件不同。  
结论：即便后续实现，也应独立成 `thread_state_projection` 一类的可丢弃索引，不要并入 rollout 主索引，避免一套库里混三种真源。

**[Curie - usage]**  
论点：如果把“按用量排序”和“组头显示用量”视为常用功能，`usage` 独立索引应当上调为第一优先级。  
引用：
- [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift#L272)
- [CodexSessionEventParser.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionEventParser.swift#L154)
- [CodexSessionsTabViewModel.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift#L1473)
- [CodexSessionsTabViewModel.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift#L1533)
代码事实：当前 usage 排序会驱动整批 rollout 文件解析，且每个 session 都是整文件读取。  
结论：这不只是“展示数字”，而是直接决定列表与分组的排序稳定性。用户已经明确接受“刷新不用这么实时”，因此 usage 非常适合做成“最终一致”的独立索引。

论点：`usage` 已经具备独立索引所需的解析边界。  
引用：
- [CodexSessionEventParser.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionEventParser.swift#L100)
- [CodexSessionEventParser.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionEventParser.swift#L125)
代码事实：usage 归约逻辑已经被单独抽到 `parseUsageEventLine / reduceUsageLine`，输入输出边界清晰。  
结论：它比 `state projection` 更容易做成文件级差量索引。建议索引键为 `sessionID / rolloutPath / fingerprint`，值为 `totals / lastTimestamp / model`；必要时再派生 project aggregate。

**[Turing - search]**  
论点：`search` 独立索引值得做，但它不是首屏链路的第一刀。  
引用：
- [CodexSessionsTabViewModel.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift#L1355)
- [CodexSessionsTabViewModel.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift#L1386)
- [CodexSessionsTabViewModel.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift#L1404)
代码事实：当前搜索只是内存匹配，并不会触发新的文件扫描；它的成本主要是 `rows` 过滤和 section 重建。  
结论：如果只看“进页面慢”，FTS 不会是最高收益项；但如果看 3000+ 会话下的日常检索体验，它很值得在主 row index 稳定后补上。

论点：搜索索引必须建立在“已有稳定 row 索引”之上。  
引用：
- [CodexSessionsTabViewModel.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift#L297)
- [CodexSessionsTabViewModel.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift#L312)
代码事实：当前搜索输入的基础单位就是 `SessionRow`。  
结论：若还没有 L1 row/header 索引，单独先做 FTS 意义有限，因为命中后仍然得回头补一层 row materialization。正确顺序是：先有主 row 索引，再加 FTS。

## 结论矩阵

| 维度 | state projection | usage | search |
|---|---|---|---|
| 直接缓解首屏冷启动 | 高 | 低 | 低 |
| 直接缓解高频交互 | 低 | 高 | 高 |
| 对“排序/搜索常用”约束的匹配度 | 低 | 高 | 高 |
| 差量更新难度 | 高 | 中 | 中低 |
| 作为独立索引的实施风险 | 高 | 中 | 中 |
| 推荐阶段 | Phase 3 | Phase 2A | Phase 2B |

## 最终结论与行动项

### 达成共识 / 主持人裁定
- 三者都“值得做”，但不是同一优先级。
- 在用户已明确“排序/搜索也是常用功能”且“刷新不必过于实时”的前提下，**独立索引优先级应调整为：`usage` > `search` > `state projection`**。
- `usage` 应作为第一类专门化独立索引推进：
  - 它直接解决“按用量排序”“组头用量展示”这两类高频交互的后台解析成本与列表重排抖动。
  - 它已经有清晰的归约器边界，最容易做文件级差量更新。
- `search` 应作为第二类专门化独立索引推进：
  - 它对日常检索体验有价值，但要依附于已有 `row/header` 主索引或热缓存。
  - 推荐使用独立 FTS，只索引 `title / displayID / cwd / provider / summary`，不要混入 usage totals。
- `state projection` 仍建议延后：
  - 它确实压在冷路径上，但用户体感更强的问题已经从“纯首屏”扩展到“高频交互”。
  - 在共享扫描、L0 热缓存、最近优先窗口落地前，直接上 projection index 属于过早优化，而且失效风险最高。

### 推荐阶段顺序
1. `Phase 0`：共享扫描输入管线，继续消掉重复 I/O
2. `Phase 1`：L0 热缓存 + 最近优先、历史后补
3. `Phase 2A`：`usage` 独立索引
4. `Phase 2B`：`search` 独立 FTS
5. `Phase 3`：再决定是否引入 `state projection` 独立索引

### 不建议现在做的事
- 不建议现在把 `state projection / usage / search` 混成一套统一大索引。
- 不建议让 `usage` 进入主 row/header 索引主链路；它应保持独立、可迟到、可后台更新。
- 不建议在还没有 row/header L1 的前提下先做纯搜索索引。

### 保留条件
- 如果后续日志证明：
  - 搜索 rebuild 在 3000+ 会话下稳定超过交互预算，或
  - 用户实际更多使用“先搜索再打开”而不是“按 usage 排序浏览”，
  则 `search` 可以与 `usage` 并列，甚至提前到同一阶段实现。

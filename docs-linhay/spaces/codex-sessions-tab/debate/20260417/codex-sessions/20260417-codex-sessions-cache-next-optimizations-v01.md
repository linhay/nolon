# codex-sessions-cache-next-optimizations

**日期**：20260417  
**模式**：合作型  
**参与者**：Borel（路径优化） / Noether（阶段拆分） / Turing（激进性能）  
**总轮次**：1 / 60  
**结束原因**：首轮即达成实质共识

## 执行元数据
- 候选参与者：Borel / Noether / Turing（内部替补评审）
- 首轮实际启用：Borel / Noether / Turing
- 后续 active participants：Borel / Noether / Turing
- 淘汰参与者：无
- 不可用原因：
  - 本轮未重复拉起 `Gemini / Claude / Copilot`，原因是同一会话内上一轮 debate 已明确验证：
    - `Gemini CLI`：非交互登录阻塞
    - `Claude Code`：默认模型不可访问
    - `Copilot CLI`：本机未登录认证

## 辩论背景
> 用户继续追问：在“独立 SQLite 差量缓存”之外，还有没有更进一步、但仍然值得做的优化。目标不是重复缓存结论，而是补充下一层更高收益的性能路线。

## 确认的代码事实
- `snapshotStream`、`loadSnapshot`、`loadProjectSkeletonSnapshot` 三条路径目前仍然各自执行扫描与解析前置工作。引用：
  - [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift#L316)
  - [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift#L418)
  - [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift#L452)
- `CodexSessionScanner` 已经支持 `DayRange`，且既能按日期分区，也能按 flat 目录扫描。引用：
  - [CodexSessionScanner.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionScanner.swift#L5)
  - [CodexSessionScanner.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionScanner.swift#L210)
- `CodexSessionsTabViewModel` 在 `initial / refresh / app activation` 都会再次走服务层重载。引用：
  - [CodexSessionsTabViewModel.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift#L526)
- 当前只缓存了 ViewModel 实例，没有 provider 维度的热索引缓存。引用：
  - [CodexSessionsTabViewModel.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift#L45)
  - [CodexSessionsTabViewModel.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift#L334)
- rewrite 完成后当前还是整页 `await load()` 回到冷路径。引用：
  - [CodexSessionsTabViewModel.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift#L726)
  - [CodexSessionsTabViewModel.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift#L768)
- `loadStateIndex()` 仍是另一条独立高成本链路，要遍历所有 `state*.sqlite` 并逐库读取 `threads`。引用：
  - [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift#L854)

## 各轮观点记录

### 第 1 轮
**[Borel - 路径优化]**  
论点：比 SQLite 缓存更先该做的是“一次扫描，多处复用”。  
引用：
- [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift#L316)
- [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift#L418)
- [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift#L452)
- [CodexSessionScanner.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionScanner.swift#L95)  
代码事实：三条读路径都重复扫描和解析同一批源文件。  
结论：Phase 0 应先收敛成一条共享输入管线，先砍掉重复 I/O，再叠缓存。

论点：值得做“最近窗口优先、历史后台补齐”。  
引用：
- [CodexSessionScanner.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionScanner.swift#L5)
- [CodexSessionScanner.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionScanner.swift#L210)
- [CodexSessionsTabViewModel.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift#L319)  
代码事实：扫描器已经支持时间范围，ViewModel 仍默认拉全量。  
结论：首屏完全可以先扫最近 3-7 天，把最近项目和最近会话先出齐，长尾历史后台回补。

论点：write 后重载整页不划算，应改为局部 patch/reconcile。  
引用：
- [CodexSessionsTabViewModel.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift#L726)
- [CodexSessionsTabViewModel.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift#L768)
- [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift#L546)
- [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift#L678)  
代码事实：rewrite 后已知受影响行和文件数量，但 UI 仍整页回冷路径。  
结论：已知变更范围时，直接 patch hot cache / SQLite cache / 内存索引，比再走一次全量读更值。

论点：值得增加进程内 `L0` 热缓存。  
引用：
- [CodexSessionsTabViewModel.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift#L45)
- [CodexSessionsTabViewModel.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift#L334)
- [CodexSessionsTabViewModel.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift#L530)  
代码事实：当前只有 ViewModel 单例，没有 provider 维度的热索引复用。  
结论：L0 热缓存专门吃掉“切页、回到会话页、前后台切换”的重复冷读，收益很直接。

**[Noether - 阶段拆分]**  
论点：Phase 顺序应先做共享扫描，再做 L0，再做 SQLite 只读索引。  
引用：
- [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift#L316)
- [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift#L418)
- [CodexSessionScanner.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionScanner.swift#L83)  
代码事实：重复 I/O 是最前面的损耗点，而 L0 热缓存又比磁盘层风险更小。  
结论：推荐顺序为 `Phase 0 共享扫描复用 -> Phase 1 L0 热缓存 -> Phase 2 SQLite 只读索引`。

论点：当前不建议直接上统一大缓存。  
引用：
- [2026-04-17-codex-sessions-loading-architecture-exec.md](/Users/linhey/Desktop/FlowUp-Libs/nolon/docs-linhay/spaces/codex-sessions-tab/plans/2026-04-17-codex-sessions-loading-architecture-exec.md#L13)
- [2026-04-17-codex-sessions-loading-architecture-exec.md](/Users/linhey/Desktop/FlowUp-Libs/nolon/docs-linhay/spaces/codex-sessions-tab/plans/2026-04-17-codex-sessions-loading-architecture-exec.md#L96)
- [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift#L854)  
代码事实：既有计划已把 SQLite cache 放到后续阶段，而 `state*.sqlite` 仍是独立高成本链路。  
结论：不要在首版把 rollout header、state projection、usage、search 全塞进一个统一缓存里，复杂度会过早爆炸。

**[Turing - 激进性能]**  
论点：两级缓存是可以落地的激进方案。  
引用：
- [CodexSessionsTabViewModel.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift#L521)
- [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift#L418)  
代码事实：进入、刷新和流式加载都反复重建 snapshot。  
结论：`L0 hot cache + L1 SQLite` 可以明显降低“退出再进来还要重新读”的体感时延。

论点：更激进但仍可控的方向是统一 `inventory` 中间层。  
引用：
- [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift#L309)
- [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift#L452)
- [CodexSessionStore.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift#L854)  
代码事实：header、project skeleton、state projection 的输入目前没有统一中间库存。  
结论：先做一次统一 inventory 扫描，再让三条读路径复用这份输入，会比单点修补更彻底。

## 最终结论与行动项

### 达成共识 / 主持人裁定
- 除了 SQLite 差量缓存外，最值得补充的优化有四类：
  - `Phase 0`：一次扫描，多处复用
  - `Phase 1`：进程内 `L0` 热缓存
  - `Phase 1.5`：最近优先、历史后补
  - `Phase 2`：写后直接 patch / 后台 reconcile
- 当前不建议直接上“统一大缓存”，也不建议首版就把 `state projection + usage + search` 混成一个缓存系统。
- 最推荐的下一步仍是：先做 **共享扫描输入管线**。这是收益最大、风险最低的一步。

### 建议的阶段顺序
1. `Phase 0`：统一 inventory / 共享扫描结果，消掉 skeleton、snapshot、stream 的重复 I/O
2. `Phase 1`：进程内 `L0` 热缓存，吃掉同会话重复进入和前后台切换
3. `Phase 1.5`：最近优先扫描，历史后台补齐
4. `Phase 2`：独立 SQLite 只读索引 + 差量更新
5. `Phase 2.5`：rewrite / migrate 后直接 patch cache，verify 改为后台 reconcile
6. `Phase 3`：再评估 `state projection / usage / search` 的独立索引

### 未解问题
- 最近窗口应该默认 `3 天 / 7 天 / 14 天`，要靠真实 perf 指标决定。
- `L0 hot cache` 的 root fingerprint 口径，是只看 rollout inventory，还是把 `session_index.jsonl / state*.sqlite` 也纳入，需要实现前补证。

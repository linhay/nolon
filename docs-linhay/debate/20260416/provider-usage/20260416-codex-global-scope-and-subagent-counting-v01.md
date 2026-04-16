# Codex 用量异常复盘：global scope 与 subagent 计入口径

## 背景

- 目标：继续排查 `codex` 本地 Usage 与上游统计差异过大的原因。
- 已知前置结论：
  - `nolon` 与参考项目 `cc-switch` 在“切天/时区”上没有足以解释“一半”差异的分歧。
  - `totalTokens` 口径双方都按 `input + output`，不是把 cached 再额外加一份。
  - cached cost 折价方向双方一致，因此主因不在 cost 公式。

本轮只聚焦两个问题：

1. 当前 `nolon` 的 Codex Usage 是否明确走 `global ~/.codex`，而不是当前账号 / 当前项目。
2. 当前扫描器是否会把不同 `id` 的 subagent / explorer 会话全部独立计入。

## 参与者观点

### 16:42 Jason

- 论点：Codex token trend 明确走全局口径，不走当前账号 `CODEX_HOME`。
  - 引用：`libs/Providers/Sources/ProviderUsage/CodexTokenTrendService.swift:26-35`
  - 代码事实：`fetchGlobalSnapshot(...)` 进入后先 `removeValue(forKey: "CODEX_HOME")`，然后才调用底层抓取器。
  - 结论：趋势数据不是账号隔离口径，而是主动退回全局口径。

- 论点：日内 drill-down 也是同一条全局链路。
  - 引用：`libs/Providers/Sources/ProviderUsage/CodexIntradayUsageService.swift:58-72`
  - 代码事实：`fetchGlobalSnapshot(...)` 同样移除了 `CODEX_HOME`，再读取 quarter-hour 数据。
  - 结论：不仅趋势图，全日内图也不是当前账号 / 当前项目视角。

- 论点：架构分发层已经把 Codex 定义成 `global`，与 Claude / Gemini 的 active snapshot 明确不同。
  - 引用：`libs/Providers/Sources/ProviderUsage/ProviderUsageRegistry.swift:38-57`
  - 代码事实：`.codex` 固定分发到 `CodexTokenTrendService().fetchGlobalSnapshot(...)`，而 `.claude` / `.gemini` 分发到 `fetchActiveSnapshot(...)`。
  - 结论：这是架构层刻意选择，不是偶发调用错误。

- 论点：UI 刷新入口没有把当前账号或项目带进 Codex token trend 查询。
  - 引用：`nolon/Skills/Domain/Providers/Usage/Engine/ProviderUsageEngine.swift:855-883`
  - 代码事实：`.codex` 分支直接调 `codexTokenTrendService.fetchGlobalSnapshot(...)`，没有账号 id、provider id、cwd 或 project filter。
  - 结论：当前 Usage 页展示的 Codex 趋势与“当前激活账号”没有绑定。

### 16:44 Averroes

- 论点：扫描器默认会把 `archived_sessions` 也纳入统计。
  - 引用：`libs/Providers/Sources/Providers/Codex/CodexSessionScanner.swift:83-103`，`libs/Providers/Sources/Providers/Codex/CostUsage/Vendored/CostUsageScanner.swift:365-369`
  - 代码事实：`includeArchived` / `includeArchivedSibling` 默认值都是 `true`，usage 扫描调用时也显式传了 `true`。
  - 结论：当前 usage 扫描不是只看 live sessions。

- 论点：现有去重只处理“同文件重复”和“同 session id 重复”，不会折叠不同 `id` 的派生会话。
  - 引用：`libs/Providers/Sources/Providers/Codex/CodexSessionScanner.swift:295-301`，`libs/Providers/Sources/Providers/Codex/CostUsage/Vendored/CostUsageScanner.swift:251-258`，`libs/Providers/Sources/Providers/Codex/CostUsage/Vendored/CostUsageScanner.swift:328-349`
  - 代码事实：扫描状态只有 `seenFileIds` 和 `seenSessionIds` 两套键；前者来自 `fileResourceIdentifier`，后者来自 `session_meta.payload.id`。
  - 结论：只要是不同物理文件、不同 `session id`，就会被当成独立会话累计。

- 论点：usage parser 根本没有把 `forked_from_id`、`originator`、`source` 纳入去重键。
  - 引用：`libs/Providers/Sources/Providers/Codex/CodexSessionEventParser.swift:112-116`，`libs/Providers/Sources/Providers/Codex/CodexSessionEventParser.swift:133-190`
  - 代码事实：parser 从 `session_meta` 里只提取 `payload.id` 当 `sessionID`；后续 token delta 只按该 `sessionID` 防重。
  - 结论：subagent / explorer 即使和父线程强相关，只要有独立 `id`，当前实现就不会折叠。

## 主持人补证

### 代码事实

- `CostUsageFetcher` 底层其实支持按 `CODEX_HOME` 作用域读取，并且注释明确写了“隔离 cache，避免 cross-account bleed”。
  - 引用：`libs/Providers/Sources/Providers/Codex/CostUsage/CostUsageFetcher.swift:48-52`
  - 结论：底层能力不是问题，问题出在上层主动去掉了 `CODEX_HOME`。

- `CostUsageFetcher` 仅在 scoped 数据为空时，才 fallback 到 `~/.codex`。
  - 引用：`libs/Providers/Sources/Providers/Codex/CostUsage/CostUsageFetcher.swift:64-89`
  - 结论：如果未来要改回账号口径，底层已有现成机制，不需要重写 scanner。

### 本机抽样事实

抽样时间：2026-04-16 16:49 左右，机器仍在持续生成新 rollout 文件，因此以下数字代表“抽样瞬间”，不是全天最终值。

- 目录 `~/.codex/sessions/2026/04/16` 抽样时共有 `50` 个 `.jsonl` 文件。
- 按首个 `session_meta.payload.cwd` 聚合：
  - `23` 个来自 `/Users/linhey/Desktop/FlowUp-Libs/nolon`
  - `17` 个来自 `/Users/linhey/Desktop/丁香园/dxyer`
  - `5` 个来自 `/Users/linhey/.nolon/skills/debate`
  - `3` 个来自 `/Users/linhey/Desktop/ohos/ohos-clinmaster`
  - 另外各 `1` 个来自 `Overloaded-org`、`linhey.wiki`
- 这证明当前全局 `~/.codex` 目录里，至少混有多个项目 / 多个工作目录的当日 session。

### 支撑性观测

- 采用与 `CodexSessionEventParser.reduceUsageLine(...)` 同样的增量规则做 shell 侧重放后，抽样瞬间的 token 主要来自“首个 `session_meta` 即标记为 subagent”的文件。
- 这不是代码证据，而是运行时观测；它的作用仅是说明：当前“不同 `id` 的 subagent 全部独立计入”这条实现，量级上足以制造 2x 左右的异常。

## 结论与行动项

### 结论

1. 当前 `nolon` 的 Codex Usage / token trend / intraday，明确不是“当前账号”或“当前项目”口径，而是 `global ~/.codex`。
2. 当前扫描器只按 `fileIdentity` 和 `session id` 去重，不会折叠不同 `id` 的 subagent / explorer / forked rollout。
3. 因此，本地统计显著高于上游，最可疑的主因已经从“时间边界”收敛为：
   - `global scope` 混入了其他项目 / 工作目录的 session
   - 不同 `id` 的派生会话被全部独立计入
4. “时间差异”这条线本轮没有新增解释力，不是当前主因。

### 行动项

1. 先改 Codex Usage 的 scope：从 `fetchGlobalSnapshot(...)` 切回当前账号 `CODEX_HOME`，只在用户明确要求时才查看 global。
2. 补测试：
   - `CODEX_HOME` 隔离口径测试
   - 多 `cwd` 混扫时不应进入当前账号 usage 的测试
   - fork / subagent / explorer 是否折叠的行为测试
3. 再做产品裁定：
   - 上游到底是“账号总量”
   - 还是“主线程折叠后总量”
   - 决定后再落最终聚合规则

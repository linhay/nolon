# codex-sessions-overview-card

**日期**：20260416
**模式**：合作型
**参与者**：Gemini CLI / Claude Code / Codex subagent（Russell）/ Codex 备用角色（Mendel）
**总轮次**：2 / 60
**结束原因**：有效代码证据已收敛；Claude Code 工具阻塞，未能产出有效论点

## 辩论背景
用户指出 `Codex Sessions` tab 上方的 `overview card` 仍然过高，要求发起一轮 `$debate`，只讨论总览卡片，不扩展到下方 session rows。

本轮限定代码范围：
- `libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexSessionViews.swift`
- `nolon/Skills/Domain/Providers/Views/CodexSessionsTabView.swift`
- `nolonTests/CodexSessionsCardSnapshotTests.swift`

## 各轮观点记录

### 第 1 轮
**[Gemini CLI]**
- 论点：overview card 的基础高度来自外层留白和纵向堆叠。  
  引用：`UnifiedCodexSessionViews.swift:21,54,65-77,110,132,156,180`  
  代码事实：外层 `VStack(spacing: 18)`、`.padding(22)`；header 窄宽时会切为 `VStack`；refresh 是 `.controlSize(.large)`；status banners 独占块；metric card `minHeight: 82`。  
  结论：应先压缩常量。
- 被主持人驳回的点：Gemini 一度把 `minHeight: 82` 错归因到 banner；该证据无效。  
  正确引用应为 `metricCard`：`UnifiedCodexSessionViews.swift:144-156`。

**[Claude Code]**
- 未形成有效观点。  
  工具事实：多次调用 `claude -p`、`claude --model sonnet -p`、`claude --bare --model sonnet -p` 均返回同一错误：`There's an issue with the selected model (gpt-5(medium))`。  
  结论：本轮记为工具阻塞，不纳入有效证据。

**[Codex subagent - Russell]**
- 论点：overview card 的基础纵向留白偏大。  
  引用：`UnifiedCodexSessionViews.swift:21,54`  
  代码事实：外层 `VStack(spacing: 18)`，整卡 `.padding(22)`。  
  结论：不改内容密度时，卡片高度下限就偏高。
- 论点：窄宽下 header 竖排会继续抬高卡片。  
  引用：`UnifiedCodexSessionViews.swift:65,73,110`  
  代码事实：`ViewThatFits` 在窄宽切到 `VStack`，refresh 是 `.large`。  
  结论：窄宽首屏会进一步吃掉 session rows 可见面积。
- 论点：overview 固定压在 sessionsContent 之上。  
  引用：`CodexSessionsTabView.swift:21-35`  
  代码事实：顶层 `LazyVStack` 先放 overview，再放 `sessionsContent`。  
  结论：该卡片过高会直接挤占首屏内容，不是单纯“视觉上大”。

### 第 2 轮
**[主持人交叉质疑]**
- 质疑点 1：`minHeight: 82` 究竟属于 banner 还是 metric？
- 质疑点 2：只改 `spacing/padding/controlSize/minHeight` 是否足够，还是必须改信息层级？

**[Codex subagent - Russell]**
- 论点：Gemini 把 `minHeight: 82` 归因到 banner 是证据错误。  
  引用：`UnifiedCodexSessionViews.swift:144-157`、`UnifiedCodexSessionViews.swift:167-181`  
  代码事实：`minHeight: 82` 位于 `metricCard`；banner 只有 `.padding(.vertical, 11)`，没有 `minHeight`。  
  结论：metric 区和 banner 区必须分开看，不能混证。
- 论点：我不再支持“只改常量就够”。  
  引用：`UnifiedCodexSessionViews.swift:21-52`、`CodexSessionsTabView.swift:195-245`  
  代码事实：overview 主体固定是 `header -> segmented picker -> statusBanners -> metrics` 的纵向堆叠；当前数据模型里 subtitle 较长，grouping 恒有值，loading 时还会追加第二条 banner。  
  结论：只压数值会更紧凑，但不能从根本上解决“这是一张说明卡，不是一块紧凑总览”的问题。
- 论点：最小结构改动应优先消除 `segmented picker` 的独占一行。  
  引用：`UnifiedCodexSessionViews.swift:24-40`、`UnifiedCodexSessionViews.swift:64-77`  
  代码事实：picker 目前是 header 之后的独立块；header 已经有 `ViewThatFits`，本身就是控制区容器。  
  结论：应把 picker 并入 header 控制区，与 refresh 同组，在宽屏先合并为同一控制行。
- 论点：若并入 header 后仍偏高，第二优先级是限制 subtitle 极端高度。  
  引用：`UnifiedCodexSessionViews.swift:97-100`、`CodexSessionsCardSnapshotTests.swift:137-159`  
  代码事实：subtitle 当前完整展开；窄宽快照正覆盖“长 subtitle + 2 banner + 4 metrics”的最坏场景。  
  结论：subtitle 最多 2 行是合理的第二刀，仍局限在 overview card 内。

**[Codex 备用角色 - Mendel]**
- 论点：overview card 的信息顺序是结构性固定，不是常量可调问题。  
  引用：`UnifiedCodexSessionViews.swift:21-52`  
  代码事实：主 `VStack` 固定为 `header -> picker -> statusBanners -> metrics grid`，没有状态驱动的折叠或重排。  
  结论：只改 `spacing/padding/minHeight` 不会改变信息层级。
- 论点：当前响应式只覆盖 header，不覆盖整张 overview card。  
  引用：`UnifiedCodexSessionViews.swift:64-77`  
  代码事实：`ViewThatFits` 只在 header 内处理 `HStack/VStack` 切换，banner 和 metrics 不参与该逻辑。  
  结论：若问题是整体主次不清，必须引入布局层级策略，而不是只压数值。
- 论点：标题区的膨胀来自文案和换行策略，不只是间距。  
  引用：`CodexSessionsTabView.swift:202-206`、`UnifiedCodexSessionViews.swift:97-100`  
  代码事实：subtitle 是长说明句，且渲染时完整展开。  
  结论：纯压 padding/spacing 只会把内容挤得更紧，不会降低信息复杂度。
- 论点：状态区支持双 banner 叠加，且位于 metrics 之前。  
  引用：`UnifiedCodexSessionViews.swift:116-132,167-181`、`CodexSessionsTabView.swift:238-245`  
  代码事实：`statusMessage` 与 `backgroundScanningMessage` 可同时出现，并以两个全宽 banner 纵向堆叠。  
  结论：要优化首屏可读性，状态信息需要合并、降级或条件展示，而不只是缩数值。

## 最终结论与行动项

### 达成共识 / 裁定结论
- 已确认的代码事实：
  - `overview card` 高度主要由四层纵向堆叠构成：`header -> segmented picker -> statusBanners -> metrics`。
  - 固定常量确实偏大：`spacing: 18`、`.padding(22)`、refresh `.large`、metric `minHeight: 82`。
  - 但真正的结构性问题是 `segmented picker` 独占一行、subtitle 完整展开、状态区允许双 banner 叠加，导致 overview 更像“说明卡”而不是“紧凑总览”。
- 主持人裁定：
  - 不建议只做纯常量压缩；有效代码证据已经收敛到“必须做轻量结构调整”。
  - 最小且正确的方案应为：  
    1. 先把 `segmented picker` 并入 header 控制区；  
    2. 同时收紧 `spacing/padding/controlSize/metric minHeight`；  
    3. 如窄宽仍高，再把 subtitle 限到 2 行；  
    4. 若状态区仍压首屏，再把双 banner 合并为单条轻量状态展示。  
  - 不建议这轮动 rows、删 metrics、把 status 信息完全隐藏。

### 行动项
| # | 行动 | 负责方 | 截止 |
|---|------|--------|------|
| 1 | 将 `segmented picker` 并入 overview header 控制区 | Codex | 本轮后续实现 |
| 2 | 收紧 overview card 常量：`spacing/padding/refresh/metric` | Codex | 本轮后续实现 |
| 3 | 若窄宽仍偏高，补 subtitle 2 行限制与快照测试 | Codex | 实现阶段 |

### 未解问题
- `statusBanners` 是否需要进一步从“banner”降级为更轻的 inline status，目前没有足够代码证据支持立即改这一步。
- Claude Code CLI 的本机模型配置为何总被劫持到 `gpt-5(medium)`，需要单独排查，不属于本次 UI 结论范围。

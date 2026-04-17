# Codex Sessions 行内详情展开设计（2026-04-17）

## 背景

当前 `Codex Sessions` 的选中态详情仍然挂在整个列表底部统一渲染：

1. 用户点击某条会话后，视觉焦点停留在原行，但详情内容跳到整个页面最下方。
2. 在 3000+ 会话的大列表里，这会造成强烈的视线断裂，用户很难确认“我点开的到底是哪一条”。
3. 现有 `CodexSessionsDetailPanelView` 仍按独立大卡片设计，头部、命令区、动作区、metadata grid 分层偏重，高度过大，不适合插入列表流中。

## 目标

1. 点击会话后，详情直接在该会话行下方展开。
2. 详情改成紧凑的“行内检查面板”，高度明显低于旧版底部大卡片。
3. 不改变现有 selection、rewrite、Finder、copy command 等能力，只重构承载位置和密度。
4. 保持当前 project-first 列表与 overview 卡片风格，不另起新的 UI 语言。

## 非目标

1. 本轮不引入右侧 split detail panel。
2. 本轮不增加新的业务字段或 provider 查询链路。
3. 本轮不把详情模型下沉到 `NolonUIFoundation`。
4. 本轮不改变当前 row menu 的业务动作集合。

## 关键代码事实

1. 列表底部统一详情入口位于：
   - [CodexSessionsTabView.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/nolon/Skills/Domain/Providers/Views/CodexSessionsTabView.swift)
2. session section / row 列表容器位于：
   - [UnifiedCodexSessionViews.swift](/Users/linhey/Desktop/FlowUp-Libs/nolon/libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexSessionViews.swift)
3. 当前 section card 只支持 `selectedRowID` 高亮，不支持在某个 row 后插入自定义展开内容。
4. 当前详情面板视图 `CodexSessionsDetailPanelView` 与 tab view 放在同一文件，便于保留应用层动作闭包，不必强行抽到 shared UI 层。

## 设计裁定

### 1. 详情插入 row 下方，而不是 section 尾部或页面底部

原因：

1. 这样最符合“点击即在原位展开”的用户预期。
2. 对超长列表更友好，用户不需要滚到列表末尾找详情。
3. 可以继续沿用现有 `selectedSessionID` 作为唯一展开态，不新增复杂状态机。

### 2. `CodexSessionsSectionCardView` 改成支持可选的 expanded row content

实现方式：

1. 将 `CodexSessionsSectionCardView` 改为带 `ExpandedRowContent: View` 的泛型容器。
2. 新增：
   - `expandedRowID: String?`
   - `expandedRowContent: (CodexSessionsRowData) -> ExpandedRowContent`
3. 为 `ExpandedRowContent == EmptyView` 提供兼容 initializer，避免旧调用和现有快照场景全部改写。

这样可以保持：

1. 通用 row 列表结构仍留在 `NolonUI`
2. 详情业务动作仍留在 app 层
3. 不需要把 detail data model 强行抽到 foundation

### 3. 详情改成紧凑 inset 面板，而不是大卡片

保留内容：

1. 标题
2. 时间 / provider / group
3. summary
4. resume command
5. 常用动作
6. 关键 metadata

压缩策略：

1. 头部缩成单行主标题 + 紧凑上下文副标题
2. `Resume` / `Finder` / `Copy` 动作改成小号按钮或 chip
3. metadata 改为低高度两列流式块
4. 外层使用 inset surface 和轻边框，不再使用大面积悬浮卡片

## BDD 验收

1. Given 用户点击某条会话
   When `selectedSessionID` 切换到该行
   Then 详情直接渲染在该会话行下方，而不是列表底部。

2. Given 某条会话已经展开详情
   When 用户点击另一条会话
   Then 原详情收起，新详情插入到新会话行下方。

3. Given 某条会话处于展开态
   When section 重新渲染但该 row 仍存在
   Then 该详情继续附着在对应 row 后方，而不是跳到 section 尾部。

4. Given 行内详情显示 resume command、project path 与 rollout path
   When 用户执行复制或 Finder 动作
   Then 行为保持与旧详情面板一致。

5. Given 中等或窄宽度窗口
   When 行内详情渲染
   Then 面板仍保持紧凑，不出现旧版大卡片那样明显挤高整个 section。

## 实现落点

1. `libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexSessionViews.swift`
   - 为 `CodexSessionsSectionCardView` 增加 row 级内联展开插槽
2. `nolon/Skills/Domain/Providers/Views/CodexSessionsTabView.swift`
   - 删除底部统一详情块
   - 在每个 section card 上按 `selectedSessionID` 注入行内详情
   - 重做 `CodexSessionsDetailPanelView`
3. `nolonTests/CodexSessionsCardSnapshotTests.swift`
   - 新增“selected row inline detail”快照
   - 更新详情面板快照到紧凑版

## 风险与控制

1. 风险：shared UI 改成泛型后影响既有调用
   - 控制：提供 `EmptyView` 兼容 initializer，保持旧构造方式不变
2. 风险：内联展开导致 section cell diff 变复杂
   - 控制：只在 `compactRowsContainer` 里按 `expandedRowID` 插入一段稳定 view，避免改动 row data model
3. 风险：详情压缩过度导致关键信息丢失
   - 控制：保留 resume command、summary、关键 metadata，裁掉的是层级与留白，不是信息本身

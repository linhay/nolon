# Codex Sessions Tab UI/UX 完整执行计划

日期：2026-04-14

关联文档：
- `docs-linhay/debate/20260414/codex-sessions/20260414-codex-sessions-tab-ui-ux-v01.md`
- `docs-linhay/features/codex-sessions-tab-2026-04-10.md`

## 背景
- `codex-sessions` tab 的会话扫描、分页、分组、rewrite 主链路已经可用，本轮不重做底层扫描与 rewrite 机制。
- 这轮 debate 已经把页面定位收敛到 `迁移优先，诊断可达`，并形成一套完整的 UI/UX 共识，不再只停留在 P0 局部修补。
- 当前要执行的是整份已收敛方案：先修正语义和动作层级，再补 overview / 分组可达性 / 首屏组感知，让页面真正成为高密度但可解释的迁移工作台。

## 目标
1. provider 呈现统一为“已知 provider 展示名主显、raw id 次显；未知 provider raw id 原样主显”。
2. 行级动作统一为“两段式”：主迁移动作 + 显式 `More` 入口，次级诊断信息稳定收口到 `More`。
3. section 语义显式建模，修正 accent color 误报，并对默认组降噪、对例外组高亮。
4. overview 指标和分页提示改成“决策优先”的信息架构，弱化实现侧噪音。
5. 分组切换在长列表中保持更高可达性。
6. 首屏 section 保底从 `1` 提升到 `2`，增强组感知，但不引入 status-aware floor。
7. 全部改动由 BDD/TDD 用例覆盖，并通过定向 `xcodebuild` 验证。

## 机械指标
- Metric：`failing_codex_sessions_uiux_regressions`
- Direction：`lower`
- Verify：
  - `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexSessionsCardSnapshotTests -only-testing:nolonTests/CodexSessionsSectionDataBuilderTests -only-testing:nolonTests/CodexSessionsTabViewModelTests`
- Guard：
  - 不修改与本轮 scope 无关的工作树文件。
  - 不把 autoresearch 工件加入 git。
  - 当前工作树已有未提交文档，按本轮实验上下文视为在场背景，不做回滚式 commit/revert loop。

## BDD 场景
1. Given 已知 provider id
   When 渲染 section title、row provider、动作文案与确认弹窗
   Then display name 主显、raw id 次显，且 source / target 都可同屏校验。

2. Given 未知 provider id
   When 渲染 provider 信息
   Then raw id 原样主显，不做猜测性格式化。

3. Given rewritable group、single-only group 与 read-only group
   When 构建 section data 并渲染 card
   Then section 使用显式 presentation kind 驱动 accent、icon、subtitle 与边框，不再用 `actions.isEmpty` 误判 warning。

4. Given 单目标 row、多目标 row 与只读 row
   When 渲染 Actions 列
   Then 单目标显示直达主动作，多目标显示 `Move Session` 菜单，只读仅显示 `More`；`More` 始终可见、可访问，并按固定顺序提供 Finder / Copy Path / rolloutPath / DB rows。

5. Given row 含 rolloutPath 与 DB rows
   When 默认渲染表格
   Then 这些诊断信息不再占据独立主列，但通过 `More` 和 context menu 一跳可见。

6. Given overview card 与长列表
   When 页面渲染和滚动
   Then metrics 按“Sessions / Groups / Rewritable / Needs Attention”表达决策信息，分页提示降级为次级说明，分组切换拥有比 overview 内单点入口更持久的可达性。

7. Given 首屏 pageSize 足以容纳多个 section
   When 首次发布可见 rows
   Then 每个 section 优先获得最多 `2` 条可见 row，再分配剩余额度。

## 实施步骤
1. 先补失败测试：
   - `CodexSessionsSectionDataBuilderTests` 覆盖 provider formatter、unknown fallback、section 三态、row actions / more menu 结构、subtitle 降噪。
   - `CodexSessionsTabViewModelTests` 覆盖 confirmation dialog 双标签、overview 决策指标、首屏 section floor=`2`。
   - `CodexSessionsCardSnapshotTests` 更新快照样例，覆盖新 table/action/layout 层级。
2. 做语义层最小实现：
   - 在 `CodexSessionsModels` 中补齐 section presentation / row primary-more action / diagnostics 承载模型。
   - 在 `CodexSessionsSectionDataBuilder` 中实现 provider display formatter、unknown fallback、section 三态、subtitle 降噪、row `More` 内容。
   - 在 `CodexSessionsTabViewModel` 中升级 confirmation dialog、overview 指标、section floor=`2`。
3. 做视图层最小实现：
   - 在 `UnifiedCodexSessionViews` 中重构 section header / accent / banner。
   - 移除默认 `Path` 主列，把诊断信息收进 `More` 与 context menu。
   - 将 Actions 列改成弹性宽度，采用 `主动作 + 图标 More`。
   - 增加更持久可达的 grouping 控件承载。
4. 运行定向验证，必要时更新快照产物。
5. 把结论回写到 debate / memory，并执行 `qmd update && qmd embed`。

## 执行结果
- 状态：已完成
- 结果摘要：
  1. `CodexSessionsModels`、`CodexSessionsSectionDataBuilder`、`CodexSessionsTabViewModel`、`CodexSessionsTabView`、`UnifiedCodexSessionViews` 已按计划落地 provider 主次展示、section 三态语义、`Move + More` 两段式动作、overview 决策指标、sticky grouping 与首屏 section floor=`2`。
  2. `Localizable.xcstrings` 已补齐本轮新增 key，包括 `action.copy_path`、`codex.sessions.action.more`、`codex.sessions.more.db_rows`、`codex.sessions.metric.groups`、`codex.sessions.metric.rewritable`、`codex.sessions.metric.needs_attention`、`codex.sessions.confirm.message.section`、`codex.sessions.confirm.message.session`。
  3. `CodexSessionsSectionDataBuilderTests`、`CodexSessionsTabViewModelTests`、`CodexSessionsCardSnapshotTests` 已更新并覆盖本轮 UI/UX 共识。
- 验证结果：
  - 2026-04-14 15:19:43（Asia/Shanghai）执行以下命令通过，`failing_codex_sessions_uiux_regressions` 从 `18` 降到 `0`：
    - `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexSessionsCardSnapshotTests -only-testing:nolonTests/CodexSessionsSectionDataBuilderTests -only-testing:nolonTests/CodexSessionsTabViewModelTests`

## 非目标
- 不重做 `CodexSessionStore`、扫描流或 rewrite 底层。
- 不引入右侧详情面板、split navigation 重构或 summary 懒加载。
- 不在本轮进入 Live/Archived 混合感知保底等 content-aware floor 策略。

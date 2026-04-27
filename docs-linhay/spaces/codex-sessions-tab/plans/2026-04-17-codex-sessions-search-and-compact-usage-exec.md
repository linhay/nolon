# Codex Sessions 搜索与 Compact Usage 执行计划

**日期**：2026-04-17  
**状态**：已完成  
**范围**：`Codex Sessions` 搜索输入、ViewModel 过滤、compact row usage 首屏可见  
**来源**：
- [20260417-codex-sessions-search-usage-v01.md](/Users/linhey/Desktop/FlowUp-Libs/nolon/docs-linhay/spaces/codex-sessions-tab/debate/20260417/codex-sessions/20260417-codex-sessions-search-usage-v01.md)
- [codex-sessions-tab-2026-04-10.md](/Users/linhey/Desktop/FlowUp-Libs/nolon/docs-linhay/spaces/codex-sessions-tab/README.md)

## 背景

本计划承接两轮 debate 的最终裁定，把 `Codex Sessions` 搜索与 compact usage 的 MVP 真正落地：

1. 搜索字段收敛为 `title / summary / displayID / cwd / provider`
2. 搜索输入复用 `SearchField`，首版不做 debounce
3. compact row 接 usage，窄宽仅显示 total

## 目标

1. 用户可以在 `Sessions` 页即时搜索主信息，不再只能靠滚动查找。
2. 搜索态结果完整可见，不被默认 `5` 条预览限制截断。
3. compact row 首屏直接可见 usage，详情面板不再是唯一入口。
4. 窄宽快照继续保持“两行 row”契约。

## 非目标

1. 不做全文索引、SQLite/磁盘级搜索优化。
2. 不做 section / overview usage 汇总。
3. 不新增 `.searchable`、debounce 或搜索高亮。
4. 不修改底层 usage 采集与 rewrite 业务流程。

## BDD 场景

1. Given 某条 session 只在第 `6` 条之后才会出现在 section 内
   When 搜索词命中该 session
   Then 搜索态仍展示它，而不是继续遵循非搜索态 `prefix(5)`。

2. Given 用户输入 provider raw id 或友好显示名
   When 触发搜索
   Then 结果都能命中对应 row。

3. Given 当前搜索词为空
   When 用户开始输入和再次清空
   Then 页面在搜索态与非搜索态之间切换，但不污染 section 原始展开状态。

4. Given compact row usage 为 `.value(total, detail)`
   When 在窄宽断点渲染
   Then 只显示 total，不显示 detail。

5. Given compact row usage 为 `.placeholder` 或 `.failed`
   When 在任意宽度渲染
   Then 仍显示该状态文本，不被 total-only 分支吞掉。

6. Given project 或 provider 分组同时存在多个 section
   When 构建 section 列表
   Then section 顺序按各组最新 session 时间倒序，而不是按标题字典序。

## 执行顺序

### Phase 0：文档先行

1. 更新 feature spec，固化搜索字段与窄宽 usage 契约
2. 写本执行计划，锁定测试与实现顺序

### Phase 1：红灯测试

1. 在 `CodexSessionsTabViewModelTests` 新增搜索相关用例：
   - `displayID` 命中
   - provider raw/friendly 命中
   - 搜索态绕过 `prefix(5)`
   - 清空搜索后恢复默认可见条数
2. 在 `CodexSessionsCardSnapshotTests` 新增 loaded usage 窄宽快照
3. 先运行定向测试，确认至少一处红灯

### Phase 2：最小实现

1. ViewModel 增加 `searchQuery`
2. 在 `rebuildSectionStates()` 中以过滤后的 rows 重建 section
3. 增加 provider 友好名匹配逻辑
4. 搜索态让 `visibleSessions(...)` 直接返回 section 全量匹配 rows
5. `CodexSessionsTabView` 接入 `SearchField`
6. `UnifiedCodexSessionViews` 接入 `compactUsageItem(_:)` 与窄宽 total-only 逻辑

### Phase 3：回归验证

1. 跑 `CodexSessionsTabViewModelTests`
2. 跑 `CodexSessionsCardSnapshotTests`
3. 如有快照变化，确认只落在本轮预期范围

## 文件清单

1. `docs-linhay/spaces/codex-sessions-tab/README.md`
2. `docs-linhay/spaces/codex-sessions-tab/plans/2026-04-17-codex-sessions-search-and-compact-usage-exec.md`
3. `nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift`
4. `nolon/Skills/Domain/Providers/Views/CodexSessionsTabView.swift`
5. `libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexSessionViews.swift`
6. `nolonTests/CodexSessionsTabViewModelTests.swift`
7. `nolonTests/CodexSessionsCardSnapshotTests.swift`

## 验证命令

1. `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexSessionsTabViewModelTests`
2. `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexSessionsCardSnapshotTests`

## 完成定义

1. 搜索与 compact usage 契约已写入 feature spec
2. 至少新增一条 ViewModel 搜索测试与一条窄宽 loaded usage 快照测试
3. 定向测试通过，或已明确说明失败原因与风险
4. memory 已同步，且执行 `qmd update && qmd embed`

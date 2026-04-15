# Codex Sessions Project-First 执行计划

日期：2026-04-14

关联文档：
- `docs-linhay/debate/20260414/codex-sessions/20260414-codex-sessions-tab-ui-ux-v01.md`
- `docs-linhay/features/codex-sessions-tab-2026-04-10.md`
- `docs-linhay/plans/2026-04-14-codex-sessions-tab-ui-ux-full.md`（已完成，作为历史基线）

## 背景
- 第一轮已完成 provider-first UI/UX 改造，并通过定向 `xcodebuild` 验证。
- 最新共识已正式裁决为：
  - `project 会话浏览优先，迁移与诊断可达`
- 因此接下来的工作不是继续在第一轮方案上加补丁，而是进入第二轮：
  - 重定默认 grouping
  - 重写列表可见性模型
  - 引入固定主列与异步 usage
  - 明确 tab cache / refresh contract

## 目标
1. 默认 grouping 改为 `project`，`provider` 保留为次级视角。
2. project 组内按时间倒序。
3. 每组默认显示 `5` 条，并支持 group 级 `展开 / 收起`。
4. 主表格列固定为 `名称 / id / 时间 / provider / 用量 / 菜单`。
5. `用量` 列异步回填，不阻塞首屏，不导致整组抖动。
6. tab 切换时优先显示旧数据，再后台增量刷新，且不丢失展开状态。

## 机械指标
- Metric：`failing_codex_sessions_project_first_regressions`
- Direction：`lower`
- Verify：
  - `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexSessionsCardSnapshotTests -only-testing:nolonTests/CodexSessionsSectionDataBuilderTests -only-testing:nolonTests/CodexSessionsTabViewModelTests`
- Guard：
  - 只修改 `codex-sessions` 第二轮 scope 内文件。
  - 不把 autoresearch 工件加入 git。
  - 第一轮历史计划文件保留，不回写为未完成。

## 执行前冻结约束
1. 产品定位已冻结为 `project 会话浏览优先，迁移与诊断可达`。
2. 默认 grouping 为 `project`，不再把 `provider` 作为默认入口。
3. `time_project` 不再承担默认分组职责；是否保留为高级视角不在本轮阻塞范围内。
4. 页面级 `Load More` 不再是主列表策略；主策略是 group 级 `5` 条 + `展开 / 收起`。
5. `usage` 必须走异步占位与行级缓存，不能走整表重建。
6. tab refresh 必须明确为“旧数据先显示、后台补新、状态不丢失”。

## BDD 场景
1. Given 用户首次打开 `Sessions`
   When 首屏渲染完成
   Then 默认 grouping 为 `project`。

2. Given 某个 project 组内有 8 条会话
   When 首屏完成
   Then 默认只显示 5 条，并展示 `展开` 控件。

3. Given 某个 project 组当前已展开
   When 用户切换到其它 tab 再切回
   Then 先显示上次已知内容，且该组仍保持展开。

4. Given usage 数据尚未返回
   When 首屏渲染表格
   Then `用量` 列显示占位状态，其它列不受阻塞。

5. Given usage 数据随后返回
   When 行级 usage 更新
   Then 只更新对应 row，不触发整组折叠/展开状态丢失。

6. Given 用户切换到 `provider` 分组
   When 页面重新组织 sections
   Then provider 仍可作为次级浏览视角存在，但默认入口不回退。

## 实施阶段

### Phase 1：测试先行（红灯）
1. 更新 `CodexSessionsTabViewModelTests`
   - 默认 grouping = `project`
   - project 组内倒序
   - 每组 `5` 条默认可见
   - 展开 / 收起状态稳定
   - tab 切换缓存语义
2. 更新 `CodexSessionsSectionDataBuilderTests`
   - 固定主列字段组装
   - project section metadata
   - usage 占位态
3. 更新 `CodexSessionsCardSnapshotTests`
   - project-first 首屏快照
   - group 展开态快照
   - usage 异步占位快照

### Phase 2：状态模型重构（绿灯前半）
1. 在 `CodexSessionsTabViewModel` 中引入 `project` grouping。
2. 把当前全局 `visibleSessionLimit` 主逻辑下沉为 group 级 visible budget。
3. 明确 group 级展开状态与 tab cache / refresh state。
4. 保持 rewrite 请求范围仍覆盖组内全部可编辑会话，不受默认 `5` 条可见限制。

### Phase 3：数据契约扩展（绿灯中段）
1. 在 `CodexSessionsModels` 中补齐：
   - row id 列
   - time 列
   - provider 列
   - usage 占位/成功/失败态
2. 在 `CodexSessionsSectionDataBuilder` 中完成新列数据注入。
3. 如果底层缺 usage 来源，在 `CodexSessionStore` 增加会话用量读取/聚合接口。

### Phase 4：视图重构（绿灯后半）
1. 在 `UnifiedCodexSessionViews` 中重写主表格为固定列。
2. 在 section header 或 footer 中承载 `展开 / 收起`。
3. 在 `CodexSessionsTabView` 中调整 overview 与 grouping 语义，使其与 project-first 一致。
4. 保留 migration / diagnostic 动作于 `菜单` 与确认弹窗中。

### Phase 5：收尾与验证
1. 跑定向 `xcodebuild` 回归，直到 `failing_codex_sessions_project_first_regressions = 0`。
2. 更新 debate / memory 记录第二轮执行结果。
3. 执行 `qmd update && qmd embed`。

## 风险与缓解
1. 风险：`usage` 数据源不完整。
   - 缓解：先定义占位态与空值语义；必要时拆成独立 Phase 3 子任务。
2. 风险：group 级 visible budget 与 rewrite 范围不一致。
   - 缓解：用 ViewModel 测试锁定“默认只显示 5 条，但 rewrite 仍覆盖全组”。
3. 风险：tab refresh 导致展开状态丢失。
   - 缓解：显式为 project section 生成稳定 ID，并写专门回归测试。

## 完成定义（DoD）
1. feature/spec 与 debate 对齐，不再出现 provider-first / project-first 双重口径。
2. 新 BDD 场景对应测试通过。
3. 主列表默认行为符合 `project-first` 新主方案。
4. 增量刷新与 usage 异步回填不破坏浏览状态。

## 执行结果（2026-04-14 20:34 CST）
- 状态：已完成。
- 实际落地：
  - `Sessions` 默认 grouping 已切为 `project`，`provider` 保留次级视角。
  - project section 已改为组内 `updatedAt` 倒序、默认显示 `5` 条、组级 `展开 / 收起`。
  - 主表格已固定为 `名称 / id / 时间 / provider / 用量 / 菜单`。
  - `usage` 已接入异步行级回填，不阻塞首屏，也不重置展开状态。
  - refresh 已保持“旧数据先显示，后台补新”的 contract。
- 代码范围：
  - `libs/NolonUIFoundation/Sources/NolonUIFoundation/CodexSessionsModels.swift`
  - `libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift`
  - `nolon/Skills/Domain/Providers/Views/CodexSessionsSectionDataBuilder.swift`
  - `libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexSessionViews.swift`
  - `nolon/Skills/Domain/Providers/Views/CodexSessionsTabView.swift`
  - `nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift`
- 测试回执：
  - `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexSessionsCardSnapshotTests -only-testing:nolonTests/CodexSessionsSectionDataBuilderTests -only-testing:nolonTests/CodexSessionsTabViewModelTests`
  - 结果：`12` 个测试全部通过，`0` 失败。
- 执行中顺手清理的编译门：
  - `nolonTests/PageMarkerRouteResolverTests.swift` 补齐 `ProviderTokenTrendSection` 新增参数。
  - `nolonTests/CodexSessionsTabViewModelTests.swift` 收紧 Swift 5 下的类型推断。
  - `nolonTests/CodexSessionsSectionDataBuilderTests.swift` 补导入 `CodexProvider`。

# Codex Sessions Tab（2026-04-10）

## 背景
- Codex 在恢复历史会话时，会按当前 `model_provider` 过滤可见线程。
- 当 Nolon 把当前账号从 OAuth / 官方 API key 切到 relay API key 后，旧历史并没有丢失，而是因为 rollout 与 `state_*.sqlite` 中仍保留旧 provider 元数据而被隐藏。
- 之前的自动迁移只能覆盖“切换当前激活账号时”的兼容场景，缺少一个可视、可确认、可手动修正的入口。

## 目标
- 为 `codex` / `codexXcode` provider 新增独立 `Sessions` tab。
- 在 tab 内按 `model_provider` 分组展示 live + archived 会话。
- 会话很多时，扫描与分组构建不能阻塞主线程，首屏只渲染第一页。
- 支持在 `按 Provider` 与 `按时间 + 项目` 两种分组视图之间切换。
- 支持对单条会话或整组会话执行 provider 重写。
- 支持对每个 session group 执行折叠 / 展开，方便在大量分组下快速浏览。
- 重写前显示影响统计，并要求用户确认。
- 底层同时改写：
  - rollout `session_meta.payload.model_provider`
  - `state_*.sqlite` 的 `threads.model_provider`

## 非目标
- 不改上游 Codex 的 resume / list_threads 过滤逻辑。
- 不允许在 Sessions 页直接创建新的 provider 配置。
- 不在非 Codex provider 上暴露该 tab。

## 约束
- 目标 provider 只能来自当前 `config.toml` 已存在的 provider id。
- 缺少 thread id 的历史记录只读展示，不允许重写。
- UI 必须同时覆盖 live 与 archived_sessions。

## BDD 验收
1. Given 当前 provider 是 `codex`
   When 解析可用 tabs
   Then 出现 `Sessions` tab，且位于 `账号与用量` 之后、`Runtime` 之前。

2. Given 当前 provider 是 `codexXcode`
   When 解析可用 tabs
   Then 出现 `Sessions` tab，且位于 `Binary` 之后、`Runtime` 之前。

3. Given `~/.codex` 中存在 live 与 archived rollout，且 `state_*.sqlite` 中存在对应线程
   When 打开 `Sessions`
   Then 按 `model_provider` 分组展示会话，并显示 live / archived 计数。

4. Given 某个会话存在合法 thread id，且当前配置中存在其他 provider id
   When 用户选择“Move Session”并指定目标 provider
   Then 先展示会话数 / live 数 / archived 数 / DB row 数的确认弹窗，再执行改写。

5. Given 某个 provider 分组下存在多条会话
   When 用户选择“Move Group”并指定目标 provider
   Then 该组所有可编辑会话的 rollout 与 SQLite provider 元数据都被改写。

6. Given 某条 rollout 缺少 thread id
   When 用户查看该记录
   Then 只显示 `Read Only`，不提供重写操作。

7. Given `~/.codex` 中存在大量 live / archived 会话
   When 打开 `Sessions`
   Then 扫描与分组构建在后台执行，界面不因全量会话同步渲染而卡死。

8. Given 某个 provider 分组下的会话数量超过单页上限
   When 首次加载完成
   Then 只显示第一页，并展示当前显示数量与 `Load More` 操作。

9. Given 某个 provider 分组当前只显示第一页
   When 用户对该分组执行 “Move Group”
   Then 仍基于该分组全部可编辑 thread id 生成 rewrite request，而不是只迁移当前页可见项。

10. Given 用户切换到 `时间 + 项目` 分组
    When 同一天同一项目下存在来自多个 provider 的 sessions
    Then 这些 sessions 合并展示在同一个 section 中，并在 row 级继续展示 provider 信息。

11. Given 用户切换到 `时间 + 项目` 分组
    When 某个 section 内包含多个 provider
    Then 该 section 只允许单条 session rewrite，不提供 section 级 `Move Group`。

12. Given `Sessions` 页存在多个 section
    When 用户折叠某个 section
    Then 该 section 只保留 header 与指标信息，隐藏内部 session rows。

13. Given 某个 section 已折叠
    When 用户执行分页加载、刷新，或切换后再切回同一种分组模式
    Then 折叠状态只影响展示，不改变已加载会话数量统计，也不影响该 section 的 rewrite 数据范围。

14. Given 某个 section 处于展开状态
    When 渲染内部 session rows
    Then 该 section 使用表头 + 行的表格式布局展示 `Session`、`Status`、`Context`、`Rollout Path` 与 `Actions` 信息，而不是时间线式卡片。

## 实现落点
- `libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift`
  - 负责扫描 sessions / archived_sessions 与 `state_*.sqlite`
  - 提供 `loadSnapshot` / `previewRewrite` / `rewriteProviders` / `migrateProviders`
- `libs/Providers/Sources/ProviderUsage/CodexSessionProviderMigrationManager.swift`
  - 激活账号时的自动迁移改为复用 `CodexSessionStore`
- `nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift`
  - 负责后台扫描后的分组构建、分页状态、确认态、状态消息、分组模式切换与刷新
- `nolon/Skills/Domain/Providers/Views/CodexSessionsTabView.swift`
  - 负责 summary card、分页状态提示、分组列表、单条/整组操作菜单
- `nolon/Skills/Domain/Providers/Views/ProviderContentTabView.swift`
  - 为 `codex` / `codexXcode` 注入 `Sessions` tab
- `nolon/Skills/Domain/Providers/Views/ProviderDetailGridView.swift`
  - 接入 `CodexSessionsTabView`

## 测试
- App：
  - `nolonTests/CodexSessionsTabConfigurationTests.swift`
  - `nolonTests/CodexSessionsTabViewModelTests.swift`
    - 覆盖分页首屏发布与分页分组整组迁移
  - `nolonTests/CodexRuntimeTabConfigurationTests.swift`
- Providers：
  - `libs/Providers/Tests/ProvidersTests/CodexTests/CodexSessionStoreTests.swift`
  - `libs/Providers/Tests/ProvidersTests/CodexTests/CodexAuthManagerTests.swift`
    - 定向回归两条历史 provider 迁移用例

## 验证
- `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexSessionsTabConfigurationTests -only-testing:nolonTests/CodexSessionsTabViewModelTests -only-testing:nolonTests/CodexRuntimeTabConfigurationTests`
- `swift test --package-path libs/Providers --filter CodexSessionStoreTests`
- `swift test --package-path libs/Providers --filter relayActivationMigratesHistoryProviderMetadataAndOAuthRestoresIt`
- `swift test --package-path libs/Providers --filter refreshActiveRelayConfigMigratesHistoricalProviderMetadata`

## 增量（2026-04-11：CLI 对齐与扫描公共层）
- 目标：
  - 让 `nolon codex session *` 与 UI `Sessions` 页使用同一套语义模型。
  - 把 session 扫描能力从 Codex 用量扫描中抽成 provider 层公共能力，避免多处重复遍历 `sessions/` / `archived_sessions/`。
- 新增 CLI：
  - `nolon codex session list`
  - `nolon codex session preview-rewrite`
  - `nolon codex session rewrite`
- 行为约束：
  - `list` 支持 `--group-by provider|time-project`，并暴露当前可用目标 provider。
  - `provider` 模式按 `model_provider` 分组；`time-project` 模式按 `日期 + 项目 cwd` 分组。
  - `preview-rewrite` / `rewrite` 只支持两类互斥选择源：
    - 重复 `--thread-id`
    - 单个 `--model-provider`
  - 文本输出与 UI 确认弹窗对齐，统一展示 `sessions / live / archived / db rows`。
- UI 对齐：
  - `CodexSessionsTabView` 不再手写 Sessions 卡片结构，改为消费 `NolonUIFoundation` data model 和 `NolonUI` shared views。
  - 现有 tab 顺序保持不变，仍为独立 `Sessions` 页，不并入 `Usage`。
- 底层抽象：
  - 新增 `CodexSessionScanner` 作为公共扫描层，统一负责：
    - `sessions/` 与 `archived_sessions/` 发现
    - 日期分区 / 平铺 jsonl 识别
    - 文件去重
    - `threadID` / `modelProvider` / `cwd` / `updatedAt` 轻量解析
  - `CodexSessionStore` 与 `CostUsageScanner` 都改为复用该扫描器。

## 增量（2026-04-12：Sessions 页 UI 重设计）
- 目标：
  - 保持现有扫描、分页、分组与 rewrite 逻辑不变，只重做展示层级和可操作性。
  - 让用户更快分辨 overview 状态、section 级整组迁移能力，以及单条 session 的上下文信息。
- UI 调整：
  - overview card 改为“标题区 + 分组切换 + 状态 banner + 指标网格”的仪表板结构。
  - section card 新增能力说明文案，明确区分：
    - 单 provider / 可编辑分组：支持整组 rewrite。
    - 多 provider 分组：仅支持单条 session rewrite。
    - 只读分组：仅展示，不允许 rewrite。
  - section header 支持折叠 / 展开：
    - 折叠后仅保留标题、能力说明、badge 与 section 级操作。
    - 展开后显示内部 session rows。
    - 折叠态不影响 overview / pagination 统计口径。
  - section 展开后的 session rows 改为表格式布局，显式展示：
    - `Session` 列：title + summary
    - `Status` 列：live / archived、provider（在 `时间 + 项目` 分组下）、DB 行数、只读状态
    - `Context` 列：相对时间、cwd
    - `Rollout Path` 列：rollout path
    - `Actions` 列：Show in Finder / Move Session
  - 移除时间线式指示器，避免在大量 session 下形成时间轴阅读负担。
- 展示模型调整：
  - `CodexSessionsSectionData` 新增 `subtitle`，承载 section 级能力说明。
  - `CodexSessionsRowData` 新增 `providerName`、`isArchived`、`isEditable`。
  - 新增 `CodexSessionsMetadataItemData`，把 row metadata 从纯字符串升级为带 icon / style 的结构化模型。
- 测试：
  - 新增 `nolonTests/CodexSessionsCardSnapshotTests.swift`，覆盖：
    - overview + provider section 视觉层级快照
    - time-project 多 provider 仅支持单条 rewrite 的快照
  - `nolonTests/CodexSessionsTabViewModelTests.swift` 持续通过，说明 UI 重构未影响会话逻辑链路。

## 增量（2026-04-12：每条会话支持在 Finder 中显示）
- 目标：
  - 每一条 live / archived session 都支持直接在 Finder 中定位 rollout 文件。
  - 不改变扫描、分页、分组与 rewrite 逻辑，只补会话级文件定位入口。
- 交互：
  - 可 rewrite 的 session：
    - row 菜单同时提供 `Show in Finder` 与 `Move Session`。
  - 只读 session：
    - row 右侧直接显示 `Show in Finder` 按钮，不再因为没有 rewrite action 而失去入口。
- 实现：
  - `CodexSessionsRowData` 新增 Finder action 文案字段。
  - 新增 `CodexSessionsSectionDataBuilder`，统一负责 section / row UI data 组装，确保所有 session 都携带 Finder 入口。
  - `CodexSessionsTabView` 使用 `provider.codexHomeFolder.file(row.rolloutPath).url` 解析目标文件，并通过 `NSWorkspace.shared.activateFileViewerSelecting([url])` 打开 Finder。
  - `UnifiedCodexSessionViews.swift` 调整 row 右侧操作区：
    - 有 rewrite action 时展示组合菜单
    - 无 rewrite action 时展示单独 Finder 按钮
- 测试：
  - 新增 `nolonTests/CodexSessionsSectionDataBuilderTests.swift`，覆盖 editable / read-only row 都带 Finder 入口。
  - `nolonTests/CodexSessionsCardSnapshotTests.swift` 更新为包含 Finder 入口的最新 row 结构。
- 验证：
  - `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexSessionsSectionDataBuilderTests -only-testing:nolonTests/CodexSessionsCardSnapshotTests`

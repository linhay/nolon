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

## 增量（2026-04-14：Project-First 浏览模型重定）

### 背景
- 经过 2026-04-14 当天多轮 debate、3 个 subagent、`Claude Code`、`Gemini CLI` 复核后，`codex-sessions` tab 的产品定位已从“迁移优先，诊断可达”改写为：
  - `project 会话浏览优先，迁移与诊断可达`
- 这意味着：
  - 原先以 `provider` 为默认入口、以全局分页和 section floor=`2` 为主的浏览模型，不再是主方案。
  - migration/rewrite 能力仍保留，但退居为项目浏览视角下的可达动作，而不是页面 IA 的第一驱动力。

### 新目标
1. `Sessions` tab 默认按 `project` 分组，而不是按 `provider` 分组。
2. project 组内按 `updatedAt` 从新到旧排序。
3. 每个 project 组默认只显示 `5` 条会话；超过后通过 group 级 `展开 / 收起` 控制，不再依赖页面级 `Load More` 作为主交互。
4. 会话行改为稳定 table 模式，主列固定为：
   - `名称`
   - `id`
   - `时间`
   - `provider`
   - `用量`
   - `菜单`
5. `用量` 列允许异步回填，但不能阻塞首屏渲染。
6. 切换到 `Sessions` tab 时优先复用旧数据，再在后台做增量刷新；刷新过程不应清空当前内容，也不应丢失展开状态。
7. migration 与诊断信息继续可达，但统一收敛到 `菜单`、确认弹窗和次级入口中。

### 非目标
- 不在这一轮把 `Sessions` 页做成实时监控面板。
- 不引入右侧详情面板或新的 split navigation。
- 不在这一轮重做底层 rewrite 能力或 SQLite 改写链路。
- 不要求首轮就保留 `时间 + 项目` 作为一级分组入口；它是否保留为高级诊断视角，可后续再定。

### 产品约束
1. 新的主方案定位为：`project 会话浏览优先，迁移与诊断可达`。
2. 默认 grouping 为 `project`；`provider` 只保留为次级切换视角。
3. group 级展开状态必须稳定记忆，且后台刷新不能打断用户当前展开/收起状态。
4. `名称 / id / 时间 / provider / 用量 / 菜单` 是固定主列，不得再退回旧的 card-table 混合主列。
5. `用量` 的异步更新必须采用行级缓存或等价机制，避免整组重排抖动。
6. tab 切换增量刷新必须满足：
   - 优先显示旧数据
   - 后台补新
   - 不清空当前表格
   - 不重置展开状态

### BDD 验收（Project-First 增量）

## 增量（2026-04-16：Overview 状态矩阵与双态密度）

### 背景
- `Codex Sessions` 的 overview card 目前仍是单一路径渲染：标题、状态 banner、指标网格全部同时出现。
- 经过 2026-04-16 当天两轮 debate，已收敛出本轮先手顺序应为：
  - `4. 先补 overview 状态矩阵测试`
  - `1. 再实现 Compact / Diagnostic 两档 overview`
- `状态中心` 与 `后台同步任务模型` 不在本轮范围内，避免在没有状态模型的前提下扩大改动面。

### 目标
1. 为 overview 建立可回归的状态矩阵测试，不再只依赖固定 snapshot 夹具。
2. 为 overview 提供 `Compact` 与 `Diagnostic` 两档密度：
   - `Compact`：默认浏览态，压缩说明与指标，优先服务项目会话浏览。
   - `Diagnostic`：在存在运行中状态或需要诊断时，展开更完整的说明与状态信息。
3. 保持现有刷新、分组切换、rewrite 流程与底层扫描链路不变。

### 非目标
1. 不在本轮引入新的后台任务实体、取消/重试模型。
2. 不把当前 `statusMessage/backgroundScanningMessage` 升级成状态中心。
3. 不修改 session list、section card 与 detail panel 的信息架构。

### 产品约束
1. 默认进入 `Compact` 模式；当存在进行中状态时，overview 允许切换到 `Diagnostic`。
2. `Compact` 模式下：
   - 说明文案必须更短
   - 非关键指标允许收敛
   - 状态区只保留当前已存在的状态输入，不扩展新语义
3. `Diagnostic` 模式下：
   - 保留完整 subtitle
   - 完整展示当前 overview metrics
   - 允许同时显示已有状态 banner
4. 状态矩阵测试至少覆盖：
   - idle / compact
   - scanning / diagnostic
   - rewrite-preparing
   - rewrite-applying
   - refresh disabled
   - 双状态并存时的优先展示契约

### BDD 验收（Overview 增量）
1. Given overview 处于默认浏览态
   When 构建 overview 展示数据
   Then 使用 `Compact` 模式，说明文案与指标集合按紧凑契约输出。

2. Given overview 正在后台扫描且页面已有旧数据
   When 构建 overview 展示数据
   Then 切换到 `Diagnostic` 模式，并保留扫描状态信息。

3. Given overview 正在准备 rewrite 或应用 rewrite
   When 构建 overview 展示数据
   Then refresh 入口保持禁用，并输出对应状态矩阵结果。

4. Given overview 状态矩阵测试运行
   When 输入不同 `loading / rewrite / status message / grouping` 组合
   Then builder / mapper 断言稳定通过，而不是只依赖 snapshot 图片。

5. Given overview 使用 `Compact` 模式
   When 在窄宽度下渲染
   Then 卡片高度继续维持紧凑，不因额外诊断说明重新膨胀。
1. Given 用户首次进入 `Sessions`
   When 页面完成首轮渲染
   Then 默认 grouping 为 `project`，且不是 `provider`。

2. Given 某个 project 组下存在多条会话
   When 页面展示该组
   Then 组内会话按 `updatedAt` 从新到旧排序。

3. Given 某个 project 组下有超过 `5` 条会话
   When 页面首次渲染完成
   Then 该组默认只显示前 `5` 条，并出现 `展开 / 收起` 控件。

4. Given 某个 project 组当前处于默认折叠配额
   When 用户点击 `展开`
   Then 该组展示完整会话列表；再次点击 `收起` 后恢复到 `5` 条。

5. Given 会话表格完成渲染
   When 用户查看任意一行
   Then 主列稳定为 `名称 / id / 时间 / provider / 用量 / 菜单`。

## 增量（2026-04-15：宽度自适应）

### 目标
- 让 `codex-sessions` 在不同窗口宽度下都保持可读，而不是只在宽窗口下成立。
- 保持 `project-first` 的信息优先级不变，但允许展示密度随宽度分档调整。

### 规则
1. 宽窗口：
   - 继续使用完整 `6` 列主表格：
     - `名称 / id / 时间 / provider / 用量 / 菜单`
2. 中等宽度：
   - 仍保持 `6` 列表格
   - 但 `id / time / provider / usage / menu` 列宽收紧，优先保住 `Name` 列可读性
3. 窄窗口：
   - section 内部 rows 切换为堆叠详情布局，而不是继续硬挤 `6` 列
   - 单条 row 至少保留：
     - title
     - `originator / source` metadata
     - `Forked From`
     - `time / provider / usage`
     - row menu
4. overview header 与 section header 的操作区需要随宽度从横排切到竖排，避免按钮把标题区压坏。

### 验收
1. Given `Sessions` 处于宽窗口
   When 渲染 project section
   Then 仍显示完整 `6` 列表格。

2. Given `Sessions` 处于中等宽度窗口
   When 渲染 project section
   Then 仍保持表格布局，且 `Name` 列不会被过度压缩到失去可读性。

3. Given `Sessions` 处于窄窗口
   When 渲染 project section
   Then row 切换为堆叠详情布局，而不是继续显示拥挤的六列表格。

4. Given `Sessions` 处于窄窗口
   When 渲染 overview / section header
   Then 标题与按钮区自动换成上下结构，不产生明显重叠或裁切。

### 验证
- `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -skipPackageUpdates -clonedSourcePackagesDirPath /Users/linhey/Library/Developer/Xcode/DerivedData/nolon-daifteoyynegwuevitolzuidfhnx/SourcePackages -only-testing:nolonTests/CodexSessionsCardSnapshotTests`
- 相关快照覆盖：
  - 宽窗口 project-first 表格
  - 中宽紧凑列表格
  - 窄宽堆叠详情布局

6. Given `用量` 数据尚未返回
   When 首屏渲染会话表格
   Then `用量` 列显示异步占位状态，但其它主列与菜单立即可用。

7. Given 用户从其它 tab 切回 `Sessions`
   When 新一轮后台刷新开始
   Then 先显示上次已知 rows，再渐进更新变化项，而不是先清空整页。

8. Given 某个 project 组已被用户展开
   When 后台刷新完成或 `用量` 异步回填
   Then 该组展开状态保持不变，且不会因刷新回退到默认 `5` 条。

9. Given 用户仍需做 provider rewrite
   When 打开某条会话的 `菜单`
   Then migration 与诊断动作仍然可达，并保持确认弹窗语义不丢失。

### 实现落点（第二轮）
- `nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift`
  - 新增 `project` grouping
  - 用 group 级 visible budget 取代当前全局 `visibleSessionLimit` 主逻辑
  - 增加 tab cache / refresh contract
  - 增加 `usageBySessionID` 或等价行级异步缓存
- `nolon/Skills/Domain/Providers/Views/CodexSessionsTabView.swift`
  - 默认切到 `project`
  - 调整 overview、grouping 控件与刷新提示语义
- `nolon/Skills/Domain/Providers/Views/CodexSessionsSectionDataBuilder.swift`
  - 适配新主列和 project 组 metadata
  - 注入 row id / time / provider / usage 占位信息
- `libs/NolonUIFoundation/Sources/NolonUIFoundation/CodexSessionsModels.swift`
  - 扩展 row / section model 以承载固定列与 usage 状态
- `libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexSessionViews.swift`
  - 重写主表格结构为 project-first 固定列
  - 增加 group 级 `展开 / 收起` 承载
- `libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift`
  - 若实现 usage 列需要底层数据支持，在这里补齐会话用量读取或聚合接口

### 测试（第二轮）
- `nolonTests/CodexSessionsTabViewModelTests.swift`
  - project grouping 默认值
  - project 组内倒序
  - 每组 `5` 条 + 展开/收起
  - tab 切换缓存与后台刷新
  - usage 异步回填不打断展开状态
- `nolonTests/CodexSessionsSectionDataBuilderTests.swift`
  - 新固定列数据组装
  - project 组 metadata
  - usage 占位 / 成功 / 失败态
- `nolonTests/CodexSessionsCardSnapshotTests.swift`
  - project-first 主表格快照
  - 展开/收起快照
  - usage 占位态快照

### 迁移说明
- 以下旧结论自本增量起降级为历史背景，不再作为执行主方案：
  1. `provider` 默认 grouping
  2. 全局 `visibleSessionLimit + section floor=2 + Load More`
  3. 以 migration workbench 为主的旧主列优先级

### 执行状态（2026-04-14 20:34 CST）
- 本增量已完成实现，并完成定向回归验证。
- 验证命令：
  - `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexSessionsCardSnapshotTests -only-testing:nolonTests/CodexSessionsSectionDataBuilderTests -only-testing:nolonTests/CodexSessionsTabViewModelTests`
- 验证结果：
  - `12` 个测试全部通过，`0` 失败
- 当前 feature 状态：
  - 从 `project-first 浏览模型重定` 进入 `已落地`
  - 后续变更应基于本状态继续迭代，不再把本节当作待讨论候选

## 增量（2026-04-17：搜索与 compact usage 首屏可见）

### 背景
- 2026-04-16 与 2026-04-17 两轮 debate 已把 `Codex Sessions` 的搜索与行级 usage 展示收敛为可执行 MVP。
- 当前页面虽然已有 project-first 分组、row 级 usage 数据与 compact row 容器，但仍存在两个明显缺口：
  - 用户无法在大量会话中直接搜索 `title / ID / project / provider`
  - compact row 首屏看不到 usage，只有详情面板可见
- 对应 debate 纪要：
  - [20260416-codex-sessions-search-usage-v01.md](/Users/linhey/Desktop/FlowUp-Libs/nolon/docs-linhay/debate/20260416/codex-sessions/20260416-codex-sessions-search-usage-v01.md)
  - [20260417-codex-sessions-search-usage-v01.md](/Users/linhey/Desktop/FlowUp-Libs/nolon/docs-linhay/debate/20260417/codex-sessions/20260417-codex-sessions-search-usage-v01.md)

### 目标
1. 在 `Sessions` 页增加显式搜索输入，支持按主信息即时过滤会话。
2. 搜索激活时返回完整匹配结果，不受 section 折叠态 `prefix(5)` 预览截断影响。
3. 在 compact row 中显示 row 级 usage，让列表首屏直接可见用量。
4. 窄宽下保护两行 row 可读性，usage 降级为只显示 total。

### 非目标
1. 不在本轮引入全文索引、远程搜索或磁盘增量搜索。
2. 不在本轮新增 section / overview usage 聚合。
3. 不在本轮引入 `.searchable` 或 debounce 节流。
4. 不在本轮扩展 `forkedFromID / originator / source` 的搜索语义。

### 产品约束
1. 搜索必须复用仓内显式 `SearchField`，不改为 `.searchable`。
2. 搜索字段首版限定为：
   - `title`
   - `summary`
   - `displayID`（`threadID` 优先，否则 `id`）
   - `cwd`
   - `provider`
3. 搜索插入点保持在 `allRows -> rebuildSectionStates()` 之间，不在 UI 层做二次过滤补丁。
4. 搜索态不能污染原始 `expandedSectionIDs`，但必须绕过默认 `5` 条预览限制。
5. compact row 的 usage 在窄宽基线下只显示 total，不显示 `in/out` 次级文案。
6. provider 搜索既要命中 raw `modelProvider`，也要命中用户看到的 provider 友好名。
7. 会话组排序必须按“组内最新会话时间”倒序，而不是按组名、provider 名或路径字典序。

### BDD 验收（搜索与 usage 增量）
1. Given `Sessions` 页已加载会话
   When 用户在搜索框输入 `thread id` 片段
   Then 页面按 `displayID` 即时过滤出匹配 rows。

2. Given `Sessions` 页已加载会话
   When 用户在搜索框输入 project 路径片段
   Then 页面按 `cwd` 过滤，并保留对应 section 的完整匹配 rows。

3. Given `Sessions` 页处于 project 分组且某个 section 默认只显示前 `5` 条
   When 用户输入能命中该 section 第 `6` 条之后 session 的搜索词
   Then 搜索态仍显示该匹配 session，而不是被折叠预览截断。

4. Given 用户搜索 `openai`、`gemini` 或 `Claude`
   When provider 原始值与友好显示名之一匹配
   Then 该 session 被视为命中结果。

5. Given 当前搜索词为空
   When 用户清空搜索框
   Then 页面恢复非搜索态 section 可见条数契约，且不改写原有展开/收起状态。

6. Given compact row 的 usage 已成功加载
   When 页面在常规宽度渲染 row
   Then compact row 显示 total 和 `in/out` 次级文案。

7. Given compact row 的 usage 已成功加载
   When 页面在窄宽基线下渲染 row
   Then compact row 只显示 total，不显示 `in/out`。

8. Given usage 仍处于 placeholder 或 failed
   When compact row 渲染
   Then 继续显示原有 placeholder / failed 文案，不因为宽度降级丢失状态。

9. Given 页面存在多个 project 或 provider 分组
   When 构建 section 列表
   Then 所有会话组按各组内最新 session 的 `updatedAt` 从新到旧排序；仅当最新时间相同才回退到标题字典序。

### 实现落点（2026-04-17 增量）
- `nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift`
  - 新增 `searchQuery`
  - 在 `rebuildSectionStates()` 前过滤 `allRows`
  - 为 provider 搜索补充友好名归一化
  - 在搜索态绕过默认 `5` 条预览限制
- `nolon/Skills/Domain/Providers/Views/CodexSessionsTabView.swift`
  - 在 overview card 下方接入 `SearchField`
  - 把搜索框与 ViewModel 绑定
- `libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexSessionViews.swift`
  - 把 `compactUsageItem(_:)` 真正接入 compact row
  - 为窄宽路径增加 usage 次级文案降级逻辑
- `nolonTests/CodexSessionsTabViewModelTests.swift`
  - 搜索字段、搜索态全量结果、展开状态恢复
- `nolonTests/CodexSessionsCardSnapshotTests.swift`
  - loaded usage 窄宽快照

### 验证
- `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexSessionsTabViewModelTests`
- `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexSessionsCardSnapshotTests`

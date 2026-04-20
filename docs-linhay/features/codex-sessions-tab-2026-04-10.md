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

15. Given 用户点击某条会话
    When 会话进入选中态
    Then 详情直接在该条会话内部展开，而不是作为列表中的独立第二块卡片插入。

16. Given 某条会话详情已经展开
    When 用户点击详情右上角关闭按钮
    Then 当前会话取消选中并收起详情，不影响当前 section 的展开状态。

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

## 增量（2026-04-20：单会话 subtitle 轨道纯文本收口）
- 目标：
  - 让单会话 row 的次信息收口为一条稳定的纯文本 subtitle rail，不再混用标题内联状态与图标化 metadata。
  - 避免 row 级 usage 异步回填期间长期显示 `Loading…`，影响浏览稳定性。
- UI 调整：
  - `title` 只承载会话标题本身，不再追加 `Live / Archived / Read Only`。
  - `subtitle` 统一承载：
    - `状态`
    - `Read Only`
    - `Provider`
    - `Usage`
    - `Time`
  - subtitle 不再使用图标，统一使用 ` · ` 分隔。
- usage 行为：
  - row 级 usage 为 `placeholder` 时不显示任何 usage 文案。
  - row 级 usage 为 `failed` 时显示 `Unavailable`。
  - section/header 级 usage loading 语义保持不变，仍可显示加载态。
- 验证：
  - `nolonTests/CodexSessionsCardSnapshotTests.swift` 更新为覆盖：
    - 单会话 row 的状态与 usage 都位于 subtitle rail
    - 长标题下 subtitle 仍保持 text-only rail
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

## 增量（2026-04-20：Sessions 页静态文字禁用选择）

### 目标
- 避免用户在浏览大量会话、拖拽滚动或连续点击条目时，误触进入文字选择态。
- 只收口 `Codex Sessions` 页面内的静态文本，不影响全局其它页面的复制能力。

### 约束
- 搜索框、输入框等可编辑控件必须继续可输入，不因页面级禁用而失效。
- 只禁用静态展示文本的选择能力，不改变 `Copy Command`、`Share` 等显式复制动作。
- 组件内部不得再局部开启 `.textSelection(.enabled)` 来覆盖页面约束。

### BDD 验收
1. Given 用户进入 `Codex Sessions` 页面
   When 拖拽或点击会话标题、Thread ID、Project Path、详情 metadata
   Then 页面不进入文字选择态，也不会出现蓝色选区。

2. Given 用户在 `Codex Sessions` 页面使用搜索框
   When 输入或编辑关键字
   Then 搜索框仍可正常获得焦点并编辑文本。

3. Given `Codex Sessions` 页面内部存在共享组件
   When 这些组件被挂到会话列表或详情中
   Then 其静态文本也遵守页面禁用选择的统一规则，不再局部重新启用。

### 实现落点
- `nolon/Skills/Domain/Providers/Views/CodexSessionsTabView.swift`
  - 页面根视图增加 `.textSelection(.disabled)`。
- `libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexSessionViews.swift`
  - 移除局部静态 metadata 的 `.textSelection(.enabled)`，避免覆盖页面级禁用。
- `nolon/Skills/Domain/Providers/Views/CodexSessionsDetailPanelView.swift`
  - 移除详情 metadata row 的局部 `.textSelection(.enabled)`。

### 测试
- `nolonTests/CodexSessionsCardSnapshotTests.swift`
  - 新增 AppKit 级断言：`sessions page disables text selection for static labels`
  - 递归检查宿主 `NSTextField`，确保静态文本节点不存在 `isSelectable == true`。

### 验证
- `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexSessionsCardSnapshotTests`

## 增量（2026-04-20：组头菜单精简）

### 背景
- 组头已经收口为 subtitle rail，但一级菜单仍然把所有 `Move Group to ...` provider 目标直接平铺出来。
- 当 provider 数量变多时，组头菜单长度快速膨胀，用户在会话页浏览大量分组时会明显觉得菜单噪音过高。
- 用户要求继续精简组头菜单，优先保留高频动作，降低一级菜单负担。

### 目标
1. 一级菜单只保留少量高频动作，不能再直接平铺所有 provider 迁移目标。
2. provider 迁移动作改为二级子菜单承载。
3. 组头低频动作从一级菜单移除，避免菜单长度继续增长。

### 产品约束
1. 不丢失整组迁移能力，只调整信息架构，不删除核心动作。
2. 不丢失整组分享与复制线程 ID 能力。
3. 组头菜单精简后，单个 provider 目标名称仍需可辨识，不能退化成只显示内部 id。

### BDD 验收（组头菜单精简）
1. Given 某个组存在多个可迁移目标 provider
   When 用户点击组头菜单
   Then 一级菜单只显示一个整组迁移入口
   And 各 provider 目标收纳在该入口的二级子菜单中。

2. Given 某个组支持分享和复制线程 ID
   When 用户点击组头菜单
   Then 一级菜单仍保留 `Share Group` 与 `Copy All Thread IDs`。

3. Given 某个组存在低频目录动作
   When 渲染组头菜单
   Then 该低频动作不再占据一级菜单位置。

### 实现落点
- `libs/NolonUIFoundation/Sources/NolonUIFoundation/CodexSessionsModels.swift`
  - 为 provider action 增加紧凑菜单文案 `menuLabelText`
- `libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexSessionViews.swift`
  - 组头菜单改为“Move ...”二级子菜单 + 一级高频动作
  - 组头一级菜单移除 `Open Folder`
- `nolonTests/CodexSessionsSectionDataBuilderTests.swift`
  - 增加 compact menu label 断言，覆盖 provider 迁移项文案收口

### 验证
- 已确认 `NolonUIFoundation` 与 `UnifiedCodexSessionViews.swift` 在 `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexSessionsSectionDataBuilderTests` 的编译过程中成功通过对应文件编译阶段。
- 完整测试命令在当前环境下被 `nolon-tests` 的全量依赖冷编译显著拖慢；本轮未拿到最终 `TEST SUCCEEDED` 结果，需要继续顺序回归。
- 结果：`19/19` 通过。

## 增量（2026-04-20：Overview 标题栏右侧控件栅格对齐）

### 目标
- 让 `Project / Provider`、排序、刷新 作为 overview 标题栏右侧的固定 controls cluster 呈现。
- 避免因为宽度略紧就整体掉到标题下方，破坏“标题左、操作右”的浏览预期。

### 实现
- `libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexSessionViews.swift`
  - `CodexSessionsOverviewCardView.header` 从 `ViewThatFits + HStack/VStack` 改为两列 `Grid`。
  - 左列承载标题与副标题，右列承载 grouping picker、sorting menu、refresh button。
  - 标题副文案下沉为第二行，控件 cluster 固定锚定在右上角，不再因最小宽度门槛过早换行。

### 验证
- `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexSessionsCardSnapshotTests`
- 结果：`19/19` 通过。

## 增量（2026-04-20：单会话 Row 状态并入标题行）

### 目标
- 降低单会话 row 的首行高度，避免 `Live / Archived / Read Only` 独立 pill 把 subtitle 撑高。
- 让状态文案和左侧标题处于同一视觉中心，不再出现 badge 与标题垂直不齐的观感。
- 明确 subtitle 元数据顺序，减少同一条 row 内的信息抖动。

### 实现
- `libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexSessionViews.swift`
  - `compactRowContent` 新增标题行内联状态文本，把 `Live / Archived / Read Only` 直接并入标题行。
  - 移除 compact row 中独立 `pill` 状态区。
  - compact subtitle 轨道改为固定顺序：`Provider -> Usage -> Time`。
  - 状态文案进一步做轻量语义强化：
    - `Live` 使用亮色圆点内联文本
    - `Archived` 使用弱化历史图标
    - `Read Only` 使用锁图标
    - 仍保持纯文本流，不回退为独立 badge。

### 验证
- `nolonTests/CodexSessionsCardSnapshotTests.swift`
  - 新增 `single session row merges status into title and keeps subtitle compact`
- `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexSessionsCardSnapshotTests`
- 结果：`20/20` 通过。

## 增量（2026-04-20：Row 点击即展开，移除独立展开按钮）

### 目标
- 移除单会话 row 右侧单独的展开按钮，避免菜单按钮和展开按钮并排造成控制区视觉别扭。
- 把展开/收起动作直接并到整条 row 的点击行为中，降低交互负担。

### 实现
- `libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexSessionViews.swift`
  - compact row 的 `onTapGesture` 从 `onSelectRow` 改为 `onToggleRowExpansion`。
  - 删除右侧 `chevron` 展开按钮，row 右侧只保留菜单按钮。
  - 选中态背景继续复用 `selectedRowID`，因此展开态视觉反馈不变。

### 验证
- `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexSessionsCardSnapshotTests`
- 结果：`20/20` 通过。
2. 为 overview 提供 `Compact` 与 `Diagnostic` 两档密度：
   - `Compact`：默认浏览态，压缩说明与指标，优先服务项目会话浏览。
   - `Diagnostic`：在存在运行中状态或需要诊断时，展开更完整的说明与状态信息。
3. 保持现有刷新、分组切换、rewrite 流程与底层扫描链路不变。

### 非目标
1. 不在本轮引入新的后台任务实体、取消/重试模型。
2. 不把当前 `statusMessage/backgroundScanningMessage` 升级成状态中心。

## 增量（2026-04-20：会话条目与详情合一）

### 目标
1. 会话点击后直接在当前条目内联展开详情，彻底去掉“条目 + 下方独立详情卡”双块结构。
2. 展开后的详情视觉上继续属于当前选中条目，背景与选中态保持一致。
3. 详情需要提供明确关闭入口，避免用户只能依赖重新刷新或切换 selection 才能收起。

### 交互约束
1. row header 仍然承担 selection 入口，点击后只展开当前条目。
2. 展开详情插入到同一个 row 容器内部，位于 row header 下方，并保留同一层背景与描边。
3. 关闭行为收敛到 row 右上角已有的展开按钮，展开与收起共用同一个 toggle 入口，不再在详情内部额外放置关闭按钮。
4. 收起时只清空 `selectedSessionID`，不额外折叠 section，也不重置其它浏览状态。

### 验证
- `selectedRowExpandsInlineDetailBelowTappedSession.inline-detail-selected-row.png` 必须稳定呈现“同一条目内部展开”的结构。
- `CodexSessionsCardSnapshotTests` 需要覆盖带关闭按钮的 inline detail 场景。

## 增量（2026-04-17：会话与会话组支持按用量排序）

### 背景
- 当前 `Codex Sessions` 的排序口径只有 `updatedAt`，无论是 project/provider 分组，还是 section 内部 session rows，全部按最近更新时间降序。
- 页面已经支持异步解析单条 session usage，也支持在组头展示聚合用量，但这些用量信息仍然只是展示，不参与排序。
- 当用户需要快速定位“最耗 token 的项目”或“最耗 token 的单条会话”时，当前页无法直接完成这一筛选。

### 目标
1. `Codex Sessions` overview card 新增排序模式切换，至少支持：
   - `按最近活动`
   - `按用量`
2. 当排序模式为 `按用量` 时：
   - section 内 session rows 按单条 session 总 token 用量降序排列。
   - groups / sections 按组内聚合总 token 用量降序排列。
3. 排序偏好需要按 provider 持久化，重新进入页面后恢复上次选择。
4. `按用量` 排序不能阻塞首屏；usage 继续后台解析，排序允许渐进收敛，但在用量缺失时必须有稳定回退顺序。

### 回退规则
1. 默认排序模式仍为 `按最近活动`。
2. `按用量` 下，已解析 usage 的 session / section 优先按总 token 用量降序比较。
3. 当用量相同，或某一项还未解析 / 解析失败时，回退到既有的 `updatedAt` 降序。
4. 当 `updatedAt` 仍相同，再按稳定字符串键（title / display id）比较，避免同值项抖动。

### BDD 验收（用量排序增量）
1. Given overview 当前处于 `按最近活动`
   When 用户切换到 `按用量`
   Then overview 显示已选中的排序模式，且该选择会写入本地偏好。

2. Given 同一 section 中多条 session 的 usage 已解析
   When 排序模式为 `按用量`
   Then 这些 session rows 按总 token 用量从高到低显示，而不是继续按时间降序。

3. Given 多个 groups / sections 的聚合 usage 已解析
   When 排序模式为 `按用量`
   Then groups / sections 按聚合总 token 用量从高到低显示，而不是继续按最近会话时间排序。

4. Given 页面重新创建 view model
   When 当前 provider 存在已持久化的排序偏好
   Then `Codex Sessions` 恢复该排序模式，而不是重置为默认值。

5. Given 排序模式为 `按用量`，且部分会话尚未解析 usage
   When 页面正在后台回填 usage
   Then 首屏仍立即可见，未解析项按最近活动回退排序，待 usage 回填后再渐进重排。

## 增量（2026-04-17：usage 独立索引）

### 背景
- `Codex Sessions` 已经把 usage 从“只在详情页可见”推进到：
  - row 级可见
  - section 组头可见
  - 会话与会话组可按 usage 排序
- 但当前 `loadSessionUsage(...)` 仍按 session 逐个整文件读取 rollout，再逐行 reduce。
- 在 3000+ 会话场景下，这会把“按用量排序”和“组头快速浏览”退化成后台长期解析与渐进重排。
- 2026-04-17 的独立索引评估已明确：在“排序/搜索也是常用功能”的前提下，`usage` 是第一优先级的专门化独立索引。

### 目标
1. 为 session usage 引入可丢弃的独立索引层。
2. 让 row usage、组头 usage、按 usage 排序优先读取索引，而不是反复整文件解析。
3. 支持文件级差量更新；当 rollout 只是 append 时，只解析新增尾部。

### 非目标
1. 本轮不引入 `search` FTS。
2. 本轮不引入 `state projection` 独立索引。
3. 本轮不改 `snapshotStream / loadSnapshot / skeleton` 主扫描链路。
4. 本轮不要求 usage 刷新达到实时强一致。

### 约束
1. usage 索引必须是可丢弃缓存，不是真源。
2. 真源仍然只有 rollout 文件。
3. 索引缺失、失效或损坏时，必须自动回退到现有全量解析路径。
4. usage 不能并入 row/header 主索引主链路，避免把首屏冷路径和高频交互缓存绑死。
5. 索引落盘位置应在 `Application Support/Nolon/codex-sessions/`，不能进 `UserDefaults`。

### BDD 验收（usage 独立索引）
1. Given 某条 session usage 第一次被读取
   When `CodexSessionStore.loadSessionUsage(...)` 完成
   Then 返回正确 totals
   And 后续读取可命中 usage 索引。

2. Given 某条 rollout 文件没有变化
   When 再次读取 usage
   Then 不再需要整文件全量解析
   And 返回与上次一致的 totals。

3. Given 某条 rollout 文件只 append 了新的 token_count 事件
   When 再次读取 usage
   Then 只解析新增尾部
   And 返回合并后的最新 totals。

4. Given 某条 rollout 文件被整体替换、截断或索引已失效
   When 再次读取 usage
   Then 自动回退全量解析
   And 不影响 row usage、组头 usage 与按 usage 排序的正确性。

5. Given 当前页面按 usage 排序
   When usage 索引已命中
   Then 会话和会话组应更快收敛到稳定顺序
   And 不再依赖每次都重读整份 rollout 文件。
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
   Then 该组展开状态保持不变，且不会因刷新回退到默认 `3` 条。

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
  - 每组 `3` 条 + 展开/收起
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
2. 搜索激活时返回完整匹配结果，不受 section 折叠态 `prefix(3)` 预览截断影响。
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
4. 搜索态不能污染原始 `expandedSectionIDs`，但必须绕过默认 `3` 条预览限制。
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

3. Given `Sessions` 页处于 project 分组且某个 section 默认只显示前 `3` 条
   When 用户输入能命中该 section 第 `4` 条之后 session 的搜索词
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
  - 在搜索态绕过默认 `3` 条预览限制
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

## 增量（2026-04-17：会话行下内联展开详情）

### 背景
- 当前会话详情在页面最下方统一展示，用户点击某条会话后，详情会脱离原始上下文。
- 在 3000+ 会话的长列表中，这种“点一条、跳到底部看详情”的模式几乎不可用。
- 旧版详情卡片层级偏重，高度过大，不适合作为会话列表中的展开项。

### 目标
1. 点击会话后，详情直接在该会话行下方展开。
2. 把详情改成紧凑的行内检查面板，压缩旧版大卡片高度。
3. 保留现有 resume、Finder、复制路径、复制命令等动作。

### 非目标
1. 本轮不改为右侧双栏详情。
2. 本轮不新增业务字段或后端查询。
3. 本轮不改变当前 selection/rewrite 数据来源。

### BDD 验收（inline detail 增量）
1. Given 用户点击任意会话行
   When 会话被选中
   Then 详情显示在该行正下方，而不是列表底部。

2. Given 某条会话已经展开详情
   When 用户点击另一条会话
   Then 原详情收起，新详情移动到新会话行下方。

3. Given 会话详情已经展开
   When 用户继续滚动同一个 section
   Then 详情仍然跟随该行，不脱离该行上下文。

4. Given 窄宽度窗口
   When 行内详情显示
   Then 布局仍保持紧凑，不产生旧版大卡片那样的超高面板。

### 实现落点（2026-04-17 inline detail 增量）
- `libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexSessionViews.swift`
  - 为 section row 增加内联 expanded content 插槽
- `nolon/Skills/Domain/Providers/Views/CodexSessionsTabView.swift`
  - 删除列表底部统一详情块
  - 重做 `CodexSessionsDetailPanelView` 为紧凑版
- `nolonTests/CodexSessionsCardSnapshotTests.swift`
  - 新增/更新 inline detail 快照场景

## 增量（2026-04-17：大样本会话下先发布项目骨架）

### 背景
- 用户的 `Codex Sessions` 已累积 3000+ 会话；当前 `snapshotStream` 会随着扫描进度持续发布“已扫描到的全量 sessions”。
- `CodexSessionsTabViewModel` 每收到一个 snapshot 都会重建全部 project section，导致 section 在扫描过程中持续插入、重排、刷新。
- 在大样本下，列表会出现明显跳动，用户无法稳定滚动或浏览。

### 目标
1. 首屏先稳定展示 project sections 骨架，而不是边扫描边插入真实 rows。
2. project skeleton 发布后，再渐进把各项目的真实会话 rows 填充进去。
3. 已经出现在列表中的 section 应尽量复用同一 `section.id`，减少 SwiftUI diff 抖动。
4. 默认 `project-first` 浏览路径下，先保证“可停留、可滚动、可浏览”，再补齐细节数据。

### 非目标
1. 本轮不引入虚拟列表、分页游标或全文索引。
2. 本轮不重写 `snapshotStream` 的主扫描与排序策略，只在其前增加轻量预扫描阶段。
3. 本轮不新增复杂 placeholder row UI；使用现有 section card 的空 rows 能力承接占位。

### 产品约束
1. skeleton 至少提供：
   - `section id`
   - `title`
   - `path`
   - `liveCount`
   - `archivedCount`
   - `latestUpdatedAt`
2. skeleton 阶段 section 不渲染真实 rows，因此 `sessions` 必须为空。
3. skeleton 阶段不能触发 row usage 预取。
4. section 一旦首屏出现，后续 rows 回填时必须尽量复用同一 `section.id`。
5. project 分组顺序仍按组内最新会话时间倒序；当仅 skeleton 可用时，也要按 skeleton 的 `latestUpdatedAt` 排序。
6. refresh 期间仍优先发布最新 skeleton，避免重新回到“边扫边跳”的状态。

### BDD 验收（project skeleton 增量）
1. Given `Codex Sessions` 有 3000+ 会话
   When 页面开始加载
   Then 先出现稳定的 project sections skeleton，而不是逐批插入真实 rows。

2. Given 某个 project section 仍处于 skeleton 阶段
   When section card 渲染
   Then 该 section 显示 header、badge 与状态文案，但 `sessions` 为空。

3. Given skeleton section 已经显示在列表中
   When 后续 stream snapshot 补齐该项目会话
   Then 复用同一 `section.id`，并从空 rows 切换为真实 rows。

4. Given stream 仍在持续扫描
   When 新 batch 到达
   Then 已出现的 project section 顺序保持稳定，不因后续 batch 频繁重排。

5. Given 用户触发 refresh
   When 新一轮加载开始
   Then 仍优先发布 skeleton，再渐进填充真实 rows。

### 实现落点（2026-04-17 project skeleton 增量）
- `libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift`
  - 新增 project skeleton 预扫描能力
  - 复用 `CodexSessionScanner.scanFiles` + `readSessionMeta`
  - 聚合 project path、live/archived 计数与最新更新时间
- `nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift`
  - 在 streaming load 前先请求 project skeleton
  - 在 ViewModel 中维护 placeholder section 状态
  - skeleton 与真实 rows 合并时复用同一 section id
  - placeholder section 不参与 selection repair 与 usage prime
- `nolon/Skills/Domain/Providers/Views/CodexSessionsSectionDataBuilder.swift`
  - 为 placeholder section 提供轻量 subtitle
- `nolonTests/CodexSessionsTabViewModelTests.swift`
  - 新增先 skeleton 后 rows、占位为空 rows、复用 section id、排序稳定等用例
- `libs/Providers/Tests/ProvidersTests/CodexTests/CodexSessionStoreTests.swift`
  - 新增 project skeleton 聚合测试

### 验证
- `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexSessionsTabViewModelTests`
- `swift test --package-path libs/Providers --filter CodexSessionStoreTests`

## 增量（2026-04-17：加载架构重构与持久化边界）

### 背景
- 仅靠 project skeleton 预扫描，已经能把“首屏空白”问题压下来，但还没有切掉真正的根因链：
  - `snapshotStream` 仍按 batch 输出“当前累计的全量 sessions”
  - ViewModel 仍按 batch 全量替换 rows 并重建 sections
  - section 顺序仍可能因流式阶段的 `latestUpdatedAt` 变化而反复调整
- 用户已经明确接受“直接推倒重来”，因此本轮允许改动加载协议和 ViewModel 内部状态模型，但仍要求：
  - 先保证 project-first 浏览稳定
  - 再考虑二阶段缓存或更重的索引层

### 目标
1. 把 `snapshotStream` 从“累计全量 snapshot”改成“delta stream + completion event”。
2. 让 `CodexSessionsTabViewModel` 从“全量 rows 重建”改成“增量索引 + query state”。
3. 在 skeleton 可用时，把 skeleton 顺序作为流式阶段的稳定 section 锚点，完成前不重排 section。
4. 搜索改为 debounce 后再应用，避免每个字符输入都触发全量重建。
5. 明确持久化边界：
   - `groupingMode` 作为轻量偏好跨重启恢复
   - `searchQuery` / `selectedSessionID` 不跨重启恢复

### 非目标
1. 本轮不引入新的 SQLite / FTS 索引层。
2. 本轮不做会话数据磁盘缓存；这属于 phase 2 评估项。
3. 本轮不恢复页面级 `Load More` 语义，继续沿用 section 级 `5` 条预览 + 展开模型。

### 产品约束
1. Provider 层 delta 必须满足：
   - 每个 batch 只输出本批新增或更新的 session
   - 最后一批必须显式标记 `isComplete`
   - 不得重复发送之前 batch 已发过、且内容未变化的 rows
2. ViewModel 必须维护稳定选择态：
   - 当选中的 session 仍存在时，不得因流式填充、折叠态或暂时不可见而跳回第一条
3. skeleton 阶段与流式阶段都必须复用同一 `section.id`。
4. `Codex Sessions` 专属偏好不得并入 `AppSettingsStore`。
5. phase 1 仅持久化 `groupingMode`；其他状态暂不跨重启。
6. 手动 `refresh` 不要求实时流式可见；允许保留当前列表，待一次性新 snapshot 准备完成后再整体替换。

### BDD 验收（delta + query state 增量）
1. Given provider 下存在 3000+ 会话
   When `snapshotStream` 逐批发布数据
   Then 每批只发布增量 rows，而不是累计全量 snapshot。

2. Given skeleton 已按 project 顺序首屏显示
   When 后续 delta batch 持续到达
   Then section 框架顺序保持稳定，直到 stream 完成前都不因最新会话变化而重排。

3. Given 用户已经选中一个仍存在的 session
   When 后续 delta batch 到达，或 section 因折叠只显示前 3 条
   Then `selectedSessionID` 保持不变，不自动回退到第一条。

4. Given 用户在搜索框内快速连续输入
   When 查询文本持续变化
   Then 只有 debounce 后的查询才驱动列表过滤，而不是每次击键都重建 sections。

5. Given 用户把分组模式切到 `provider`
   When 退出并重新打开应用
   Then `Sessions` 页恢复为 `provider` 分组。

6. Given 用户关闭并重新打开应用
   When 回到 `Sessions` 页
   Then `searchQuery` 与 `selectedSessionID` 不自动恢复。

7. Given 用户已经进入 `Codex Sessions`
   When 用户主动点击刷新
   Then 当前列表保持可浏览，不重新进入流式抖动状态
   And 刷新完成后一次性切换到最新 snapshot。

### 实现落点（2026-04-17 delta + 持久化增量）
- `libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift`
  - 新增 delta stream 事件结构
  - `snapshotStream` 改为逐批输出增量 rows，并在结束时发出 completion event
- `nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift`
  - 维护 session 增量索引与 section query state
  - skeleton 顺序锁定、stream 完成后再解除
  - 手动 refresh 改为稳态单次 snapshot reload，不再复用实时 delta stream
  - 搜索 debounce
  - 选择态修正为“session 仍存在即保持”
- `nolon/Skills/Domain/Providers/Views/CodexSessionsPreferencesStore.swift`
  - provider-scoped `UserDefaults` 偏好存储
  - phase 1 仅管理 `groupingMode`
- `nolonTests/CodexSessionsTabViewModelTests.swift`
  - 新增/更新：delta 流期间顺序稳定、selection 稳定、debounce 查询、groupingMode 恢复
- `libs/Providers/Tests/ProvidersTests/CodexTests/CodexSessionStoreTests.swift`
  - 新增 delta stream 契约测试

## 增量（2026-04-17：组头显示当组用量）

### 背景
- 当前 `Codex Sessions` 已在 row 级异步回填 usage，但 section header 只显示标题、路径和 badge。
- 当用户按 `project` 或 `provider` 浏览大量会话时，需要先在组头看到“这一组大概消耗了多少”，而不是逐条点开或横向扫 usage 列。

### 目标
1. 每个 section 组头显示该组当前可聚合的 usage。
2. usage 展示位于标题区域上方，优先服务快速浏览，而不是塞进 subtitle。
3. 组头 usage 复用现有 row usage 语义，避免引入第二套展示状态。

### 产品约束
1. section usage 必须由 builder 聚合，而不是由 View 直接遍历 row 临时拼接。
2. section usage 状态与 row usage 对齐：
   - 全部仍在加载时显示 `Loading…`
   - 至少存在一条已加载 usage 时，显示当前已解析总量
   - 没有成功值且存在失败时显示 `Unavailable`
3. section header 的 usage 聚合范围必须覆盖该组全部 session，不能受折叠态可见 rows 数量限制影响。
4. 窄宽布局下仍优先保留总量；次级 `in/out` 细节可降级，但不能让总量消失。

### BDD 验收（组头用量）
1. Given 某个 project section 下已有多条 session usage 回填成功
   When 渲染该 section header
   Then 组头上方显示该组总量，并显示 `in/out` 汇总明细。

2. Given 某个 section 下所有 row usage 仍在加载
   When 首屏渲染该组
   Then 组头显示 `Loading…`，且不阻塞 row 列表浏览。

3. Given 某个 section 下没有成功 usage，且至少一条 usage 解析失败
   When 渲染该组
   Then 组头显示 `Unavailable`。

4. Given 某个 section 处于折叠态，且只有前 3 条 row 当前可见
   When 渲染该组 header usage
   Then 组头 usage 仍按该组全部 session 聚合
   And 不能只统计当前可见 rows。

### 实现落点
- `libs/NolonUIFoundation/Sources/NolonUIFoundation/CodexSessionsModels.swift`
  - `CodexSessionsSectionData` 新增 `usage`
- `nolon/Skills/Domain/Providers/Views/CodexSessionsSectionDataBuilder.swift`
  - 聚合 section.usageSessionIDs 的 usageState，分离“组头聚合来源”和“当前可见 rows”
- `libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexSessionViews.swift`
  - 在 section header 顶部增加 usage block
- `nolonTests/CodexSessionsSectionDataBuilderTests.swift`
  - 覆盖 section usage 聚合规则
- `nolonTests/CodexSessionsCardSnapshotTests.swift`
  - 覆盖组头显示 usage 的视觉回归

## 增量（2026-04-17：恢复到会话页时自动刷新）

### 背景
- 当前 `Codex Sessions` 页面只在首次进入时通过 `loadIfNeeded()` 触发加载。
- 当用户停留在 `Sessions` 页，把 App 退到后台后再重新激活，或恢复到该页面时，没有新的刷新触发点。
- 用户感知结果是：重新打开 App 后还停在 `Sessions` 页，但列表仍是旧数据。

### 目标
1. 当 `Sessions` 页已经完成过一次加载后，App 重新变为 `active` 时执行一次稳态刷新。
2. 该刷新沿用现有 `refresh()` 语义，不回退到 skeleton，也不重启流式抖动。
3. 未完成首次加载前，不因为 `scenePhase` 变化额外触发一次重复刷新。

### BDD 验收（恢复刷新）
1. Given 用户当前停留在 `Codex Sessions` 页，且页面已完成初始加载
   When App 退到后台后重新变为 `active`
   Then 页面执行一次稳态 `refresh()`，并展示最新 snapshot。

2. Given `Codex Sessions` 页还没有完成首次加载
   When App 生命周期切到 `active`
   Then 不额外触发 `refresh()`，避免与初始加载重复。

### 实现落点
- `nolon/Skills/Domain/Providers/Views/CodexSessionsTabView.swift`
  - 监听 `scenePhase`，在页面可见且重新进入 `active` 时通知 ViewModel
- `nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift`
  - 新增“App 激活后按需刷新”入口，复用现有 `refresh()` 逻辑
- `nolonTests/CodexSessionsTabViewModelTests.swift`
  - 覆盖已加载后 active refresh 与未加载前不刷新

## 增量（2026-04-20：概览指标显示总用量）

### 背景
- 当前 `Codex Sessions` 已经支持 row usage、组头 usage、按 usage 排序，但顶部 overview card 的 `Total / Groups` 仍只显示数量。
- 用户在大量会话场景下，需要在进入页面后不滚动列表就能先看到“总量大概消耗了多少”以及“当前分组总量大概消耗了多少”。
- 现有 `recent` 模式下，usage 会在后台渐进回填；如果 overview 继续依赖 section 的静态排序字段，usage 文案会停在初始占位，不会随回填更新。

### 目标
1. overview card 的核心指标继续以“数量”为主值，同时在次级文案展示对应 usage。
2. 紧凑态覆盖 `Total / Groups`；诊断态额外覆盖 `Rewritable`。
3. 不新增第二套 overview 卡片或独立 usage 卡，继续复用现有 metric 区域。

### 产品约束
1. overview usage 必须由 ViewModel 基于当前 bucket 内全部 session 的 `usageBySessionID` 动态聚合，不能直接复用 section 的静态 `usageTotalTokens` 排序缓存。
2. 指标主值仍然是数量；usage 只能作为次级文案，避免把 overview 读成第二套统计面板。
3. usage 展示语义与 row / section 保持一致：
   - 至少一条成功时显示已解析总量
   - 没有成功值但仍有待加载项时显示 `Loading…`
   - 没有成功值且存在失败时显示 `Unavailable`
4. `Groups` 指标展示的是“当前全部分组覆盖的总 usage”，不改成“每组平均用量”或其它衍生指标。

### BDD 验收（overview 指标用量）
1. Given 页面已有会话，且部分 usage 已成功回填
   When 渲染 overview card
   Then `Total / Groups` 的 count 下方显示对应 usage 次级文案。

2. Given overview 当前处于诊断态
   When 渲染指标区
   Then `Rewritable` 也显示自己的 usage 次级文案。

3. Given 页面排序模式为 `recent`
   And 首屏 section 顺序不会因为 usage 回填而重建
   When usage 在后台渐进回填完成
   Then overview usage 仍会从 `Loading…` 更新为已解析总量
   And section / row 顺序继续保持 recent 规则不变。

4. Given 当前 bucket 中没有成功 usage，且至少一条 usage 失败
   When 渲染 overview 指标
   Then 对应 metric 的 usage 次级文案显示 `Unavailable`。

### 实现落点
- `libs/NolonUIFoundation/Sources/NolonUIFoundation/CodexSessionsModels.swift`
  - `CodexSessionsMetricData` 新增 `detailText`
- `nolon/Skills/Domain/Providers/Views/CodexSessionsOverviewDataBuilder.swift`
  - overview context 新增各 metric 对应 usage
  - builder 输出 metric 次级 usage 文案
- `nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift`
  - 基于 `usageBySessionID` 动态聚合 overview usage bucket
- `nolon/Skills/Domain/Providers/Views/CodexSessionsTabView.swift`
  - 把 overview usage 接线到 overview builder context
- `libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexSessionViews.swift`
  - 在 overview metric 中渲染次级 usage 文案
- `nolonTests/CodexSessionsOverviewDataBuilderTests.swift`
  - 覆盖 metric usage 文案构建与本地化兼容断言
- `nolonTests/CodexSessionsTabViewModelTests.swift`
  - 覆盖不同 metric bucket 的动态 usage 聚合
- `nolonTests/CodexSessionsCardSnapshotTests.swift`
  - 覆盖 overview card usage 次级文案的视觉回归

## 增量（2026-04-20：组头改为标题 + subtitle 轨道）

### 背景
- 当前 project group header 仍保留多层堆叠结构，usage、badge、路径和状态分散在多行，信息密度高但浏览成本也高。
- 用户已经明确要求 group header 与单会话 row 采用同一套表达方式：主标题独立在上方，次信息统一并入 subtitle rail，用 ` · ` 分隔。
- 组级菜单与单会话菜单视觉也需要统一，不能再显示“操作”文字按钮。

### 目标
1. group header 改为双层结构：
   - 第一行只显示标题
   - 第二行用纯文本 subtitle rail 承载 usage、badge、状态、路径
2. 组头移除左侧 icon，不再额外渲染独立 usage 行、badge 行或 path 行。
3. 组头右侧菜单与单会话一致，只显示点点点。
4. 菜单新增：
   - 复制本组所有线程 ID
   - 打开关联文件夹
5. 组头标题字号与单会话标题字号同步抬高，提升大列表浏览可读性。

### 产品约束
1. subtitle rail 必须为纯文本语义，不再混入图标或胶囊。
2. 复制本组线程 ID 必须基于完整 section state，不能只复制当前折叠态可见的前 3 条。
3. “打开关联文件夹”只在 section 确实绑定到一个有效目录时展示，不能提供无效入口。
4. 组头菜单保留已有整组分享与 rewrite 能力，不因为视觉重构丢失原有动作。

### BDD 验收（组头 subtitle rail）
1. Given 会话页存在 project group
   When 渲染 group header
   Then 标题独立位于第一行
   And 其它次信息统一收口到第二行 subtitle rail
   And 各字段之间使用 ` · ` 分隔。

2. Given 某个 group 具备 usage、badge、路径与只读状态
   When 渲染组头
   Then 这些信息都显示在 subtitle rail 中
   And 不再显示左侧 icon、独立 usage 行或独立 badge 行。

3. Given 用户点击组头右侧菜单
   When 组存在完整线程 ID 与有效目录
   Then 菜单同时提供 `复制本组所有线程 ID` 与 `打开关联文件夹`。

4. Given 某个 group 的路径不是有效目录
   When 渲染菜单
   Then 不显示 `打开关联文件夹` 菜单项。

### 实现落点
- `libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedCodexSessionViews.swift`
  - 重构 section header 为标题 + subtitle rail
  - 移除左侧 icon 与旧的多行次信息布局
  - 菜单按钮统一为 `EllipsisMenuButton`
  - 标题字号提升
- `nolon/Skills/Domain/Providers/Views/CodexSessionsTabView.swift`
  - 接线组级复制线程 ID 与打开目录动作
- `nolon/Skills/Domain/Providers/Views/CodexSessionsTabViewModel.swift`
  - 提供完整 section 的线程 ID
  - 仅在有效目录存在时返回 folder path
- `nolon/Localizable.xcstrings`
  - 增加组级菜单文案键

### 验证
- `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexSessionsCardSnapshotTests`

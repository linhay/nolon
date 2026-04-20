# Skill: codex-sessions-workstream

用于处理 `Codex Sessions` 模块相关任务，避免在高复杂度场景下只改 UI、不补文档、或再次走回全量重扫的老路。

## 触发条件
- 修改 `Codex Sessions` 页、会话组、会话详情、搜索、排序、分享、刷新策略。
- 修改 `libs/Providers/Sources/Providers/Codex/` 下与 session 扫描、缓存、usage、timeline、CLI 对齐有关的逻辑。
- 用户反馈会话页“慢、跳、乱、不稳定、不持久化、不按预期排序/展开/刷新”。

## 先读什么
1. `docs-linhay/features/codex-sessions-tab-2026-04-10.md`
2. `docs-linhay/dev/codex-sessions-session-distillation-2026-04-21.md`
3. 按任务选择最近设计：
   - 缓存/启动：`docs-linhay/dev/codex-sessions-projection-cache-design-2026-04-18.md`
   - 启动刷新：`docs-linhay/dev/codex-sessions-startup-acceleration-design-2026-04-19.md`
   - 内存/大文件：`docs-linhay/dev/codex-sessions-memory-control-design-2026-04-20.md`
   - 行内展开/详情：`docs-linhay/dev/codex-sessions-inline-detail-expansion-2026-04-17.md`

## workflow

### 1. 先判定任务类型
- 产品语义：分组模式、信息架构、概览卡、section 能力说明、分享语义。
- 性能缓存：启动速度、投影缓存、usage index、timeline、后台 reconcile。
- 交互布局：行内展开、subtitle rail、组头样式、菜单位置。
- 诊断链路：CLI 对齐、日志、数据库损坏、缓存失效、降级路径。

### 2. 文档先行的边界
- 只要改动会影响“用户看到什么、何时刷新、缓存如何命中、分组如何排序、详情如何展开”，先更新 `docs-linhay/features/` 或 `docs-linhay/dev/`，必要时补 `docs-linhay/plans/`。
- 纯样式微调且不改变语义时，可直接实现；但若用户反馈已持续多轮，仍应补一份 `dev/` 或 `debate/` 文档收敛共识。

### 3. 实现边界
- 扫描、缓存、usage、timeline、SQLite、CLI 对齐放 `libs/Providers`。
- 会话页面编排、选择态、搜索词、排序模式、展开态放 ViewModel。
- 通用会话 UI 模型放 `libs/NolonUIFoundation`，复用组件放 `libs/NolonUI`。
- App 层不要直接持有 SQLite 细节，也不要绕过 Provider 层自行重扫 rollout。

### 4. 固定产品约束
- 首目标是“3000+ 会话下稳定浏览”，不是“首屏全字段都最新”。
- 默认采用“缓存先显示，后台 reconcile，stale-aware refresh”的节奏。
- 不要因为实时补数导致 section 或 row 顺序持续跳动。
- 单击条目应以内联方式展开/收起详情，避免把焦点移到列表底部。
- 组头与会话行的视觉结构要尽量同构：标题在上，副标题轨道承载次级信息。

### 5. 性能与容错约束
- 避免整文件读入大 rollout；优先流式逐行读取。
- 稳定文件优先走文件级缓存或 SQLite 索引，不要重复扫 timeline。
- SQLite/缓存损坏时默认静默降级，不把底层原始错误直接抛到首屏。
- 刷新链路必须记录 cache hit/miss、降级原因、耗时与数据规模。

### 6. 测试与验证
- 先补失败测试，再实现。
- 优先补这几层测试：
  - Provider：扫描、缓存、usage、timeline、降级。
  - ViewModel：分组、排序、展开、缓存首屏应用、后台 reconcile。
  - Snapshot/UI：组头、会话行、详情面板、分享内容。
- 常用命令：
  - `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexSessionsTabViewModelTests`
  - `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/CodexSessionsCardSnapshotTests`
  - `swift test --package-path libs/Providers --filter CodexSessionStoreTests`
- 若本轮只改文档/skills，至少执行一次文档级自检（如 `git diff --check`），并在收尾说明未跑代码测试。

## dont
- 不要跳过文档直接重写会话模块。
- 不要把“实时刷新”当作默认正确方向。
- 不要让 UI 层自行决定缓存策略或直接解析 rollout 文件。
- 不要只修单个视觉点而忽略同一模块内的结构性不一致。

## 输出要求
- 收尾时说明：本次任务属于哪一类、触碰了哪一层、是否更新了 `docs-linhay` 文档、跑了哪些验证。

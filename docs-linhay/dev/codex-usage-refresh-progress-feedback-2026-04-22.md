# Codex Usage 刷新详情与进度反馈设计（2026-04-22）

## 背景
- 用户在 `Codex -> Usage` tab 手动刷新时，页面长时间只显示 loading / spinner，体感接近“卡死”。
- 实际底层刷新链路并不是单一步骤，而是分成：
  - 读取现有 token trend snapshot 与 usage index 缓存
  - 扫描 live / archived rollout 清单
  - 识别 dirty rollout
  - 回填派生 usage 并更新受影响的 day keys
- 旧 UI 没有把这些阶段透传出来，因此用户无法判断：
  - 当前是不是还在正常推进
  - 卡在“扫文件”、“读 usage index”还是“回填派生用量”
  - 本轮大致还有多少工作量

## 目标
1. `Codex -> Usage` 刷新期间，页面明确展示当前阶段、详情与可感知进度，并尽量细化到数据库 / rollout 文件级。
2. 只改善反馈可解释性，不改变 token trend 统计口径。
3. 仅在 `codex` 用量页启用，不影响其他 provider 的刷新表现。

## 非目标
1. 本轮不改动 `Codex Usage` 的汇总算法与日级口径定义。
2. 本轮不把刷新进度定义成字节级或事件级百分比。
3. 本轮不引入新的全局 loading overlay，避免遮挡已有图表和错误态。

## 设计

### 1. Provider 层发出分阶段性能通知
- 文件：`libs/Providers/Sources/Providers/Codex/CodexSessionStore.swift`
- `refreshChangedProjectedUsageDayKeys(...)` 追加统一 operation trace，并按阶段发送通知：
  - `started`
  - `progress`
  - `completed`
- 在三大 phase 之下，进一步补充 `detail_phase`，把刷新链路细化为：
  - `scan_inventory`
  - `read_usage_index`
  - `reconcile_rollouts`
  - `read_previous_minutes`
  - `analyze_rollout`
  - `read_updated_minutes`
  - `rollout_completed`
  - `purge_stale_entries`
  - `finished`
- 当前通知 payload 包含：
  - `dirty_rollout_count`
  - `processed_rollout_count`
  - `scanned_file_count`
  - `cached_entry_count`
  - `refreshed_live_rollout_count`
  - `refreshed_archived_rollout_count`
  - `skipped_rollout_count`
  - `removed_rollout_count`
  - `affected_day_key_count`
  - `current_refresh_reason`
  - `current_rollout_path`
  - `current_database_name`
  - `current_database_path`
  - `codex_home_path`

### 2. Usage engine 负责把底层 payload 翻译成页面语义
- 文件：`nolon/Skills/Domain/Providers/Usage/Engine/ProviderUsageEngine.swift`
- 仅当 `usageProvider == .codex` 时监听 `CodexSessionStore.performanceNotification`。
- 仅接收当前 `codex_home_path` 对应的通知，避免别的账号或目录污染当前页面。
- 刷新开始后，先发布一个通用 preparing 状态：
  - 标题：`正在准备刷新本地用量`
  - 详情：`正在读取缓存并核对会话派生用量，请稍候。`
- 当底层 phase 推进时，再映射成：
  - `正在扫描会话文件`
  - `正在读取用量索引数据库`
  - `正在比对待刷新文件`
  - `正在读取旧分钟索引`
  - `正在分析会话文件`
  - `正在回读刷新结果`
  - `正在清理旧索引记录`
  - 兜底仍保留 `正在扫描会话用量` / `正在回填派生用量`
- 详情文案改为用户能直接理解、且能定位链路位置的句子，例如：
  - `正在读取 usage-index-v1.sqlite，准备比对 128 个会话文件与本地 minute 索引。`
  - `正在解析 2026/04/22/rollout-123.jsonl，原因：发现新 rollout。`
  - `正在从 usage-index-v1.sqlite 回读 2026/04/22/rollout-123.jsonl 的最新分钟桶，准备更新受影响日期。`
  - `已刷新 live 2 个、archived 1 个，跳过 116 个，当前影响 2 天，刚完成 2026/04/22/rollout-123.jsonl。`
- 刷新结束或失败时清空状态，避免旧进度残留在页面上。

### 3. UI 在 token trend header 下展示刷新状态卡片
- 文件：
  - `libs/NolonUIFoundation/Sources/NolonUIFoundation/ProviderTokenTrendModels.swift`
  - `libs/NolonUI/Sources/NolonUI/Components/Shared/UnifiedProviderUsageSupportViews.swift`
  - `nolon/Skills/Domain/Providers/Usage/Views/Common/ProviderTokenTrendSection.swift`
  - `nolon/Skills/Domain/Providers/Usage/Views/Common/ProviderUsageView.swift`
- 新增 `ProviderTokenTrendRefreshStatusData`，承载：
  - `title`
  - `detail`
  - `progressLabel`
  - `fractionCompleted`
- token trend header 在 subtitle 下方新增一块轻量状态卡片，展示：
  - 当前阶段标题
  - 与标题合并后的详情说明
  - 进度文案（如 `3 / 12`）
  - `ProgressView`
  - 当前 rollout 相对路径（详情句子中呈现）
  - 当前数据库名与刷新原因（详情句子中呈现）
- 交互微调：
  - 用户现场反馈“标题和分析说明拆成两行太散”，因此刷新状态卡片改为单条主文案：
    - 例如 `正在分析会话文件：正在解析 2026/04/22/rollout-123.jsonl，原因：发现新 rollout。`
  - 进度文案与 `ProgressView` 保留在下方，不再单独渲染第二行 detail。

## BDD

### 场景 1：刷新开始时给出“准备中”反馈
- Given 用户位于 `Codex -> Usage`
- When 页面开始执行 token trend refresh
- Then header 下方立即出现 refresh status 卡片
- And 文案说明页面正在读取缓存并准备核对本地派生用量

### 场景 2：扫描阶段显示可解释的详情
- Given 底层正在扫描 session rollout
- When Provider 层发出 `started` phase
- Then 页面展示“正在扫描会话用量”
- And 详情中展示已扫描文件数、缓存命中数、待回填 rollout 数

### 场景 3：文件级 / 数据库级阶段能被识别
- Given 底层已经进入具体 rollout 的 minute 回填链路
- When Provider 层发出 `detail_phase`
- Then 页面能区分“正在读取 usage-index”“正在读取旧分钟索引”“正在分析会话文件”“正在回读刷新结果”“正在清理旧索引记录”
- And 详情里能看到当前 rollout 相对路径、数据库名，以及触发本次回填的原因

### 场景 4：回填阶段显示进度
- Given 底层正在刷新 dirty rollout 的派生 usage
- When Provider 层持续发出 `progress` / `completed` phase
- Then 页面展示“正在回填派生用量”
- And 详情中展示 live / archived 刷新数、跳过数、受影响天数
- And 页面显示 `processed / dirty` 进度与对应 progress bar

### 场景 5：刷新结束后状态不残留
- Given 本轮 refresh 已完成或失败
- When `refreshTokenTrend()` 退出
- Then 页面移除 refresh status 卡片
- And 后续只保留最终 snapshot / error state

## 已知限制
1. 当前百分比来自 `dirty_rollout_count`，它表示“待处理 rollout 数量”，不是字节级、事件级或 token 级精确进度。
2. 当本轮没有 dirty rollout 时，进度显示为 `无需回填`，并直接把 `ProgressView` 视作完成态。
3. 如果底层真的卡住，这个设计不能直接修复阻塞本身，但至少能把“卡在扫描”还是“卡在回填”暴露出来，便于继续定位。

## 验证
- `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/ProviderUsageEngineManualRefreshTests`
- `swift test --package-path libs/Providers --filter CodexSessionStoreTests`
- `xcodebuild test -project nolon.xcodeproj -scheme nolon-tests -destination 'platform=macOS' -only-testing:nolonTests/ProviderUsageRootLoadBoundaryTests`

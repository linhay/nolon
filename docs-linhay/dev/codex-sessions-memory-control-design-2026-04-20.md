# Codex Sessions 内存收敛设计（2026-04-20）

## 背景
- 当前 `Codex Sessions` 在会话很多、且 rollout 文件体积较大时，内存峰值可上升到约 `1.5 GB`。
- 现有链路已经有两层缓存：
  - `projection cache`：缓存首屏列表投影。
  - `usage index`：缓存 usage 解析结果。
- 但当前仍有两个明显缺口：
  - `loadSessionTimeline` 仍然整文件读入。
  - `usage index` 只缓存 usage，不缓存详情卡片需要的 timeline 起止时间。

## 根因
我认为根因是：

> `usage` 排序会触发大量 rollout usage 解析，而 `CodexSessionUsageIndex.parseUsageFile` 与 `CodexSessionStore.loadSessionTimeline` 仍以整文件读入方式工作；当多个大文件并发解析时，会制造很高的瞬时内存峰值。与此同时，稳定 rollout 文件虽然几乎不会再变化，但 timeline 仍未复用磁盘缓存，导致详情展开和排序都可能重复扫文件。

## 目标
1. 首先压低峰值内存，避免解析大 rollout 文件时整块 `Data` 进内存。
2. 其次提升稳定文件的缓存命中率，避免详情卡片和 usage 排序重复扫文件。

## 最终落地方案

### 方案 1：rollout 解析改为流式逐行读取
- 新增统一的 rollout 行读取器。
- `usage index` 解析 usage 时改为 chunked line scan，而不是 `readToEnd()`。
- `loadSessionTimeline` 不再单独整文件读取，而是走同一条 usage 索引链路。

预期收益：
- 峰值内存从“文件大小 x 并发数”下降到“chunk 大小 x 并发数”。

### 方案 2：把稳定文件缓存从“仅 usage”扩为“usage + timeline 元数据”
- 扩展 `CodexSessionUsageIndex` 的 entry：
  - 保留已有 usage totals。
  - 新增 `startedAtUnixMs` / `lastActivityAtUnixMs`。
- 解析 usage 文件时顺便累积 timeline 元数据，一次扫描写入同一条索引记录。
- `loadSessionTimeline` 优先走该索引；若文件未变更，直接返回缓存值。

原因：
- 用户指出“许多文件已经不会更新了”，这类稳定 rollout 文件最适合走文件指纹缓存。
- 详情卡片展示起止时间时，不应再为稳定文件重复扫整份 JSONL。

## 暂缓项

### `CodexSessionsTabViewModelStore` 淘汰策略
- 该方案做过实现尝试，但在 `xcodebuild test` 中触发 `malloc: pointer being freed was not allocated`。
- 目前确认缓存主收益来自文件级持久化缓存，而不是强行回收 UI 层单例。
- 因此本轮明确暂缓 VM 淘汰，保留原来的“按 provider 复用同一个 view model”语义，单独立项继续排查析构链路。

## 非目标
- 本轮不重写 `Codex Sessions` 分组、搜索、排序主流程。
- 本轮不新增新的独立 SQLite 库文件，优先扩展已有 usage index。
- 本轮不改详情卡片 UI 结构，只服务于其加载链路和缓存。
- 本轮不继续推进 `CodexSessionsTabViewModelStore` 的 TTL / LRU / eviction。

## 验收标准
1. usage / timeline 解析路径不再整文件读入 rollout。
2. 对未变化文件，详情时间信息可复用磁盘缓存。
3. timeline 在无可解析时间戳时，仍能回退到文件 `mtime`，行为不回退。
4. 相关测试覆盖缓存命中与 timeline/usage 正确性。

## 实际实现结果
- `CodexRolloutLineReader` 已接入 usage 解析，避免整文件载入内存。
- `CodexSessionUsageIndex` 已缓存 `usage totals` 与 `startedAtUnixMs` / `lastActivityAtUnixMs`。
- `loadSessionTimeline` 已复用 usage index，不再单独扫描 rollout。
- schema 迁移通过补列兼容旧 SQLite 文件。

# Codex Sessions 启动提速设计（2026-04-19）

## 背景
- 当前 `Codex Sessions` 已经具备磁盘级 `projection cache`，可以做到“先显示旧内容，再后台 reconcile”。
- 但在真实使用中，用户仍能感知到进入会话页后后台扫描持续发生，尤其是 App 重开后首次进入会话页时。
- 2026-04-18 的投影缓存方案已经证明：首屏立即可见的核心不是流式加载，而是可直接 hydrate 的缓存。
- 本轮问题进一步收敛为：
  1. 初次命中缓存后，仍然会默认进入真实扫描校准。
  2. 即使真源没有变化，也会重复做 `loadProjectSkeletonSnapshot / loadSnapshot`。
  3. 当前缺少“数据源是否脏、缓存是否足够新”的轻量判定。

## 目标
1. 在存在有效缓存且数据源未变时，进入 `Codex Sessions` 不再立即触发全量 reconcile。
2. App 启动后能低优先级预热会话缓存，把重活前移到页面打开之前。
3. 数据源发生变化时，只标记缓存为 dirty，不做实时强刷。
4. 继续保持“缓存损坏或判定失败时自动回退真实扫描”的安全语义。

## 非目标
1. 本轮不引入全文搜索 FTS。
2. 本轮不建立完整 `sessions-index.sqlite`。
3. 本轮不把会话页改成实时监听 + 实时刷新模型。
4. 本轮不改变排序、分组、详情卡的数据语义。

## 现状判断

### 当前首屏慢点
- 真正慢的不是 ViewModel diff，而是 Provider 侧的混合源扫描：
  - rollout 文件树枚举
  - 首条 `session_meta` 解析
  - `session_index.jsonl`
  - `state_*.sqlite`
- 当前路径：
  - `CodexSessionScanner.scanFiles(...)`
  - `CodexSessionStore.loadProjectSkeletonSnapshot(...)`
  - `CodexSessionStore.loadSnapshot(...)`

### 当前缓存缺口
- `projection cache` 只保存结果，不保存“结果是否还干净”。
- ViewModel 无法区分：
  - “缓存刚刚生成，且源数据没变”
  - “缓存很旧，或者运行期已经有文件变化”

## 方案选型

### 方案 1：只做后台预热
- App 启动后后台跑一次 `skeleton + snapshot`，尽量让用户打开页面时命中 projection cache。
- 优点：实现最小。
- 缺点：不能解决“缓存命中后仍立即重扫”的问题。

### 方案 2：缓存 freshness + dirty gate + 后台预热
- 在 projection cache 基础上补一层轻量状态：
  - `dirty`
  - `snapshot_updated_at`
  - `skeleton_updated_at`
- 页面初次加载命中缓存时：
  - 若 `dirty == false` 且缓存年龄未超过阈值，则跳过当前轮 reconcile。
  - 否则再进入现有真实扫描链路。
- App 启动后低优先级预热 dirty / stale 的 provider。
- 推荐本方案。

### 方案 3：完整独立索引库
- 建 `sessions-index.sqlite`，让会话页只读索引库。
- 优点：后续搜索/排序/差量更新都可统一。
- 缺点：成本明显更高，不适合“先把启动做快”。

## 设计决策

### 决策 1：不直接做实时刷新，只做 dirty 标记
- 使用 `STPathWatcher` 监听：
  - `sessions/`
  - `archived_sessions/`
  - `session_index.jsonl`
  - `state_*.sqlite`
- 监听到变化时，只把对应 `codexHome` 的 projection 状态标为 dirty。
- 不在 watcher 回调里直接重扫。

### 决策 2：把 freshness / dirty 状态放进 projection cache 边界
- 新增 projection cache 状态读取能力，例如：
  - `cachedProjectionStatus(codexHome:)`
  - `markDirty(codexHome:)`
- 这样 App 层只关心“这个 provider 当前缓存能不能直接信任”，不关心 SQLite 细节。

### 决策 3：ViewModel 初次加载命中缓存时允许直接短路
- `reload(.initial)` 命中缓存后：
  - 若状态为 `clean + fresh`，直接结束本轮初次加载。
  - 若状态为 `dirty` 或 `stale`，再执行一次稳定 `loadSnapshotPresentation(...)`。
- 这样缓存首次进入可以真正“只读缓存，不立刻扫盘”。

### 决策 4：后台预热只做低优先级补偿
- App 启动后为 Codex provider 启动后台 warmup：
  - 若缓存缺失、dirty、或超过 warmup staleness 阈值，则后台重建 projection cache。
  - 若缓存是 clean + fresh，则跳过。

### 决策 5：回滚必须低成本
- 本轮所有新增状态都是可丢弃缓存。
- 删除 projection db 或关闭 watcher/warmup 接线即可回滚。

## 数据模型

### 基于现有 projection sqlite 增加状态表
建议新增：

`projection_status`

| 列 | 类型 | 说明 |
|---|---|---|
| `codex_home_path` | TEXT | `CODEX_HOME` 绝对路径 |
| `is_dirty` | INTEGER | 是否已脏 |
| `last_source_change_at_unix_ms` | INTEGER | 最近一次 watcher 标脏时间 |
| `last_snapshot_written_at_unix_ms` | INTEGER | 最近一次 full snapshot 落盘时间 |
| `last_skeleton_written_at_unix_ms` | INTEGER | 最近一次 skeleton 落盘时间 |

约束：
- 主键：`codex_home_path`

## 运行时流程

### 初次进入会话页
1. 读取 cached snapshot / skeleton
2. 若无缓存：
   - 回退当前真实扫描链路
3. 若有缓存：
   - 读取 `projection_status`
   - 若 `clean + fresh`：
     - 直接展示缓存并结束初次加载
   - 若 `dirty/stale`：
     - 展示缓存
     - 后台做一次稳定 snapshot reconcile

### 运行期文件变化
1. watcher 收到事件
2. debounce
3. 标记 `codexHome` 为 dirty
4. 不自动触发 UI reload

### App 启动后后台预热
1. 收集 codex provider 的 `codexHome`
2. 对每个 home 检查 projection status
3. 对 dirty / stale / missing provider 做低优先级 warmup

## BDD 验收场景

### 场景 1：clean cache 直接秒开
- Given `session_snapshot` 已存在
- And projection status 为 `clean`
- And snapshot 年龄未超过初次加载阈值
- When 用户进入 `Codex Sessions`
- Then 页面直接显示缓存列表
- And 不会立刻触发真实扫描

### 场景 2：dirty cache 先显示再后台校准
- Given `session_snapshot` 已存在
- And projection status 为 `dirty`
- When 用户进入 `Codex Sessions`
- Then 页面先显示缓存
- And 后台触发一次稳定 snapshot reconcile

### 场景 3：watcher 只标脏不重扫
- Given App 正在运行
- When `sessions/` 或 `state_*.sqlite` 发生变化
- Then 对应 provider 被标记为 dirty
- And 不会立即进入会话页重扫链路

### 场景 4：App 启动预热只处理脏或过期 provider
- Given App 启动
- When warmup service 执行
- Then 仅 dirty / stale / missing provider 会被后台预热
- And clean + fresh provider 会跳过

### 场景 5：状态读取失败自动降级
- Given projection status 无法打开或解码失败
- When 用户进入 `Codex Sessions`
- Then 仍然按当前真实扫描链路工作
- And 不影响功能正确性

## 测试策略

### Provider
1. status 表初始化与 schema 升级
2. `markDirty` 能正确写入 dirty 状态
3. snapshot/skeleton 写入后会更新 written_at 并清理 dirty
4. status 损坏时读取安全返回 nil / 默认值

### ViewModel
1. clean + fresh cached snapshot 会跳过初次 reconcile
2. dirty cached snapshot 会继续走稳定 snapshot reconcile
3. cached skeleton 在 clean + fresh 场景下也可直接展示占位

### App
1. watcher 收到变化后只标脏
2. warmup service 只预热 dirty / stale provider

## 回滚成本
- 关闭 warmup service 启动入口
- 移除 watcher 接线
- 忽略 projection status 判定
- 删除 projection sqlite

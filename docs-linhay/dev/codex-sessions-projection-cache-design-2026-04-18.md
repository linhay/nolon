# Codex Sessions 磁盘投影缓存设计（2026-04-18）

## 背景
- 当前 `Codex Sessions` 已经通过进程内 `inventory cache` 把 `snapshotStream` 与 `loadSnapshot` 压到几十毫秒。
- 但页面首屏仍然慢，瓶颈已经收敛到 `loadProjectSkeletonSnapshot(...)`，在 3000+ 会话下约 1.9s。
- 根因不是“没有任何缓存”，而是“没有可直接用于 UI hydrate 的磁盘级投影缓存”。
- 目前真正落盘的只有：
  - `usage-index-v1.sqlite`
  - `UserDefaults` 中的 `groupingMode / sortMode`
- 这两者都不能直接恢复会话页的 `projects / sections / rows`。

## 目标
1. 进入 `Codex Sessions` 时，优先读取上次成功构建的磁盘投影，做到“立即有内容可看”。
2. 后台继续做一次真实扫描与 reconcile，把最新结果 patch 回 UI。
3. 缓存损坏、缺失、版本不匹配时，必须自动回退现有扫描链路，不影响正确性。
4. App 回到前台时不再无脑刷新，只在 stale 时才触发后台 reconcile。

## 非目标
1. 本轮不引入全文搜索 FTS。
2. 本轮不把 usage、search、state 三套索引统一成一个复杂多表系统。
3. 本轮不缓存 `selectedSessionID`、展开态、搜索关键字等高频交互态。
4. 本轮不改变会话排序、分组、详情卡片的数据语义。

## 设计决策

### 决策 1：新增独立 SQLite 投影缓存，而不是继续扩大内存 TTL
- 推荐方案：新增 `CodexSessionProjectionCache`。
- 原因：
  - 用户痛点发生在“进入页面”和“App 重开后回到会话页”。
  - 进程内 TTL 缓存无法跨进程/跨重启生效。
  - 单独的 SQLite 投影缓存可丢弃、可回滚、易诊断。

### 决策 2：缓存“可直接展示的最终投影”，而不是继续只缓存扫描输入
- 本轮缓存内容：
  - `project_skeleton_snapshot`
  - `session_snapshot`
- 不缓存内容：
  - `snapshotStream` 的中间 batch
  - 逐 session 的 usage/timeline 临时加载态
- 理由：
  - 用户要的是页面立即可看。
  - 只缓存 `scannedFiles / stateIndex / sessionIndex` 仍然需要重新组装投影，无法真正消除首屏等待。

### 决策 3：缓存读写边界放在 Provider 层，对 ViewModel 只暴露“已缓存快照”
- 新增 Provider 协议能力：
  - `loadCachedProjectSkeletonSnapshot(codexHome:) -> CodexSessionProjectSkeletonSnapshot?`
  - `loadCachedSnapshot(codexHome:) -> CodexSessionSnapshot?`
- ViewModel 只负责：
  - 首屏先读缓存并应用
  - 后台继续走现有真实扫描链路
- 理由：
  - 保持 App 层不关心 SQLite 细节。
  - 与现有 `CodexSessionStore` / CLI benchmark 结构一致。

### 决策 4：缓存更新时机绑定真实扫描成功，不做独立后台写线程
- `loadProjectSkeletonSnapshot(...)` 成功后写入 skeleton cache。
- `loadSnapshot(...)` 成功后写入 full snapshot cache。
- `snapshotStream(...)` 完成时，把累计快照写入 full snapshot cache。
- 理由：
  - 避免多条写路径竞争同一份投影。
  - 先保证一致性和可维护性，再谈更细粒度增量写入。

### 决策 5：前台激活改成 stale-aware，避免每次激活都重扫
- `refreshOnAppActivationIfNeeded()` 改为复用 `refreshIfStale()`。
- 理由：
  - 当前无脑 `refresh()` 会放大“页面一直在扫”的体感。
  - 这属于缓存生效后的必要补强，否则仍会频繁触发后台重扫。

## 数据模型

### 存储位置
- 根目录：`~/Library/Application Support/Nolon/codex-sessions/`
- 数据库文件：`projection-cache-v1.sqlite`

### 表结构

`projection_snapshots`

| 列 | 类型 | 说明 |
|---|---|---|
| `codex_home_path` | TEXT | `CODEX_HOME` 绝对路径 |
| `kind` | TEXT | `project_skeleton` / `session_snapshot` |
| `schema_version` | INTEGER | 当前缓存 schema 版本 |
| `payload_json` | TEXT | JSON 编码后的快照 |
| `updated_at_unix_ms` | INTEGER | 最近写入时间 |
| `source_run_id` | TEXT | 本次写入 trace id，便于诊断 |

约束：
- 主键：`(codex_home_path, kind)`

## 读取策略
1. ViewModel 初次进入页面：
   - 若 `sections` 为空，先尝试读取 `project_skeleton` cache 并应用。
   - 再尝试读取 `session_snapshot` cache 并直接生成 `sections / rows`。
   - 然后后台进入真实扫描链路做 reconcile。
2. 若缓存缺失、解码失败、SQLite 打开失败：
   - 记录 warning
   - 忽略缓存
   - 继续现有真实扫描链路
3. `session_snapshot` 存在时：
   - 首屏不再依赖 `snapshotStream` 才能出现会话列表。
4. `project_skeleton` 与 `session_snapshot` 同时存在时：
   - 优先应用 `session_snapshot`
   - `project_skeleton` 只作为“缓存缺少完整列表时”的兜底概览

## 更新策略
1. `loadProjectSkeletonSnapshot(...)` 成功：
   - 覆盖写入 `project_skeleton`
2. `loadSnapshot(...)` 成功：
   - 覆盖写入 `session_snapshot`
3. `snapshotStream(...)` 完成：
   - 汇总所有 emitted sessions
   - 覆盖写入 `session_snapshot`
4. rewrite 成功：
   - 失效该 `codexHome` 的 session/skeleton cache
   - 下次加载重新生成

## 降级策略
1. SQLite 路径不可写或数据库损坏：
   - 缓存层静默失效
   - 主功能回退到当前扫描实现
2. 单个 `state_*.sqlite` 打不开：
   - 记 warning
   - 跳过该文件，继续其它文件
   - 不再把底层 SQLite 原始错误直接弹到会话页首屏
3. 缓存 schema 升级：
   - 直接忽略旧版本行并覆盖重建

## BDD 验收场景

### 场景 1：跨重启秒开已有缓存
- Given 上一次成功生成过 `session_snapshot`
- When 用户退出并重新打开 App 后进入 `Codex Sessions`
- Then 页面先直接显示上次缓存的会话列表
- And 不需要等待全量扫描完成才出现可浏览内容

### 场景 2：缓存缺失自动回退
- Given 当前没有任何 projection cache
- When 用户首次进入 `Codex Sessions`
- Then 页面仍按现有 skeleton + stream + snapshot 链路工作
- And 功能正确性不受影响

### 场景 3：后台 reconcile 覆盖旧缓存
- Given 页面先展示了旧缓存
- When 后台真实扫描完成
- Then 页面被最新结果替换
- And 新结果会覆盖写回 projection cache

### 场景 4：前台激活不过度刷新
- Given 已经存在最近一次成功加载结果
- When 用户切到别的页面再切回或 App 重新 active
- Then 仅在超过 stale 阈值时才触发刷新
- And 不会每次激活都立即重扫

### 场景 5：缓存失败不影响页面可用
- Given projection cache 损坏或无法打开
- When 页面尝试读取缓存
- Then 页面不会直接失败
- And 会自动回退真实扫描链路

## 测试策略

### Provider
1. 读取不存在缓存时返回 `nil`
2. 写入后能正确读回 `project_skeleton`
3. 写入后能正确读回 `session_snapshot`
4. schema version 不匹配时会忽略旧缓存
5. 失效后读取返回 `nil`

### ViewModel
1. 初次加载时优先应用 cached snapshot
2. 仅有 cached skeleton 时能先显示概览
3. 后台真实扫描完成后会替换缓存投影
4. App 激活时只在 stale 条件满足时刷新

## 回滚成本
- 关闭 `CodexSessionProjectionCache` 接线即可回滚。
- 删除 `projection-cache-v1.sqlite` 即可清除所有影响。
- 不涉及 rollout 真源数据迁移，回滚成本低。
